import AppKit

/// The permission system is injected: no real consent prompts or Settings writes.
@main
enum PermissionChecks {
    @MainActor static func main() {
        var granted = false
        var requests = 0
        var openedSettings = 0
        let permissions = PermissionManager(
            checkAccess: { granted },
            requestAccess: {
                requests += 1
                return granted
            },
            settingsOpener: { _ in
                openedSettings += 1
                return true
            }
        )
        precondition(!permissions.hasScreenRecordingPermission && requests == 0)
        permissions.requestPermission()
        precondition(requests == 1 && openedSettings == 1 && permissions.isWaitingForPermission)
        for _ in 0..<10 { permissions.refreshPermissionStatus() }
        precondition(requests == 1)  // Polling must never request consent.
        granted = true
        precondition(permissions.refreshPermissionStatus())
        precondition(!permissions.isWaitingForPermission)
        permissions.requestPermission()
        precondition(requests == 1)  // Already granted: no redundant request.
        granted = false
        precondition(!permissions.refreshPermissionStatus())
        permissions.requestPermission()
        precondition(requests == 2)  // A TCC reset must not be blocked by a stored flag.
        permissions.stopMonitoring()
        precondition(!permissions.isWaitingForPermission)

        // Exercise the real timer with fake access, not just manual refresh.
        granted = false
        permissions.startMonitoring()
        granted = true
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        precondition(permissions.hasScreenRecordingPermission)
        permissions.stopMonitoring()
        precondition(requests == 2)  // Timer recovery must not display consent.

        var inlineGranted = false
        let inline = PermissionManager(
            checkAccess: { inlineGranted },
            requestAccess: {
                inlineGranted = true
                return true
            },
            settingsOpener: { _ in preconditionFailure("Do not open Settings after an inline grant") }
        )
        inline.requestPermission()
        precondition(inline.hasScreenRecordingPermission)
        print("Permission grant, revocation, explicit retry, and no-reprompt checks passed.")
    }
}
