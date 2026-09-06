# Maeumjaro Android performance benchmarks

This module owns instrumentation only. It does not claim that a benchmark or
baseline profile has been generated until a connected device run produces the
artifact.

## Scenarios

- `MaeumjaroMacrobenchmark.coldStartup` and `warmStartup`: launcher startup.
- `widgetDirectColdStartup` and `widgetDirectWarmStartup`: explicit
  `MainActivity` launch using the same `SOURCE=widget` contract as the widget.
- `intensityFiveFrameTiming`: warm steady-state swipe with
  `FrameTimingMetric`.
- `MaeumjaroBaselineProfile.startupAndCoreNavigation`: launcher and direct
  widget entry paths for profile collection.

The widget tests measure app entry from an explicit intent; they do not pretend
to measure launcher rendering or widget refresh. Actual launcher/widget refresh
and subjective haptics remain physical-device gates.

## Required gates

Record each run separately for emulator and physical reference device. The
performance targets are defined in the approved plan: widget refresh p95 <=
500 ms, warm direct launch p95 <= 1.5 s, and cold direct launch p95 <= 3 s.
Do not convert an emulator result into a physical-device result, and preserve a
failed device row with its cause and action.

Baseline Profile packaging is intentionally left as an external compatibility
gate. With the repository's current AGP 9.3.2 and AndroidX Baseline Profile
1.4.1 versions, applying the plugin fails during configuration (`:app is not a
supported android module`). Keeping the plugin/consumer out of these modules
preserves a green Gradle configuration; after a compatible AGP/plugin pair is
selected, wire the generated profile into the release artifact and record that
verification here. This module currently provides only the Macrobenchmark and
profile producer tests.
