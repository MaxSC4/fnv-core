# FNV Core (fallout-core)

Authoritative server-side core for a Fallout: New Vegas RP server built on Nanos World.  
This repo contains the gameplay logic, data-driven systems, and the client Lua bridge that talks to the WebUI (UI lives in the separate `fallout-ui` package).

## Scope

- RP-focused gameplay foundation (not a full game framework).
- Server-authoritative logic with a thin client bridge.
- Data-driven by design (items, shops, dialogs, currencies, etc.).

## Packages

- `fallout-core`: server logic + client bridge (this repo)
- `fallout-ui`: WebUI only (HTML/CSS/JS, no Lua)

## Dependencies

- `nact` (NPC AI framework)
- `classlib` (required by NACT)
- `csst` (required by NACT)

## Core Principles

- Server authority for all gameplay decisions.
- Data-driven content (DB tables, not hard-coded logic).
- Clean, modular Lua systems with minimal globals.
- Explicit event contracts between server, client bridge, and UI.

## Systems Implemented

### Player & Stats

- S.P.E.C.I.A.L. base stats + derived stats
- HP: Fallout NV formulas, regen over time, death handling
- AP: Fallout NV formulas, regen, sprint/punch consumption and locks
- Carry weight (derived) and weight calculations

### Inventory

- Stacks vs instances (condition, mods, custom name, equipped)
- Categories (weapons/apparel/aid/ammo/misc/notes)
- Weight/value/condition tracking
- Equip/unequip, inspect, drop into world

### Items & Data

- Items DB with weight (WG), condition (CND), description, info, icons
- Value scaling by condition
- Weapon/apparel definitions with visuals and stats

### Weapons

- Equip, holster, reload, ammo consumption from inventory
- Condition decay per shot + damage scaling
- HUD ammo sync + weapon condition

### Shops (Barter)

- Vendor/player inventories, cart system, pricing mods
- Partial selection, confirm/close flows
- Condition-aware prices

### Dialog

- Server-authoritative dialog sessions
- Data-driven dialog DB per NPC
- Actions: open shop, give item, add money, set flags

### Loot (World)

- Drop any item into the world (prop fallback to cube)
- Pickup with look + proximity + prompt
- Instance data preserved on drop

### Containers

- Static world containers with inventory
- Floating list on look (no input lock)
- Transfer menu (full screen, locked inputs, move/take all)

### NPC & HUD

- NPC registry, interact prompts, enemy target HUD
- Hostile tags + HP bars on target

## UI Event Contracts (Bridge)

These are the core events emitted/consumed by the UI. The UI package listens to these and forwards player intent back to core.

### UI Mode

- `FNV:UI:SetMode` -> `{ mode = "gameplay" | "dialog" | "shop" | "inventory" | "container" }`

### Dialog

- `FNV:Dialog:Open` -> `{ open=true, npc, node, options, selected, can_close }`
- `FNV:Dialog:Close` -> `{ open=false }`
- UI -> `FNV:Dialog:Choose`, `FNV:Dialog:CloseRequest`

### Shop

- `FNV:Shop:Open` -> `{ vendor, player, currency, selected, cart, ... }`
- `FNV:Shop:Close` -> `{ open=false }`
- UI -> `FNV:Shop:Select`, `FNV:Shop:Accept`, `FNV:Shop:CloseRequest`

### Inventory

- `FNV:Inv:Open` -> full inventory payload
- `FNV:Inv:Close` -> `{ open=false }`
- UI -> `FNV:Inv:Action`, `FNV:Inv:CloseRequest`

### Containers (Floating)

- `FNV:Container:Open` -> `{ open=true, container, items, selected }`
- `FNV:Container:Close` -> `{ open=false }`

### Containers (Transfer)

- `FNV:Container:TransferOpen` -> `{ open=true, mode="transfer", container, player, player_items, container_items, selected }`
- `FNV:Container:TransferClose` -> `{ open=false }`
- UI -> `FNV:Container:TransferMove`, `FNV:Container:TransferTakeAll`, `FNV:Container:TransferCloseRequest`

### HUD

- `FNV:HUD:Sync` -> `{ hp, hp_max, ap, ammo, equip, cnd, money }`
- `FNV:HUD:Notify` -> `{ text, ms }`
- `HUD:EnemyTarget` -> `{ visible, name, hp_pct }`

## Data-Driven Tables

- `Server/systems/inventory/items_db.lua`
- `Server/systems/shops/shop_db.lua`
- `Server/systems/dialog/dialog_db.lua`
- `Server/systems/economy/currency_db.lua`

## Notes (Webhook Test)

- UI package is expected to implement all WebUI listeners and emit intent events back to core.
- Client Lua remains a bridge: input/focus handling + remote dispatch only.

## License

Private project, internal use for the FNV RP server.
