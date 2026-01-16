-- CORE
Package.Require("Server/core/log.lua")
Package.Require("Server/core/players.lua")
Package.Require("Server/core/autosave.lua")

-- PERSISTENCE
Package.Require("Server/systems/persistence/package_data.lua")
Package.Require("Server/systems/persistence/persistence.lua")

-- INVENTORY
Package.Require("Server/systems/inventory/items_db.lua")
Package.Require("Server/systems/inventory/inventory.lua")
Package.Require("Server/systems/inventory/inventory_store.lua")
Package.Require("Server/systems/inventory/item_use.lua")
Package.Require("Server/systems/inventory/inventory_service.lua")
Package.Require("Server/systems/loot/loot_service.lua")
Package.Require("Server/systems/loot/container_service.lua")
Package.Require("Server/systems/loot/container_store.lua")

-- ECONOMY / WALLET
Package.Require("Server/systems/economy/currency_db.lua")
Package.Require("Server/systems/economy/wallet.lua")
Package.Require("Server/systems/economy/wallet_store.lua")

-- PERSISTENCE (depends on inventory + wallet)
Package.Require("Server/systems/persistence/player_state_store.lua")

-- SHOPS
Package.Require("Server/systems/shops/shop_db.lua")
Package.Require("Server/systems/shops/shop_service.lua")

-- UI
Package.Require("Server/systems/ui/hud_sync.lua")
Package.Require("Server/systems/ui/hud_notify.lua")

-- PLAYER
Package.Require("Server/systems/player/ap.lua")
Package.Require("Server/systems/player/state_api.lua")
Package.Require("Server/systems/player/ap_input.lua")
Package.Require("Server/systems/player/hp.lua")
Package.Require("Server/systems/player/special.lua")

-- ADMIN
Package.Require("Server/systems/admin/auth_admin.lua")
Package.Require("Server/systems/admin/commands.lua")

-- NPC
Package.Require("Server/systems/npc/npc_service.lua")
Package.Require("Server/systems/npc/pawn_test.lua")

-- DIALOG
Package.Require("Server/systems/dialog/dialog_db.lua")
Package.Require("Server/systems/dialog/dialog_actions.lua")
Package.Require("Server/systems/dialog/dialog_service.lua")

-- BOOT
Package.Require("Server/core/bootstrap.lua")
BOOT.Start()

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local DEV_RESET_INVENTORY = true
local DEFAULT_SPAWN_POS = Vector(1400, 800, 300)
local function GetPlayerID(player)
    if player.GetSteamID then
        return tostring(player:GetSteamID())
    end
    if player.GetAccountID then
        return tostring(player:GetAccountID())
    end
    return tostring(player:GetName())
end

local function SpawnCharacterFor(player, state)
    -- Nettoie l'ancien character (important sur reload / respawn)
    local old = player:GetControlledCharacter()
    if old then
        old:Destroy()
    end

    local spawn_pos = DEFAULT_SPAWN_POS
    local character = Character(spawn_pos, Rotator(0, 0, 0), "nanos-world::SK_Female")
    if character.SetCanDrop then
        character:SetCanDrop(false)
    end
    player:Possess(character)
    return character
end

local function SyncHUDSafe(player, state)
    -- Petit délai: laisse le temps au package UI client de recharger et SubscribeRemote
    Timer.SetTimeout(function()
        if player and state then
            HUD_SYNC.Send(player, state)
        end
    end, 250)
end

local function SeedTestInventory(inv)
    INV.Add(inv, "water", 5)
    INV.Add(inv, "stimpack", 30)
    INV.Add(inv, "radaway", 2)
    INV.Add(inv, "med_x", 2)
    INV.Add(inv, "nuka_cola", 2)
    INV.Add(inv, "sunset_sarsaparilla", 2)
    INV.Add(inv, "cram", 2)
    INV.Add(inv, "sugar_bombs", 1)
    INV.Add(inv, "pork_beans", 1)
    INV.Add(inv, "whiskey", 1)
    INV.Add(inv, "buffout", 1)
    INV.Add(inv, "jet", 1)
    INV.Add(inv, "repair_kit", 1)
    INV.Add(inv, "bobby_pin", 10)
    INV.Add(inv, "lottery_ticket", 1)
    INV.Add(inv, "fusion_cell", 25)
    INV.Add(inv, "ammo_9mm", 60)
    INV.Add(inv, "ammo_556", 2000)
    INV.Add(inv, "repair_kit", 2)
    INV.Add(inv, "scrap_metal", 5)
    INV.Add(inv, "wrench", 1)
    INV.Add(inv, "note_vault", 1)
    INV.Add(inv, "pistol_10mm", 1, { condition = 80 })
    INV.Add(inv, "pistol_10mm", 1, { condition = 20 })
    INV.Add(inv, "varmint_rifle", 1, { condition = 65 })
    INV.Add(inv, "vault_suit_21", 1, { condition = 95 })
    INV.Add(inv, "vault_suit_21", 1, { condition = 15 })
    INV.Add(inv, "ncr_beret", 1, { condition = 90 })
end

local function EnsureInventory(state)
    if not state then return false end
    if INV and INV.New then return true end
    state.inventory = state.inventory or {
        _version = 2,
        stacks = {},
        instances = {},
        next_instance_id = 1
    }
    if LOG and LOG.Warn then
        LOG.Warn("INV not ready during Load; skipping inventory seed.")
    end
    return false
end

-- ------------------------------------------------------------
-- Reload-safe: quand le package (re)charge, respawn les joueurs connectés
-- ------------------------------------------------------------
Package.Subscribe("Load", function()
    for _, player in pairs(Player.GetAll()) do
        local player_id = GetPlayerID(player)

        -- Si on a déjà le state en mémoire, on le garde, sinon on le (re)charge
        local state = PLAYERS.GetState(player)
        if not state then
            state = select(1, PLAYER_STATE.Load(player_id))
            PLAYERS.Set(player, player_id, state)
        end

        -- Dev: donne 5000 caps à chaque reload de package
        if state and state.wallet then
            WALLET.Add(state.wallet, "caps", 5000)
        end

        -- Dev: ajoute quelques items pour tester l'inventaire
        if state and state.inventory and EnsureInventory(state) then
            if DEV_RESET_INVENTORY then
                state.inventory = INV.New()
                SeedTestInventory(state.inventory)
            else
                local entries = INV.GetEntries and INV.GetEntries(state.inventory) or {}
                if #entries == 0 then
                    SeedTestInventory(state.inventory)
                end
            end
        end

        state.pos = DEFAULT_SPAWN_POS
        local character = SpawnCharacterFor(player, state)
        if INV_SERVICE and INV_SERVICE.ApplyEquipped then
            INV_SERVICE.ApplyEquipped(player)
        end
        if HP and HP.BindCharacter then
            HP.BindCharacter(player, state, character)
        end
        SyncHUDSafe(player, state)

        LOG.Info("[Reload] Respawn + HUD sync for " .. player:GetName())
    end

    NPC.DespawnAll()
    NPC.Spawn(
        "veronica",
        Vector(1400, 1000, 300),
        Rotator(0, 180, 0),
        "Veronica"
    )
    NPC.Spawn(
        "raider_debug",
        Vector(1600, 800, 300),
        Rotator(0, 90, 0),
        "Raider"
    )
    if NPC.SetHostile then
        NPC.SetHostile("raider_debug", true)
    end
    if NPC.AttachDebugHP then
        NPC.AttachDebugHP("raider_debug", 250)
    end
    if PAWN_TEST and PAWN_TEST.Start then
        PAWN_TEST.Start(Vector(1500, 700, 300))
    end

    if CONTAINER and CONTAINER.Spawn then
        CONTAINER.Spawn(
            "stash_01",
            Vector(100, 0, 0),
            Rotator(0, 0, 0),
            "Caisse rouillée",
            "nanos-world::SM_Crate_07"
        )
        local stash = CONTAINER.List and CONTAINER.List["stash_01"]
        if stash and stash.inventory then
            local entries = INV.GetEntries(stash.inventory)
            if not entries or #entries == 0 then
                INV.Add(stash.inventory, "water", 2)
                INV.Add(stash.inventory, "stimpack", 1)
                INV.Add(stash.inventory, "ammo_9mm", 20)
                if CONTAINER_STORE and CONTAINER_STORE.Save then
                    CONTAINER_STORE.Save("stash_01", stash.inventory)
                end
            end
        end
    end
end)

-- ------------------------------------------------------------
-- DEV OFFLINE TEST
-- ------------------------------------------------------------
local DEV_OFFLINE_TEST = false
if DEV_OFFLINE_TEST then
    Timer.SetTimeout(function()
        LOG.Info("OFFLINE TEST: start")

        -- Persistence test (table TOML)
        local id = "DEV_TEST"
        local s1, created1 = PERSIST.LoadOrCreate(id)
        LOG.Info("PERSIST: created=" .. tostring(created1) .. " pos=" .. tostring(s1.pos))

        s1.pos = Vector(111, 222, 333)
        s1.last_seen = os.time()
        PERSIST.Save(id, s1)
        LOG.Info("PERSIST: saved pos=Vector(111,222,333)")

        local s2, created2 = PERSIST.LoadOrCreate(id)
        LOG.Info("PERSIST: reload created=" .. tostring(created2) .. " pos=" .. tostring(s2.pos))

        local ok = (math.floor(s2.pos.X) == 111 and math.floor(s2.pos.Y) == 222 and math.floor(s2.pos.Z) == 333)
        LOG.Info("PERSIST: OK=" .. tostring(ok))

        -- Inventory test via store
        local inv_id = "DEV_INV_TEST"
        local st_inv = { hp = 50, inventory = INV_STORE.Load(inv_id) }

        INV.Add(st_inv.inventory, "water", 2)
        INV.Add(st_inv.inventory, "stimpack", 1)

        LOG.Info("INV start: water=" .. INV.Count(st_inv.inventory, "water")
            .. " stim=" .. INV.Count(st_inv.inventory, "stimpack")
            .. " hp=" .. st_inv.hp)

        local ok1, r1 = ITEM_USE.Use(st_inv, "water")
        LOG.Info("USE water: ok=" .. tostring(ok1) .. " r=" .. tostring(r1) .. " hp=" .. st_inv.hp)

        local ok2, r2 = ITEM_USE.Use(st_inv, "stimpack")
        LOG.Info("USE stim: ok=" .. tostring(ok2) .. " r=" .. tostring(r2) .. " hp=" .. st_inv.hp)

        LOG.Info("INV after: water=" .. INV.Count(st_inv.inventory, "water")
            .. " stim=" .. INV.Count(st_inv.inventory, "stimpack"))

        INV_STORE.Save(inv_id, st_inv.inventory)
        LOG.Info("INV saved")

        -- Wallet test via store (tables TOML)
        local pid = "DEV_WALLET_TEST"
        local st_w = { wallet = WALLET_STORE.Load(pid) }

        WALLET.Add(st_w.wallet, "caps", 100)
        WALLET.Add(st_w.wallet, "casino_ultraluxe", 50)

        LOG.Info("caps=" .. WALLET.Get(st_w.wallet, "caps")
            .. " ultra=" .. WALLET.Get(st_w.wallet, "casino_ultraluxe"))

        WALLET.Spend(st_w.wallet, "caps", 30)
        WALLET.Spend(st_w.wallet, "casino_ultraluxe", 10)

        LOG.Info("after spend caps=" .. WALLET.Get(st_w.wallet, "caps")
            .. " ultra=" .. WALLET.Get(st_w.wallet, "casino_ultraluxe"))

        WALLET_STORE.Save(pid, st_w.wallet)
        LOG.Info("WALLET saved")
    end, 1000)
end

-- ------------------------------------------------------------
-- Player events
-- ------------------------------------------------------------
Player.Subscribe("Spawn", function(player)
    local player_id = GetPlayerID(player)

    -- Charge state et stocke en mémoire
    local state, created = PLAYER_STATE.Load(player_id)
    PLAYERS.Set(player, player_id, state)

    -- Spawn character à la pos persistée
    if state then
        state.pos = DEFAULT_SPAWN_POS
    end
    local character = SpawnCharacterFor(player, state)
    if INV_SERVICE and INV_SERVICE.ApplyEquipped then
        INV_SERVICE.ApplyEquipped(player)
    end
    if HP and HP.BindCharacter then
        HP.BindCharacter(player, state, character)
    end

    -- HUD sync
    SyncHUDSafe(player, state)

    LOG.Info("Spawn: " .. player:GetName() .. " id=" .. player_id .. (created and " (created)" or " (loaded)"))
end)

Player.Subscribe("Destroy", function(player)
    local state = PLAYERS.GetState(player)
    local player_id = PLAYERS.GetID(player)

    if state and player_id then
        local char = player:GetControlledCharacter()
        if char then
            state.pos = char:GetLocation()
        end
        state.last_seen = os.time()

        PLAYER_STATE.Save(player_id, state)
        LOG.Info("Saved on leave: " .. tostring(player_id))
    end

    local char = player:GetControlledCharacter()
    if char then
        char:Destroy()
    end

    PLAYERS.Remove(player)
end)

