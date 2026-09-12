# Contributing

Keep changes focused and explain their effect on capture, permissions, sensor
lifetime, and the fixed-plane projection. Do not commit signing credentials,
screen recordings, build products, Xcode user state, or personal diagnostics.
Review images for private information and provenance before publishing them.

## Local checks

```sh
xcrun swift-format lint --recursive DuoHinge
```

After building, check the native Metal pipelines without capturing the desktop:

```sh
swiftc -parse-as-library Tests/MetalChecks.swift -o /tmp/duo-metal-checks
/tmp/duo-metal-checks /path/to/DuoHinge.app/Contents/Resources/default.metallib
```

This verifies neutral-angle orientation and SDR color roundtripping at Retina
scale. Capture maps BGRA pixel buffers directly into Metal; GPU ownership tokens
must outlive command completion. Keep at most one GPU frame in flight. The
motion estimate runs at render cadence with a 25 ms filter (12 ms on reversal).
The motion presentation interpolates real reports at render cadence with a 120 ms
buffer. This avoids visible sensor steps and does not predict past the latest raw
reading. Raw angles control visibility.

Build the app using the command in the README. Keep the system UI accessible in
both light and dark appearance, and respect Reduce Motion for optional animation.
Use comments to explain invariants and hardware workarounds, not to narrate syntax.

## Manual regression checklist

- Grant/deny Screen Recording access on a fresh app identity; retry and relaunch.
- Open/close the lid around 90° and verify stable transitions with no capture feedback.
- Check all appearance presets without changing perspective.
- Open and dismiss the controls; verify sensor ownership remains with the runtime.
- Disable and quit the app while the effect is active; verify the overlay disappears.
- Sleep/wake and connect/disconnect an external display.
- Confirm only an active, unmirrored built-in display receives the effect.
- Test unsupported hardware without assuming Apple Silicon implies sensor support.
- Measure CPU/GPU usage and sensor cadence on real hardware; do not infer performance
  from the configured capture frame interval.

Policy tests are standalone so they do not launch the app, request permissions,
or modify HID settings. Real rendering and hardware behavior still need manual tests.
Permission tests inject fake access checks, requests, and Settings opening. Test
grant/revocation and retry behavior without modifying your real macOS permissions.
For release validation, also check the Relaunch menu action from a signed build:
the replacement must wait for the old process before opening the sensor or stream.
