# 마음자로 iOS asset provenance

This directory records the provenance of the independent iOS brand and ritual assets. The release review status is intentionally `pending` until the public asset, trademark, and final production review is approved.

## SwiftUI consumer names

The asset catalog names are the stable identifiers future SwiftUI code should consume with `Image("...")`:

| Asset ID | SwiftUI consumer | Runtime role |
| --- | --- | --- |
| `PenLocked` | `Image("PenLocked")` | Locked state base |
| `PenReady` | `Image("PenReady")` | Ready state base |
| `PenComplete` | `Image("PenComplete")` | Complete state base |
| `PenRingLocked` | `Image("PenRingLocked")` | Locked ring face |
| `PenRingReady` | `Image("PenRingReady")` | Ready ring face |
| `PenWindowEmpty` | `Image("PenWindowEmpty")` | Fixed empty window layer |
| `PenLiquidFull` | `Image("PenLiquidFull")` | Masked liquid layer |
| `AppIcon` | Xcode `ASSETCATALOG_COMPILER_APPICON_NAME` | 1024px application icon |
| `RitualCompleteV1` | `Bundle` resource `ritual-complete-v1.caf` | Optional completion chime; default off |

## Source separation

- The seven pen PNGs are the user-provided final files from `assets/maeumjaro_pen/`. They were copied byte-for-byte into the app asset catalog. No crop, trace, redraw, or re-encoding was performed.
- `AppIcon-1024.png` is an original, no-reference built-in imagegen output. The original generated 1254px source is preserved at the managed imagegen path in `AssetManifest.json`; the workspace copy is normalized to the required 1024×1024 RGB opaque PNG with macOS `sips`.
- `ritual-complete-v1-source.wav` is the editable 48 kHz mono Int16 source for the short synthesized two-note chime. The app runtime uses only the converted CAF at `iOSApp/Maeumjaro/Resources/Audio/ritual-complete-v1.caf`.

License terms for the user-provided pen assets were not supplied and are not inferred here. The generated icon and synthesized audio carry no third-party license assertion. All entries include source/runtime SHA-256 values and implementation/release review statuses in `AssetManifest.json`.

These assets are visual/audio interaction materials only. They do not make medical, efficacy, dosage, treatment, weight, or diagnosis claims.
