<div align="center">

<br />

<img src="assets/DuoHinge.png" width="140" height="140" alt="DuoHinge Icon" style="box-shadow: 0 12px 32px rgba(0, 0, 0, 0.25);" />

# DuoHinge

<br />

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-007AFF?style=flat-square&logo=apple&logoColor=white" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.4_compiler-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.4 compiler" />
  <img src="https://img.shields.io/badge/Metal-3-9945FF?style=flat-square&logo=apple&logoColor=white" alt="Metal 3" />
  <img src="https://img.shields.io/badge/License-MIT-34C759?style=flat-square" alt="MIT License" />
</p>

<p align="center">
  <a href="https://github.com/JoaoFranco03/DuoHinge/releases/latest/download/DuoHinge.dmg">
    <img src="https://img.shields.io/badge/Download_Latest_Release-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download Latest Release" height="38" />
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://ko-fi.com/joaofranco03">
    <img src="https://img.shields.io/badge/Support_on_Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Support on Ko-fi" height="38" />
  </a>
</p>

<br />

</div>

---

## ✦ Overview

**DuoHinge** brings the tactile magic of the **iPhone Duo** folding animation to macOS, transforming your physical MacBook display into an interactive folding optical illusion. By directly tapping into Apple Silicon's built-in **Lid Angle Sensor (`las`)**, DuoHinge projects your live desktop onto a virtual upright 3D plane with realistic raycasted perspective, dual-pass Gaussian glass scattering, and chromatic edge dispersion as you fold the screen closed.

Desktop processing runs on-device and requests the built-in display’s refresh rate (up to **120 Hz** on supported displays; actual frame rate depends on GPU load) using **ScreenCaptureKit** and custom **Metal** shaders, wrapped in a click-through transparent overlay that never interrupts your workflow.

<br />

<div align="center">
  <img src="assets/demo.gif" width="720" alt="DuoHinge Live Demo" style="border-radius: 12px; box-shadow: 0 16px 40px rgba(0, 0, 0, 0.35);" />
</div>

<br />

---

## ✨ Core Highlights

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>📐 Display-Paced Sensor Motion</h3>
      <p>Reads the <code>AppleSPUHIDDriver</code> lid angle sensor and interpolates real readings at render cadence. A 120 ms presentation buffer removes visible sensor steps while preserving the physical motion. The tested M2 Pro delivers roughly 10 readings per second during movement.</p>
    </td>
    <td width="50%" valign="top">
      <h3>💻 Dynamic Live Menu Bar Icon</h3>
      <p>An Apple-style vector MacBook icon that physically rotates and mirrors your display's real-time angle in macOS Dark & Light mode menu bars.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>⚡ Capture Pre-Warming</h3>
      <p>ScreenCaptureKit spins up in a warm standby state 3° before the folding threshold, reducing startup delay. Permission checks and WindowServer registration can still take time.</p>
    </td>
    <td width="50%" valign="top">
      <h3>🔮 Metal Glass Optics</h3>
      <p>High-performance fixed-plane perspective raycasting, 2-pass separable Gaussian blur, and NameDrop-inspired radial chromatic dispersion.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🖱️ 100% Click-Through Overlay</h3>
      <p>Built with non-activating, mouse-transparent AppKit panels (<code>ignoresMouseEvents = true</code>). Keep typing, clicking, and interacting with all macOS apps without focus loss.</p>
    </td>
    <td width="50%" valign="top">
      <h3>🔋 Reduced Idle Rendering</h3>
      <p>Capture and Metal drawing stop outside the pre-warm range. Sensor monitoring, the runtime timer, and permission checks remain active.</p>
    </td>
  </tr>
</table>

<br />

---

## 🎨 Optical Presets & Perspectives

### 1. Appearance Styles
Choose between three handcrafted optical profiles tailored to your aesthetic:

| Style | Characteristics | Best For |
| :--- | :--- | :--- |
| **`Clear`** | Light subtle blur, minimal dimming | Maximum legibility while folding |
| **`Frosted`** *(Default)* | Soft frosted glass diffusion, balanced light transmission | Everyday seamless aesthetic |
| **`Cinematic`** | Deep refraction with prismatic chromatic dispersion | Maximum visual drama & dual-screen illusion |

### 2. Viewing Positions
Adjust the raycast eye-point relative to how you use your MacBook:

- **`Desk`** *(Default)*: Optimized for looking down at your laptop keyboard from an elevated seated angle.
- **`Front`**: Straight-on eye-level perspective for elevated laptop stands or external mounts.

<br />

---

## 📋 System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or later. The project’s deployment target is macOS 14.0; runtime behavior is verified locally only on macOS 27.
- **Hardware**: A MacBook that exposes the supported Apple lid-angle HID device (`vendor 0x05AC`, `product 0x8104`, usage page `0x0020`, usage `0x047F`) and has an active, non-mirrored built-in display. Tested sensor: 14-inch M2 Pro MacBook Pro. Apple Silicon alone does not guarantee support.
- **Permissions**: Screen Recording (required by ScreenCaptureKit for desktop sampling)
- **Toolchain**: Xcode 27.0 with the Metal toolchain (verified locally). It uses the Swift 6.4 compiler in Swift 5 language mode. Other Xcode versions may work but are not verified.

<br />

---

## 💻 Compatibility

### Hardware Detection

At launch, DuoHinge looks for the exact HID device described above. If it is not
available, the app reports that the hinge sensor is unavailable and keeps the
effect inactive. It does not maintain a model whitelist, and the app should not
be advertised as supporting a model until it has been tested on that model. The
M2 Pro sensor measured roughly 10 reports per second while the lid was moving;
display refresh rate does not increase sensor report rate.

### Display &amp; Setup Behavior
- **Built-in Display Only**: DuoHinge targets the internal MacBook display (`CGDisplayIsBuiltin`). External monitors remain completely standard and are never captured or obscured.
- **Clamshell Mode**: With no active built-in display, DuoHinge stops its capture and overlay. It does not claim a specific GPU-usage percentage.
- **Display Mirroring**: If mirroring is enabled, the overlay safely deactivates to prevent recursive screen feedback loops.

<br />

---

## 🚀 Quick Start & Installation

### Download the Latest Release

Download the notarized DMG from [GitHub Releases](https://github.com/JoaoFranco03/DuoHinge/releases/latest), open it, and drag DuoHinge to Applications. On first launch, open the app in the menu bar and grant Screen Recording access when macOS asks.

### Build with Xcode

1. Open `DuoHinge.xcodeproj` in Xcode.
2. Select the `DuoHinge` scheme and target **My Mac**.
3. Select your development team under **Signing & Capabilities**.
4. Press `Cmd + R` to build and run.

<br />

---

## 🏛️ Architecture & Codebase Map

```
DuoHinge/
├── App/
│   └── DuoHingeApp.swift              # App entry point & MenuBarExtra scene lifecycle
├── Core/
│   ├── HingeRuntime.swift             # 100 Hz runtime timer, state coordination & pre-warming
│   ├── HingePolicy.swift              # Pure geometric policy
│   ├── HingeMotion.swift              # Bounded prediction and display-paced filtering
│   ├── HingeMetalRenderer.swift        # Direct pixel-buffer Metal rendering
│   ├── CapturedSurface.swift           # GPU surface ownership
│   ├── HingeViewpoint.swift           # Eye-point coordinates (Desk vs Front)
│   ├── LaptopIconRenderer.swift       # Real-time vector menu bar icon renderer
│   ├── LidAngleSensor.swift           # IOKit HID driver hook (AppleSPUHIDDriver / las)
│   ├── PermissionManager.swift        # Screen capture access & login item manager
│   ├── ScreenCaptureService.swift     # ScreenCaptureKit zero-copy frame streaming
│   └── ScreenOverlayController.swift  # Borderless click-through NSPanel
├── Shaders/
│   └── HingeGlass.metal               # Perspective raycast, Gaussian scattering & dispersion
└── Views/
    └── ContentView.swift              # Native menu dropdown user interface
```

<br />

---

## 🔒 Privacy & Local Processing

- **Local processing**: The app does not save or upload desktop frames. ScreenCaptureKit pixel buffers are mapped into Metal textures. The Support link opens an external website only when selected.
- **Reduced idle work**: Capture and rendering stop outside the pre-warm range. Sensor monitoring, the runtime timer, and permission checks remain active.
- **Safe Window Exclusion**: The overlay window automatically excludes itself from capture to prevent infinite reflection loops.

<br />

---

## Limitations and troubleshooting

- Front and Desk assume a fixed eye position; there is no eye tracking. Prediction trades a small amount of angle accuracy for continuity.
- Disable the effect or quit from the menu to remove the overlay. If unresponsive, quit DuoHinge through Activity Monitor.
- Grant Screen Recording in System Settings → Privacy & Security. The app rechecks access; a relaunch may still be necessary for some signed copies. Do not reset system permissions as a first troubleshooting step.
- Public downloads should be Developer ID signed, notarized, and stapled. An unsigned local test build is not a distributable release.

---

## ☕ Support the Project

If you enjoy using **DuoHinge** and want to say thanks:

<a href="https://ko-fi.com/joaofranco03">
  <img src="https://img.shields.io/badge/Support_on_Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" height="42" alt="Support on Ko-fi" />
</a>

*Every coffee is greatly appreciated!*

<br />

---

## 🌟 From the Developer

| App | Description |
| :---: | :--- |
| <a href="https://havensetup.codes"><img src="assets/HavenIcon.png" width="72" height="72" alt="Haven: Setup Codes" /></a> | **[Haven: Setup Codes](https://havensetup.codes)**<br />Store, organize, and access all your smart home (HomeKit &amp; Matter) setup codes seamlessly in one secure place.<br /><br />🔗 **[havensetup.codes ↗](https://havensetup.codes)** |
| <a href="https://lume.recipes"><img src="assets/LumeIcon.png" width="72" height="72" alt="Lume" /></a> | **[Lume](https://lume.recipes)** *(Coming Soon)*<br />An intelligent, private recipe manager that brings every recipe you love into one calm, beautifully organized cookbook.<br /><br />🔗 **[lume.recipes ↗](https://lume.recipes)** |

<br />

---

## 📜 Attribution & License

- **Sensor Integration**: Adapted from [Sam Henri Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) (Apache-2.0). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **License**: Released under the [MIT License](LICENSE).
