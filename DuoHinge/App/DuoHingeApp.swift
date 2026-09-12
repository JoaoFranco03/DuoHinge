import AppKit
import SwiftUI

@main
struct DuoHingeApp: App {
    @NSApplicationDelegateAdaptor(HingeAppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            ContentView(runtime: delegate.runtime)
        } label: {
            Image(nsImage: delegate.runtime.menuBarImage)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class HingeAppDelegate: NSObject, NSApplicationDelegate {
    let runtime = HingeRuntime()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var relaunchWait: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--duo-relaunch-parent"),
            arguments.indices.contains(index + 1),
            let pid = Int32(arguments[index + 1]), others.count == 1,
            let parent = others.first, parent.processIdentifier == pid
        {
            // Return from didFinishLaunching so NSWorkspace can report launch success.
            // The old process then exits; do not overlap capture or HID ownership.
            relaunchWait = Task { @MainActor [weak self] in
                for _ in 0..<100 {
                    guard !Task.isCancelled else { return }
                    if parent.isTerminated {
                        self?.startRuntime()
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                // A refused/failed parent termination must not leave two runtimes.
                NSApp.terminate(nil)
            }
            return
        }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }
        startRuntime()
    }

    private func startRuntime() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.runtime.stop() }
            })
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.runtime.start() }
            })

        runtime.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        relaunchWait?.cancel()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        runtime.stop()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        runtime.displaysChanged()
    }
}
