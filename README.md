<div align="center">

<br />

<img src="assets/DuoHinge.png" width="140" height="140" alt="DuoHinge Icon" style="box-shadow: 0 12px 32px rgba(0, 0, 0, 0.25);" />

# DuoHinge

<br />

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.2%2B-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.2+" />
  <img src="https://img.shields.io/badge/Metal-3_Shaders-black?style=flat-square&logo=apple&logoColor=white" alt="Metal 3" />
  <img src="https://img.shields.io/badge/License-MIT-5856D6?style=flat-square" alt="MIT License" />
</p>

<p align="center">
  <a href="https://github.com/joaofranco/DuoHinge/releases/latest">
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

```mermaid
flowchart LR
    A[MacBook Lid Sensor] -->|Hardware reports (~10 Hz measured)| B[Hinge Runtime]
    B -->|Bounded motion prediction| C[ScreenOverlayController]
    D[ScreenCaptureKit] -->|Pre-warmed GPU Texture| E[Metal Shader Pipeline]
    C -->|Real-time Angle & Optics| E
    E -->|Fixed-Plane Raycast + Blur| F[Click-Through Desktop Overlay]
```

<br />

---

## ✨ Core Highlights

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>📐 Display-Paced Sensor Motion</h3>
      <p>Reads the <code>AppleSPUHIDDriver</code> lid angle sensor and evaluates motion at render cadence. Prediction is capped at 60 ms and 3°, with reversal correction and stale-report handling. The tested M2 Pro delivers roughly 10 readings per second during movement.</p>
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
      <h3>🔮 Metal 3 Glass Optics</h3>
      <p>High-performance fixed-plane perspective raycasting, 2-pass separable Gaussian blur, and NameDrop-inspired radial chromatic dispersion.</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🖱️ 100% Click-Through Overlay</h3>
      <p>Built with non-activating, mouse-transparent AppKit panels (<code>ignoresMouseEvents = true</code>). Keep typing, clicking, and interacting with all macOS apps without focus loss.</p>
    </td>
    <td width="50%" valign="top">
      <h3>🧪 Hardware Simulation Mode</h3>
      <p>Simulated angles are available when no sensor is detected. The overlay still requires an active, non-mirrored built-in display; external displays are deliberately excluded.</p>
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

- **Operating System**: macOS 14.0+ deployment target; older-system behavior still needs hardware testing
- **Hardware**: A MacBook exposing the supported lid-angle HID device and an active, non-mirrored built-in display. Tested sensor: 14-inch M2 Pro MacBook Pro. Apple Silicon alone does not guarantee sensor support.
- **Permissions**: Screen Recording (required by ScreenCaptureKit for desktop sampling)
- **Toolchain**: Xcode 26+ (Swift 6.2 compiler) with the Metal toolchain. Verified locally with Xcode 27; Swift 5 language mode is used.

<br />

---

## 🚀 Quick Start & Installation

### Option 1: In-Place Build & Install *(Recommended)*
Builds the optimized Release binary and syncs it into `/Applications/DuoHinge.app` using your signing team. Keeping the same signing identity and bundle identifier can help permission continuity, but macOS may require permission again:

```bash
git clone https://github.com/joaofranco/DuoHinge.git
cd DuoHinge
bash scripts/install.sh DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

The installer refuses to replace a running app and retains a backup of an existing installation. Build failures remain visible in its log. It does not launch the app.

### Option 2: Build with Xcode
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
│   ├── HingeRuntime.swift             # 100 Hz runtime loop, state coordination & pre-warming
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

## 🧪 Automated Testing

Run the hardware-independent policy and permission test suite:

```bash
bash scripts/check.sh
xcodebuild -project DuoHinge.xcodeproj -scheme DuoHinge \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

This unsigned build checks compilation without a developer account; do not install or distribute it as a signed release. See [CONTRIBUTING.md](CONTRIBUTING.md) for GPU and manual checks and [SECURITY.md](SECURITY.md) for reporting sensitive issues.

<br />

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
