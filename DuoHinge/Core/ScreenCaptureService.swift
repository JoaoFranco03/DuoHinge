//
//  ScreenCaptureService.swift
//

import AppKit
import CoreGraphics
import CoreVideo
import Observation
import ScreenCaptureKit

/// Streams only the active, non-mirrored built-in display.
/// Permission prompts are owned by PermissionManager; capture only checks access.
@Observable @MainActor
final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored nonisolated private let captureQueue = DispatchQueue(
        label: "desktop.frames", qos: .userInteractive)
    // One frame in flight: never accumulate stale images while the UI is busy.
    @ObservationIgnored nonisolated private let frameSlot = DispatchSemaphore(value: 1)
    private(set) var pixelBuffer: CVPixelBuffer?
    private(set) var displayID: CGDirectDisplayID?
    private(set) var errorMessage: String?
    @ObservationIgnored private var captureTask: Task<Bool, Never>?
    @ObservationIgnored var overlayWindowID: CGWindowID?
    @ObservationIgnored private var sessionID = UUID()

    var isRunning: Bool { stream != nil }

    /// Await the actual startup, not just the creation of a nested task.
    @discardableResult
    func start() async -> Bool {
        if let captureTask { return await captureTask.value }
        if stream != nil { return true }
        guard CGPreflightScreenCaptureAccess() else {
            errorMessage =
                "Screen access is unavailable to this running copy. Enable it in Settings and check again. Relaunch only if access still cannot be used."
            return false
        }
        errorMessage = nil
        let token = UUID()
        sessionID = token
        let task = Task { [weak self] in
            guard let self else { return false }
            return await self.captureBuiltInDisplay(session: token)
        }
        captureTask = task
        let success = await task.value
        guard sessionID == token else { return false }
        captureTask = nil
        if !success {
            stream = nil
            pixelBuffer = nil
        }
        return success
    }

    func stop() {
        sessionID = UUID()
        captureTask?.cancel()
        captureTask = nil
        let capture = stream
        stream = nil
        pixelBuffer = nil
        displayID = nil
        errorMessage = nil
        Task { try? await capture?.stopCapture() }
    }

    private func captureBuiltInDisplay(session token: UUID) async -> Bool {
        var pendingStream: SCStream?
        do {
            var content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            try Task.checkCancellation()
            guard sessionID == token else { return false }
            // WindowServer registration can lag the panel's creation briefly.
            for _ in 0..<10 {
                if content.windows.contains(where: { $0.windowID == overlayWindowID }) { break }
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                guard sessionID == token else { return false }
            }
            guard
                let display = content.displays.first(where: {
                    HingePolicy.allowsDisplay(
                        builtIn: CGDisplayIsBuiltin($0.displayID) != 0,
                        active: CGDisplayIsActive($0.displayID) != 0,
                        mirrored: CGDisplayIsInMirrorSet($0.displayID) != 0)
                })
            else {
                errorMessage =
                    "The effect requires an active MacBook display in extended-display mode. External displays are never used."
                return false
            }
            displayID = display.displayID
            // Accessory/menu-bar processes may not appear in the application list
            // at startup. Also inspect window owners, and never capture unfiltered.
            let candidates = content.applications + content.windows.compactMap(\.owningApplication)
            var seen = Set<pid_t>()
            let ownApps = candidates.filter { app in
                let ours =
                    app.processID == ProcessInfo.processInfo.processIdentifier
                    || app.bundleIdentifier == Bundle.main.bundleIdentifier
                return ours && seen.insert(app.processID).inserted
            }
            guard let overlayWindow = content.windows.first(where: { $0.windowID == overlayWindowID }) else {
                errorMessage = "Capture could not locate its overlay window. Quit and reopen Duo Hinge."
                pixelBuffer = nil
                return false
            }
            // No exceptions: a captured overlay compounds even a 1-degree warp
            // every frame. Exclude other Debug/Release instances as well.
            let excludedPIDs = Set(ownApps.map(\.processID))
            let excludedWindows = content.windows.filter {
                $0.windowID == overlayWindow.windowID
                    || $0.owningApplication.map { excludedPIDs.contains($0.processID) } == true
            }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
            let configuration = SCStreamConfiguration()
            configuration.captureResolution = .best
            configuration.width = CGDisplayPixelsWide(display.displayID)
            configuration.height = CGDisplayPixelsHigh(display.displayID)
            // Preserve full RGB detail and use the captured display's color space.
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.colorSpaceName = CGColorSpace.sRGB
            configuration.showsCursor = false
            let screen = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                    == display.displayID
            }
            let refreshRate = max(screen?.maximumFramesPerSecond ?? 60, 1)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(refreshRate))
            configuration.queueDepth = 3
            let capture = SCStream(filter: filter, configuration: configuration, delegate: self)
            pendingStream = capture
            try Task.checkCancellation()
            try capture.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            stream = capture
            try await capture.startCapture()
            if Task.isCancelled || sessionID != token {
                try? await capture.stopCapture()
                return false
            }
            errorMessage = nil
            return true
        } catch {
            if let pendingStream { try? await pendingStream.stopCapture() }
            guard sessionID == token, !Task.isCancelled else { return false }
            errorMessage = "ScreenCaptureKit failed: \(error.localizedDescription)"
            return false
        }
    }

    nonisolated func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid, let buffer = sampleBuffer.imageBuffer else { return }
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
            let status = attachments.first?[.status] as? Int,
            status == SCFrameStatus.complete.rawValue,
            frameSlot.wait(timeout: .now()) == .success
        else { return }
        let frame = CapturedSurface(buffer: buffer)
        Task { @MainActor in
            defer { frameSlot.signal() }
            guard self.stream === stream else { return }
            pixelBuffer = frame.buffer
        }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            guard self.stream === stream else { return }
            self.errorMessage = error.localizedDescription
            self.pixelBuffer = nil
            self.stream = nil
            self.sessionID = UUID()
            self.captureTask?.cancel()
            self.captureTask = nil
        }
    }
}
