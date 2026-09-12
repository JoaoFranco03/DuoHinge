//
//  ScreenOverlayController.swift
//

import AppKit
import MetalKit
import Observation

enum HingeStyle: String, CaseIterable, Identifiable {
    case clear = "Clear"
    case frosted = "Frosted"
    case cinematic = "Cinematic"
    var id: String { rawValue }
    var chromaticAberration: Float { self == .cinematic ? 1 : 0 }
    var blur: Float {
        switch self {
        case .clear: 0.25
        case .frosted: 1
        case .cinematic: 1.3
        }
    }
    var darkness: Float {
        switch self {
        case .clear: 0.2
        case .frosted: 1
        case .cinematic: 1.2
        }
    }
    var detail: String {
        switch self {
        case .clear: "Light blur, minimal dimming"
        case .frosted: "Soft glass, balanced dimming"
        case .cinematic: "Deeper blur, prismatic edges"
        }
    }
}

/// Places the ScreenCaptureKit texture only over the built-in display. The panel deliberately
/// ignores mouse events, so it never prevents the user from interacting with macOS.
@Observable @MainActor
final class ScreenOverlayController {
    var viewpoint = HingeViewpoint(rawValue: UserDefaults.standard.string(forKey: "hingeViewpoint") ?? "") ?? .desk {
        didSet { UserDefaults.standard.set(viewpoint.rawValue, forKey: "hingeViewpoint") }
    }
    var style = HingeStyle(rawValue: UserDefaults.standard.string(forKey: "hingeVisualStyle") ?? "") ?? .frosted {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "hingeVisualStyle") }
    }
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var renderer: HingeMetalRenderer?

    static var builtInScreen: NSScreen? {
        NSScreen.screens.first {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            let id = number.uint32Value
            return HingePolicy.allowsDisplay(
                builtIn: CGDisplayIsBuiltin(id) != 0,
                active: CGDisplayIsActive(id) != 0,
                mirrored: CGDisplayIsInMirrorSet(id) != 0)
        }
    }

    /// Register an empty transparent window before enumerating capture sources.
    /// It contains no desktop image until capture has installed its exclusion.
    func prepareForCapture(screenCapture: ScreenCaptureService) {
        guard let panel = makePanelIfNeeded(screenCapture: screenCapture) else {
            screenCapture.overlayWindowID = nil
            hide()
            return
        }
        screenCapture.overlayWindowID = CGWindowID(panel.windowNumber)
        renderer?.clear()
        panel.orderFrontRegardless()
    }

    func update(angle: Double, sampleTime: Double, thresholdAngle: Double, screenCapture: ScreenCaptureService) {
        let closeProgress = HingePolicy.closeProgress(angle: angle, thresholdAngle: thresholdAngle)
        guard closeProgress > 0.0001 else {
            hide()
            return
        }

        guard screenCapture.hasFrame else { return }
        renderer?.progress = Float(closeProgress)
        renderer?.thresholdAngle = thresholdAngle
        renderer?.receive(angle: angle, at: sampleTime)
        renderer?.style = style
        renderer?.viewpoint = viewpoint
        renderer?.view.isPaused = false

        guard let panel = makePanelIfNeeded(screenCapture: screenCapture) else {
            hide()
            return
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        renderer?.view.isPaused = true
        renderer?.resetMotion()
    }

    private func makePanelIfNeeded(screenCapture: ScreenCaptureService) -> NSPanel? {
        guard let screen = Self.builtInScreen else { return nil }
        let frame = screen.frame
        if let panel {
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            return panel
        }
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.title = "Duo Hinge Desktop Overlay"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.animationBehavior = .none
        self.panel = panel
        refresh(panel: panel, screenCapture: screenCapture)
        guard renderer != nil else {
            self.panel = nil
            return nil
        }
        return panel
    }

    private func refresh(panel: NSPanel, screenCapture: ScreenCaptureService) {
        do {
            let renderer = try HingeMetalRenderer(capture: screenCapture)
            renderer.view.preferredFramesPerSecond = Self.builtInScreen?.maximumFramesPerSecond ?? 60
            self.renderer = renderer
            panel.contentView = renderer.view
        } catch {
            NSLog("Cannot initialize desktop renderer: %@", error.localizedDescription)
        }
    }
}
