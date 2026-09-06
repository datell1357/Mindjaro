# Customization integration requirements

`CustomizationController` is deliberately independent from the app shell. The
composition root must provide the process-scoped `AppStateStore`, the Room
`CustomPhraseRepository`, the live `EntitlementRepository`, and a persistent
`WidgetPresetStore` adapter.

- Collect `CustomizationController.load()` when the customization route enters
  and refresh the screen state after every write.
- Keep the selected theme in `AppStateStore.themeId`; the controller falls back
  to `ThemeCatalog.default` whenever entitlement is not confirmed Pro.
- Route phrase create/edit/archive actions through the controller so
  `CustomPhraseValidator` and the Room repository remain the only write gate.
  Archived phrases stay visible in history but are excluded from selection.
- Connect widget IDs from `GlanceAppWidgetManager` to the persistent preset
  adapter. Presets must be removed from that adapter in the widget receiver's
  `onDeleted` callback.
- The screen's locked controls are explanatory only; they must not perform a
  purchase or grant entitlement. Billing UI owns purchase/restore actions.

The current screen exposes the state and callbacks required by the shell, but
does not modify `AppContainer`, navigation, billing, or widget receiver code.
