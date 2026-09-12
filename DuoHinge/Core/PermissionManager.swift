import AppKit
import CoreGraphics
import Observation
import ServiceManagement

/// The sole owner of permission state. Only an explicit user action requests access.
@Observable @MainActor
final class PermissionManager {
    private(set) var hasScreenRecordingPermission: Bool
    private(set) var isWaitingForPermission = false
    private(set) var hasRequestedThisSession = false
    private(set) var isRelaunching = false
    private(set) var errorMessage: String?
    var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != oldValue, !updatingLoginItem else { return }
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    @ObservationIgnored private var updatingLoginItem = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var monitor: Timer?
    @ObservationIgnored private var nextCheck = 0.0
    @ObservationIgnored private var waitingUntil = 0.0
    @ObservationIgnored private var requesting = false
    @ObservationIgnored private let checkAccess: @MainActor () -> Bool
    @ObservationIgnored private let requestAccess: @MainActor () -> Bool
    @ObservationIgnored private let settingsOpener: @MainActor (URL) -> Bool

    init(
        checkAccess: @escaping @MainActor () -> Bool = { CGPreflightScreenCaptureAccess() },
        requestAccess: @escaping @MainActor () -> Bool = { CGRequestScreenCaptureAccess() },
        settingsOpener: @escaping @MainActor (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.checkAccess = checkAccess
        self.requestAccess = requestAccess
        self.settingsOpener = settingsOpener
        self.hasScreenRecordingPermission = checkAccess()
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.refreshPermissionStatus() }
            })
        // A native menu doesn't necessarily activate the app. Also observe leaving Settings.
        observers.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.refreshPermissionStatus() }
            })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        refreshPermissionStatus()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        monitor = timer
    }

    func stopMonitoring() {
        monitor?.invalidate()
        monitor = nil
        isWaitingForPermission = false
    }

    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        if isWaitingForPermission && now >= waitingUntil { isWaitingForPermission = false }
        guard now >= nextCheck else { return }
        refreshPermissionStatus()
        nextCheck = now + (isWaitingForPermission ? 1 : 5)
    }

    @discardableResult
    func refreshPermissionStatus() -> Bool {
        hasScreenRecordingPermission = checkAccess()
        if hasScreenRecordingPermission { isWaitingForPermission = false }
        return hasScreenRecordingPermission
    }

    func requestPermission() {
        guard !requesting else { return }
        if refreshPermissionStatus() { return }
        requesting = true
        defer { requesting = false }
        hasRequestedThisSession = true
        // Do not persist a "requested once" flag: macOS permission entries can be reset.
        // macOS decides whether another user-initiated request can show a prompt.
        _ = requestAccess()
        if !refreshPermissionStatus() { openSettings() }
    }

    func openSettings() {
        isWaitingForPermission = !hasScreenRecordingPermission
        waitingUntil = ProcessInfo.processInfo.systemUptime + 120
        nextCheck = 0
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"),
            settingsOpener(url)
        else {
            errorMessage = "Could not open Screen Recording settings."
            isWaitingForPermission = false
            return
        }
    }

    /// The replacement process waits for this PID to exit before starting the runtime.
    /// If launching fails, keep this app alive and report the error.
    func relaunch() {
        guard !isRelaunching else { return }
        isRelaunching = true
        errorMessage = nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--duo-relaunch-parent", String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) {
            [weak self] application, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard error == nil, application != nil else {
                    isRelaunching = false
                    errorMessage =
                        "Could not relaunch: \(error?.localizedDescription ?? "No replacement process was created.")"
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        updatingLoginItem = true
        defer { updatingLoginItem = false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }
}
