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
must outlive command completion. Keep at most two GPU submissions in flight on
the same serial queue. Reject frames from stopped or superseded capture streams.
Motion uses a display-paced critically damped response whose duration follows
report cadence. It trades visual lag for continuity with sparse readings;
the overlay finishes returning to neutral before hiding, with a bounded timeout.

Build the app using the command in the README. Keep the system UI accessible in
both light and dark appearance, and respect Reduce Motion for optional animation.
Use comments to explain invariants and hardware workarounds, not to narrate syntax.

## Manual regression checklist

- Grant/deny Screen Recording access on a fresh app identity; retry and relaunch.
- Open/close the lid around 90° and verify stable transitions with no capture feedback.
- Enable Return When Idle: pause the hinge, verify the desktop returns to normal,
  then move again and verify the effect resumes. Confirm the preference persists.
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
For release validation, quit and reopen a signed build and confirm that only one
instance owns the sensor and capture stream.
