import AppKit
import Observation

/// Owns capture independently of menu presentation. Retries are bounded per session.
@Observable @MainActor
final class HingeRuntime {
    let sensor = LidAngleSensor()
    let capture = ScreenCaptureService()
    var overlay = ScreenOverlayController()
    var permissions = PermissionManager()

    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            stopCaptureAndOverlay()
            if isEnabled { refresh() }
        }
    }
    private static let triggerAngleKey = "triggerAngle"
    var triggerAngle: Double = {
        let stored = UserDefaults.standard.double(forKey: "triggerAngle")
        return stored > 0 ? stored : 90.0
    }()
    {
        didSet {
            guard triggerAngle != oldValue else { return }
            UserDefaults.standard.set(triggerAngle, forKey: Self.triggerAngleKey)
            refresh()
        }
    }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startup: Task<Void, Never>?
    @ObservationIgnored private var startupID = UUID()
    @ObservationIgnored private var lastProgress: Double?
    @ObservationIgnored private var lastPermission: Bool?
    @ObservationIgnored private var recovery = CaptureRecoveryPolicy()

    var angle: Double { sensor.angle }
    private(set) var menuBarImage: NSImage = LaptopIconRenderer.render(angle: 90)
    @ObservationIgnored private var lastIconAngle: Double = -999
    @ObservationIgnored private var lastIconEnabled: Bool?
    @ObservationIgnored private var lastIconPermission: Bool?

    var menuBarIcon: String {
        if !permissions.hasScreenRecordingPermission {
            return "laptopcomputer.trianglebadge.exclamationmark"
        }
        return isEnabled ? "laptopcomputer" : "laptopcomputer.slash"
    }

    private func updateMenuBarIconIfNeeded() {
        let granted = permissions.hasScreenRecordingPermission
        let currentAngle = (angle.isFinite ? angle : 90.0)
        let quantized = (currentAngle / 2.0).rounded() * 2.0
        if quantized != lastIconAngle || isEnabled != lastIconEnabled || granted != lastIconPermission {
            lastIconAngle = quantized
            lastIconEnabled = isEnabled
            lastIconPermission = granted
            menuBarImage = LaptopIconRenderer.render(
                angle: quantized,
                isEnabled: isEnabled,
                hasPermission: granted
            )
        }
    }

    func displaysChanged() {
        guard timer != nil else { return }
        stopCaptureAndOverlay()
        refresh()
    }

    /// Manual retry also refreshes permission, but never requests it.
    func retryCapture() {
        permissions.refreshPermissionStatus()
        stopCaptureAndOverlay()
        refresh()
    }

    func start() {
        guard timer == nil else { return }
        permissions.startMonitoring()
        sensor.start()
        let timer = Timer(timeInterval: 1.0 / 100.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func refresh() {
        guard timer != nil else { return }
        updateMenuBarIconIfNeeded()
        let granted = permissions.hasScreenRecordingPermission
        if lastPermission != granted {
            // A permission transition invalidates stale frames and failed attempts.
            stopCaptureAndOverlay()
            lastPermission = granted
        }
        let shouldPrewarm =
            granted && isEnabled && ScreenOverlayController.builtInScreen != nil
            && HingePolicy.shouldPrewarmCapture(angle: angle, thresholdAngle: triggerAngle, prewarmMargin: 3.0)
        guard shouldPrewarm else {
            if startup != nil || capture.isRunning || lastProgress != nil || recovery.attempts > 0 {
                stopCaptureAndOverlay()
            }
            return
        }

        if !capture.hasFrame {
            if startup == nil, !capture.isRunning,
                recovery.canAttempt(at: ProcessInfo.processInfo.systemUptime)
            {
                beginCapture()
            }
        }

        let target = HingePolicy.closeProgress(angle: angle, thresholdAngle: triggerAngle)
        if target > 0.0001, capture.hasFrame {
            lastProgress = target
            overlay.update(
                angle: angle,
                sampleTime: sensor.sampleTime,
                thresholdAngle: triggerAngle,
                screenCapture: capture)
        } else if lastProgress != nil {
            lastProgress = nil
            overlay.hide()
        }
    }

    private func beginCapture() {
        recovery.recordAttempt(at: ProcessInfo.processInfo.systemUptime)
        let token = UUID()
        startupID = token
        overlay.prepareForCapture(screenCapture: capture)
        startup = Task { [weak self] in
            guard let self else { return }
            _ = await capture.start()
            guard !Task.isCancelled, startupID == token else { return }
            startup = nil
            // PermissionManager is the only writer of access state.
            permissions.refreshPermissionStatus()
            if !capture.isRunning { overlay.hide() }
            refresh()
        }
    }

    private func stopCaptureAndOverlay() {
        startupID = UUID()
        startup?.cancel()
        startup = nil
        capture.stop()
        overlay.hide()
        recovery.reset()
        lastProgress = nil
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        permissions.stopMonitoring()
        stopCaptureAndOverlay()
        sensor.stop()
    }
}
