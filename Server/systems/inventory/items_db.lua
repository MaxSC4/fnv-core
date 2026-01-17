ITEMS = {
    water = {
        name = "Eau Purifiée",
        desc = "Une eau propre et sans radiations. Rare dans les terres désolées, presque un luxe dans le Mojave. Idéale pour se désaltérer sans effets secondaires.",
        info = "Hydrate légèrement. Usage courant dans le Mojave.",
        category = "aid",
        wg = 1.00,
        cnd = 100,
        icon = "icons/items/items_water.png",
        value = 5,
        max_stack = 50,
        use = { type = "heal", amount = 5 }
    },

    stimpack = {
        name = "Stimpak",
        desc = "Une dose de médecine portative pour te remettre vite sur pied. Soigne les blessures légères et te permet de repartir.",
        info = "Régénère 20% des HP max (4x10).",
        category = "aid",
        wg = 1.00,
        cnd = 100,
        icon = "icons/items/items_stimpack.png",
        value = 30,
        max_stack = 50,
        use = { type = "heal_pct", pct = 0.20, duration = 4.0, ticks = 4 }
    },

    ammo_9mm = {
        name = "9mm Round",
        desc = "Common handgun ammo.",
        category = "ammo",
        wg = 0.01,
        cnd = 100,
        value = 1,
        max_stack = 200
    },

    ammo_556 = {
        name = "5.56mm Round",
        desc = "Rifle ammo for light weapons.",
        category = "ammo",
        wg = 0.02,
        cnd = 100,
        value = 2,
        max_stack = 2000
    },

    pistol_10mm = {
        name = "10mm Pistol",
        desc = "Standard sidearm.",
        category = "weapons",
        item_icon = "weapons/weapons_10mm_pistol.png",
        str = 2,
        ammo_type = "9mm",
        effects = {},
        weapon = {
            mesh = "nanos-world::SK_Pistol",
            ammo = 12,
            reserve = 120,
            ammo_type = "ammo_9mm",
            damage = 18,
            spread = 10,
            recoil = 0.2,
            cadence = 0.15,
            infinite_ammo = true,
            particles = {
                bullet_trail = "nanos-world::P_Bullet_Trail",
                barrel = "nanos-world::P_Weapon_BarrelSmoke",
                shells = "nanos-world::P_Weapon_Shells_762x39"
            }
        },
        wg = 3.0,
        cnd = 100,
        value = 120,
        max_stack = 1
    },

    varmint_rifle = {
        name = "Varmint Rifle",
        desc = "Light rifle for small game.",
        category = "weapons",
        item_icon = "weapons/weapons_varmint_rifle.png",
        str = 4,
        ammo_type = "5.56mm",
        effects = {},
        weapon = {
            mesh = "nanos-world::SK_AK47",
            ammo = 5,
            reserve = 60,
            ammo_type = "ammo_556",
            damage = 25,
            spread = 8,
            recoil = 0.25,
            cadence = 0.18,
            infinite_ammo = false,
            handling_mode = HandlingMode.DoubleHandedWeapon,
            holster = {
                kind = "skeletal",
                socket = "holster_weapon",
                mesh = "nanos-world::SK_AK47",
                location = Vector(-10, -15, 35),
                rotation = Rotator(0, 90, 0)
            },
            particles = {
                bullet_trail = "nanos-world::P_Bullet_Trail",
                barrel = "nanos-world::P_Weapon_BarrelSmoke",
                shells = "nanos-world::P_Weapon_Shells_762x39"
            }
        },
        wg = 4.5,
        cnd = 100,
        value = 180,
        max_stack = 1
    },

    vault_suit_21 = {
        name = "Combinaison de l'Abri 21",
        desc = "Une tenue Vault-Tec numérotée, résistante et encore propre. Un classique du Mojave.",
        category = "apparel",
        type = "léger",
        slot = "body",
        dt = 6,
        visual = { kind = "skeletal", socket = "full", mesh = "nanos-world::SK_CasualSet" },
        wg = 2.5,
        cnd = 100,
        icon = "apparel/vault_suit_21.png",
        value = 55,
        max_stack = 1
    },

    ncr_beret = {
        name = "Béret de la RNC",
        desc = "Un béret militaire de la RNC. Simple, discret, mais reconnaissable.",
        category = "apparel",
        type = "léger",
        slot = "head",
        dt = 2,
        visual = { kind = "static", socket = "hair", mesh = "nanos-world::SM_Hair_Kwang", bone = "hair_female" },
        wg = 0.6,
        cnd = 100,
        icon = "apparel/item_ncr_beret.png",
        value = 35,
        max_stack = 1
    },

    med_x = {
        name = "Med-X",
        desc = "Painkiller with combat benefits.",
        category = "aid",
        wg = 0.5,
        cnd = 100,
        value = 25,
        max_stack = 20
    },

    radaway = {
        name = "RadAway",
        desc = "Reduces radiation levels.",
        category = "aid",
        wg = 0.5,
        cnd = 100,
        value = 40,
        max_stack = 20
    },

    scrap_metal = {
        name = "Scrap Metal",
        desc = "Useful for repairs and crafting.",
        category = "misc",
        wg = 2.0,
        cnd = 100,
        value = 5,
        max_stack = 50
    },

    wrench = {
        name = "Wrench",
        desc = "A simple tool.",
        category = "misc",
        wg = 3.0,
        cnd = 100,
        value = 12,
        max_stack = 1
    },

    note_vault = {
        name = "Vault Note",
        desc = "A handwritten note.",
        category = "notes",
        wg = 0.1,
        cnd = 100,
        value = 0,
        max_stack = 1
    },

    nuka_cola = {
        name = "Nuka-Cola",
        desc = "Un soda sucré très populaire avant-guerre. Toujours un petit boost de moral.",
        info = "Restaure un peu d'énergie.",
        category = "aid",
        wg = 1.0,
        cnd = 100,
        icon = "icons/items/items_cola.png",
        value = 8,
        max_stack = 20
    },

    sunset_sarsaparilla = {
        name = "Sunset Sarsaparilla",
        desc = "Boisson gazeuse du Mojave, plus douce que la Nuka-Cola.",
        info = "Restaure un peu d'énergie.",
        category = "aid",
        wg = 1.0,
        cnd = 100,
        icon = "icons/items/items_sunset_sarsp.png",
        value = 6,
        max_stack = 20
    },

    cram = {
        name = "Cram",
        desc = "Viande en conserve douteuse, mais ça remplit l'estomac.",
        info = "Nourrit légèrement.",
        category = "aid",
        wg = 1.0,
        cnd = 100,
        icon = "icons/items/items_cram.png",
        value = 7,
        max_stack = 10
    },

    sugar_bombs = {
        name = "Sugar Bombs",
        desc = "Céréales très sucrées, un classique pré-guerre.",
        info = "Nourrit légèrement.",
        category = "aid",
        wg = 0.7,
        cnd = 100,
        icon = "icons/items/items_sugar_bombs.png",
        value = 5,
        max_stack = 10
    },

    pork_beans = {
        name = "Pork 'n' Beans",
        desc = "Haricots au porc en conserve. Pas très fin mais efficace.",
        info = "Nourrit légèrement.",
        category = "aid",
        wg = 1.0,
        cnd = 100,
        icon = "icons/items/items_pork_beans.png",
        value = 6,
        max_stack = 10
    },

    whiskey = {
        name = "Whiskey",
        desc = "Alcool fort. Redonne du courage, pas toujours de la lucidité.",
        info = "Effet temporaire. Peut déshydrater.",
        category = "aid",
        wg = 1.0,
        cnd = 100,
        icon = "icons/items/items_whiskey.png",
        value = 15,
        max_stack = 10
    },

    buffout = {
        name = "Buffout",
        desc = "Drogue de performance. Rend plus fort, mais avec un contrecoup.",
        info = "+Force temporaire.",
        category = "aid",
        wg = 0.1,
        cnd = 100,
        icon = "icons/items/item_buffout.png",
        value = 35,
        max_stack = 10
    },

    jet = {
        name = "Jet",
        desc = "Inhalant très addictif. Ralentit la perception du temps.",
        info = "Temps dilaté temporairement.",
        category = "aid",
        wg = 0.1,
        cnd = 100,
        icon = "icons/items/item_jet.png",
        value = 40,
        max_stack = 10
    },

    repair_kit = {
        name = "Kit de réparation",
        desc = "Outils compacts pour effectuer des réparations rapides.",
        info = "Permet de réparer une arme ou armure.",
        category = "misc",
        wg = 2.0,
        cnd = 100,
        icon = "icons/items/item_repair_kit.png",
        value = 45,
        max_stack = 5,
        actions = { "use" },
        use = { type = "repair_kit" }
    },

    bobby_pin = {
        name = "Épingle à cheveux",
        desc = "Épingle à cheveux utile pour crocheter des serrures.",
        info = "Utilisée pour le lockpick.",
        category = "misc",
        wg = 0.01,
        cnd = 100,
        icon = "icons/items/item_bobby_pin.png",
        value = 1,
        max_stack = 100
    },

    lottery_ticket = {
        name = "Ticket de loterie",
        desc = "Un ticket de loterie poussiéreux. Qui sait ?",
        info = "Objet de chance ou de quête.",
        category = "misc",
        wg = 0.01,
        cnd = 100,
        icon = "icons/items/item_lottery_ticket.png",
        value = 2,
        max_stack = 10
    },

    fusion_cell = {
        name = "Cellule d'énergie",
        desc = "Munition standard pour armes à énergie.",
        info = "Utilisée par les armes laser.",
        category = "ammo",
        wg = 0.02,
        cnd = 100,
        icon = "icons/items/items_fusion_cell.png",
        value = 3,
        max_stack = 200
    }
}

function ITEMS.Get(id)
    return ITEMS[id]
end
