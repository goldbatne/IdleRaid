# Growth v2 integration plan

Source: `IdleRaid_Codex_Integration_v2.md` (IdleRaid test design, not competitor formulas).

## Existing invariants

- Server validates BasicAttack target, range, cooldown, actual damage and kill reward.
- EnemyService owns HP; multiple Slimes and one Raid boss work independently.
- EquipmentService checks inventory ownership; StatService owns FinalAttack/Defense.
- RaidService owns participants, boss patterns, dash, HP, rewards and cleanup.
- Client owns input, auto movement, UI and short visual effects. `IdleRaid.rbxl` and Studio objects are user assets and must remain untouched.
- Current runtime PlayerData, Inventory and Equipment are separate and unsaved. Level/Exp are mutable runtime values. StateSyncService sends full snapshots.

## Checkpoints

1. Define capped exact integer economy, GrowthConfig, level thresholds, gate rules and a simulator that loads the same Luau modules.
2. Consolidate one versioned profile containing growth, existing currency/inventory/equipment, ownership, gate records, settlement cursor and receipt ledger. Add migration, mock and production DataStore adapter with session ownership and save serialization.
3. Integrate online/offline training, battle rewards, facility purchases, free/ticket breakthrough, token exchange and gate-qualified raid clear.
4. Add disabled-by-default developer products with fixed ownership contracts, receipt idempotency and Studio-only grants. Keep all ProductIds and prices unset.
5. Split state synchronization and rebuild HUD/Character/Bag/Growth/Raid menus with Korean strings, revision checks, PC and narrow layouts.
6. Run economy/gate/persistence/security/regression and UI Play tests. Produce CSV, design and test report; capture PC/narrow Studio views. Merge to main only if no critical data-loss or gate-bypass defect remains.

## Explicit limits

- No actual purchase prompt, Robux spend, operating DataStore reset/change, or public publish.
- Published Experience DataStore and real-device behavior require separate evidence; mock results must be labeled.
- Previously existing untracked `IdleRaid.rbxl` remains out of commits.
