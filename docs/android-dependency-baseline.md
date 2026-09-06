# Android dependency baseline

Captured on 2026-09-06 for the current Android workspace. The version catalog
(`gradle/libs.versions.toml`) is the source of the locked values below. The
current `app` and `benchmark` build files use the dependencies marked active;
this document does not claim that any version is the online latest.

## Verification result

Live verification through Aside Browser was attempted against official Android
and Kotlin release documentation, but the configured provider returned HTTP 402
`Insufficient credits`. No version was guessed or described as the online
latest. The fallback required by the Task 1 contract was used: stable-looking
release artifacts already resolved in the local Gradle cache, with Android AAR
metadata checked for `compileSdk = 36` compatibility where applicable.

| Component | Locked version | Current use | Local evidence |
| --- | --- | --- | --- |
| Gradle wrapper | 9.7.1 | active | complete local wrapper distribution |
| Android Gradle Plugin | 9.3.2 | active | cached plugin POM; build passes with SDK 36 |
| Kotlin Compose plugin | 2.3.21 | active | cached plugin POM; Kotlin compile passes |
| KSP | 2.3.11 | active, Room processor | cached plugin and implementation artifacts |
| Compose BOM | 2026.06.01 | active | cached BOM maps Compose artifacts to 1.11.4 |
| Activity Compose | 1.13.0 | active | AAR metadata `minCompileSdk=36` |
| Core KTX | 1.18.0 | active | AAR metadata `minCompileSdk=36` |
| Lifecycle runtime KTX | 2.9.4 | active | cached stable artifact; build passes with SDK 36 |
| Material 3 | 1.4.0 | active | cached stable artifact; build passes with SDK 36 |
| Navigation Compose | 2.9.8 | active | implementation in `app/build.gradle.kts`; cached stable artifact |
| Room | 2.8.4 | active | runtime, KTX, compiler, testing; cached stable artifacts |
| DataStore | 1.1.7 | active | DataStore implementation in `app/build.gradle.kts`; cached stable artifact |
| Glance AppWidget | 1.1.1 | active | implementation in `app/build.gradle.kts`; cached stable artifact |
| Play Billing | 9.1.0 | active | implementation in `app/build.gradle.kts`; cached stable artifact |
| JUnit 4 | 4.13.2 | active test | cached artifact; targeted tests pass |

## Authoritative pages to refresh when browser access is available

- Android Gradle Plugin releases: https://developer.android.com/build/releases/gradle-plugin
- Compose BOM mapping: https://developer.android.com/develop/ui/compose/bom/bom-mapping
- AndroidX releases: https://developer.android.com/jetpack/androidx/versions/all-channel
- Activity: https://developer.android.com/jetpack/androidx/releases/activity
- Core: https://developer.android.com/jetpack/androidx/releases/core
- Lifecycle: https://developer.android.com/jetpack/androidx/releases/lifecycle
- Navigation: https://developer.android.com/jetpack/androidx/releases/navigation
- Room: https://developer.android.com/jetpack/androidx/releases/room
- DataStore: https://developer.android.com/jetpack/androidx/releases/datastore
- Glance: https://developer.android.com/jetpack/androidx/releases/glance
- Play Billing release notes: https://developer.android.com/google/play/billing/release-notes
- Kotlin releases: https://kotlinlang.org/docs/releases.html

For dependencies that remain catalog-only, refresh their official stable status
and compatibility before adding them to a build. Treat this offline baseline as
a record of the checked local values, not a claim about the latest release.
