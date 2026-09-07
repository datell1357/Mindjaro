# 마음자로 iOS design contract

This document records the native SwiftUI contract for Todo 8b. The approved pen integration JSON, its four companion documents, and the Swift sources in `Maeumjaro/DesignSystem` are the implementation sources of truth. No web layout, React surface, Lighthouse check, or additional visual research is in scope.

## 1. Atmosphere

The surface is quiet, tactile, and deliberate: warm or deep neutral fields, one calm teal action color, and a restrained coral completion highlight. The interface communicates state through text, shape, position, and value in addition to color. The pen remains an abstract ritual object and does not imitate a medical instrument.

## 2. Color themes

The semantic order is `background / surface / ink / accent / highlight`.

| Theme | Light tokens | Dark/high-contrast behavior |
| --- | --- | --- |
| `quietIvory` | `#FBF7F0 / #FFFCF7 / #1F2328 / #4F7D75 / #E9856B` | Deep warm neutral dark variant; black/white high-contrast variants |
| `midnightInk` | `#0E1418 / #182127 / #F2F4EF / #73B7A9 / #F09A7C` | Deep ink dark variant; high-contrast black/white variants |
| `forestMist` | `#EEF3ED / #FAFCF8 / #1D2B24 / #3E7460 / #C77C67` | Deep green dark variant; high-contrast black/white variants |

`ThemePalette` owns semantic foregrounds, borders, and accent foregrounds. Its contrast driver requires 4.5:1 for normal text and 3:1 for large text. Light accent controls use a dark or approved accent foreground when white would fail. Pro theme selection and downgrade behavior remain Todo 15/16 work.

## 3. SF/Dynamic Type typography

Only the system SF family is used. `DesignTokens.TextStyle` maps to native SwiftUI semantic styles: screen title to `.title`, section title to `.title3`, body to `.body`, secondary to `.subheadline`, and caption to `.caption`. `DesignTokens.font(for:)` is the single token entry point and applies weight after the semantic style so Dynamic Type remains active at accessibility sizes. Consumers must not replace this with fixed `.system(size:)` fonts.

## 4. Spacing and layout

Spacing uses a 4-point base (`4, 8, 12, 16, 20, 24, 32`) with 12/20/28-point corner radii for small/card/large surfaces. Interactive controls reserve at least 44×44 points and use a 3-point focus ring. The pen source canvas is 1024×1536; its frozen ring frame is `(362,136,300,112)` and liquid window is `(449,650,126,414)`. Scaling is uniform so the source geometry does not distort.

## 5. Components and states

The intensity control is a native `ButtonStyle` with quiet, selected, pressed, and focus-visible states. `HeatmapColorScale` uses the domain intensity range and palette semantics. Pen states are `locked`, `ready`, and `complete`; the composited ready layers are `readyBase`, `windowEmpty`, `maskedLiquidFull`, and `ringCylinder`. The exact seven pen artifact IDs are exposed by `PenAssetContract`; no new pen raster or native pen Shape is introduced here. Actual ritual UI consumption is Todo 12.

## 6. Motion and reduced motion

The ring uses one source/destination face with the contract's one-face Y rotation: before halfway, `direction × 180 × progress`; after halfway, `direction × 180 × (progress - 1)`. The ready base excludes the ring rectangle. Liquid top position is `windowHeight × (1 - initialFill × (1 - progress))`; duration and initial fill come only from the domain `IntensityProfile`. Reduce Motion switches the ring to its committed face on release, keeps the same liquid value, and removes decorative surface motion. Fresh pointer-sequence, pause, cancel, and exactly-once persistence behavior belong to Todo 12/16.

## 7. Depth

Depth comes from semantic surface separation, a restrained border, a visible focus ring, and the pen's layered raster contract. No copied gradient or ornamental glass treatment is required. Shadows and blur, if later needed by a component owner, must remain subordinate to text contrast and must not encode state alone.

## 8. Accessibility and debt

The native checks cover token values, WCAG contrast variants, minimum touch target, asset manifest completeness, forbidden user-visible claims, byte-identical original pen copies, frozen geometry, and domain timing delegation. Native SwiftUI and Simulator checks are the applicable verification surface; React/Lighthouse and web breakpoints are not applicable. Remaining debt is actual ritual UI integration, Dynamic Type rendering at every screen, VoiceOver/focus traversal, Reduce Motion interaction, and full Simulator matrix evidence. These are pending gates, not a full UI runtime PASS.
