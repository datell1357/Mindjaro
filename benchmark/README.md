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
- `MaeumjaroBaselineProfile.startupAndCoreNavigation`: real app-icon startup,
  onboarding, records, and injection entry for profile collection. It does not
  bypass onboarding or impersonate a widget through debug intent extras.

The widget tests measure app entry from an explicit intent; they do not pretend
to measure launcher rendering or widget refresh. Actual launcher/widget refresh
and subjective haptics remain physical-device gates.

## Required gates

Record each run separately for emulator and physical reference device. The
performance targets are defined in the approved plan: widget refresh p95 <=
500 ms, warm direct launch p95 <= 1.5 s, and cold direct launch p95 <= 3 s.
Do not convert an emulator result into a physical-device result, and preserve a
failed device row with its cause and action.

Baseline Profile packaging is wired through AndroidX Baseline Profile Gradle
plugin `1.5.0-rc02`, which is the locally available plugin pair that configures
successfully with AGP `9.3.2`. The runtime `profileinstaller` dependency remains
at stable `1.4.1`; the plugin is still a release candidate, so upgrading to the
next stable AndroidX release should be treated as a compatibility review.

On 2026-09-06, `generateReleaseBaselineProfile` completed on the API 29 rooted
emulator `AIQuotaFixQA20260905`. The generated source profile contains 20,150
rules, including 1,222 entries referencing `com/maeumjaro`. It is checked in at
`app/src/release/generated/baselineProfiles/baseline-prof.txt` so release builds
can consume it without a connected device. Regenerate after significant code
changes with:

```sh
ANDROID_SERIAL=<device-serial> ./gradlew :app:generateReleaseBaselineProfile
./gradlew :app:bundleRelease
```

This collection run does not establish cold/warm performance targets: the five
Macrobenchmark timing tests were skipped by the profile-generation task. No
separate startup profile was generated. Physical-device timing and actual
launcher/widget coverage remain open gates.
