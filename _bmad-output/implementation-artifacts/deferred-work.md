# Deferred Work

## Deferred from: code review of story 1-1 (2026-04-01)

- `fatalError` on `ModelContainer` failure in `DictlyiOSApp.swift` and `DictlyMacApp.swift` — no recovery path if store is corrupted or migration fails. Consider retry-with-delete or error UI in a future story.
- `Session.locationLatitude` and `Session.locationLongitude` are independent optionals — no enforcement that both are set or both are nil. Add validation when location features are implemented.
- App-level test targets (`DictlyiOSTests`, `DictlyMacTests`) exist as directories but are not wired into `project.yml` — add when first app-layer tests are written.

## Deferred from: code review of story 1-2 (2026-04-01)

- WCAG AA contrast claims in `DictlyColors.TagCategory` doc comment may be inaccurate for some color/surface combinations (e.g., `story` #D97706 on light surface #F2EDE7). Verify actual contrast ratios and update or remove the claim.
- No `accessibilityReduceTransparency`/`increaseContrast` palette handling — background (#FAF8F5) and surface (#F2EDE7) are very close in lightness, making boundaries hard to distinguish for some users. Consider an increased-contrast palette variant.

## Deferred from: code review of 1-3-campaign-management (2026-04-01)

- `campaign.sessions.count` in `CampaignRowView` triggers a lazy relationship fault on every row render. With many campaigns this causes N relationship faults during list scroll. Consider prefetching or a denormalized session count property when scaling.

## Deferred from: code review of 1-4-session-organization-within-campaigns (2026-04-01)

- `formatDuration` in `SessionListRow` does not guard against negative `TimeInterval` values. Currently impossible (duration set to 0 on creation, real values from recording engine in Story 2.x), but add a `max(0, duration)` clamp when recording engine is implemented.
- `SessionListRow.dateFormatter` uses system locale without explicit locale setting — pre-existing pattern from `CampaignRowView`. May produce unexpected date formats on non-Gregorian calendars. Consider standardizing locale handling across all formatters.

## Deferred from: code review of 1-5-tag-category-and-tag-management (2026-04-01)

- `DefaultTagSeeder.seedIfNeeded` performs a read-then-write (`fetchCount` → insert loop) with no transaction lock. In multi-window scenarios, concurrent calls could both observe `existingCount == 0` and insert duplicate defaults. Extremely unlikely in single-window iOS app but should be addressed if multi-window support is added.
