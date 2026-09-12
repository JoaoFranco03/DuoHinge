import AppKit
import SwiftUI

/// Native menu items only; the runtime remains owned by the application delegate.
struct ContentView: View {
    @Bindable var runtime: HingeRuntime

    var body: some View {
        if !runtime.permissions.hasScreenRecordingPermission {
            Button {
                runtime.permissions.requestPermission()
            } label: {
                Label("Screen Recording Permission Required…", systemImage: "exclamationmark.triangle")
            }
            Divider()
        }

        if !runtime.sensor.isAvailable {
            Text("Hinge sensor unavailable")
            Divider()
        }

        Toggle("Enable Hinge Effect", isOn: $runtime.isEnabled)
        Toggle("Return When Idle", isOn: $runtime.returnWhenIdle)
        Menu("Appearance") {
            Picker(
                "Appearance",
                selection: Binding(
                    get: { runtime.overlay.style },
                    set: { runtime.overlay.style = $0 })
            ) {
                ForEach(HingeStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }.pickerStyle(.inline)
        }
        Menu("Viewing Position") {
            Picker(
                "Viewing Position",
                selection: Binding(
                    get: { runtime.overlay.viewpoint },
                    set: { runtime.overlay.viewpoint = $0 })
            ) {
                ForEach(HingeViewpoint.allCases) { viewpoint in
                    Text(viewpoint.rawValue).tag(viewpoint)
                }
            }.pickerStyle(.inline)
        }
        Menu("Trigger Angle") {
            Picker("Trigger Angle", selection: $runtime.triggerAngle) {
                Text("75°").tag(75.0)
                Text("90° (Default)").tag(90.0)
                Text("105°").tag(105.0)
                Text("120°").tag(120.0)
                Text("135°").tag(135.0)
            }.pickerStyle(.inline)
        }

        Divider()
        Toggle("Launch at Login", isOn: $runtime.permissions.launchAtLogin)

        Divider()
        Button("Support on Ko-fi…") {
            if let url = URL(string: "https://ko-fi.com/joaofranco03") {
                NSWorkspace.shared.open(url)
            }
        }
        Button("About DuoHinge") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(options: [
                .applicationName: "DuoHinge",
                .credits: NSAttributedString(
                    string:
                        "LidAngleSensor: Sam Henri Gold (Apache 2.0).\nSupport: https://ko-fi.com/joaofranco03"
                ),
            ])
        }
        Button("Quit DuoHinge") {
            runtime.stop()
            NSApp.terminate(nil)
        }.keyboardShortcut("q")
    }
}
