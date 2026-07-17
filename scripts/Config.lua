-- Shared tuning for the Game Jam prototype. All coordinates use room space: 0..1.
local Config = {
    Title = "弹反之室",
    Debug = false,

    Room = {
        minX = 0.08,
        maxX = 0.92,
        minY = 0.14,
        maxY = 0.88,
        introDuration = 1.0,
        clearDuration = 1.1,
        dropPickupDuration = 5.0,
        doorwayWidth = 0.1,
    },

    Player = {
        maxHp = 3,
        radius = 0.035,
        speed = 0.54,
        invulnerabilityDuration = 0.62,
        parryWindow = 0.22,
        perfectParryWindow = 0.10,
        parryCooldown = 0.45,
        parryRange = 0.19,
        parryHalfAngleCos = math.cos(math.rad(60)), -- 120 degree cone
        meleeKnockback = 0.48,
    },

    Enemy = {
        melee = {
            hp = 1,
            radius = 0.04,
            telegraphDuration = 0.72,
            dashDuration = 0.34,
            recoveryDuration = 0.7,
            dashSpeed = 0.9,
            moveSpeed = 0.19,
            preferredDistance = 0.16,
            strafeStrength = 0.35,
            touchDamage = 1,
        },
        ranged = {
            hp = 1,
            radius = 0.04,
            telegraphDuration = 0.86,
            recoveryDuration = 0.95,
            touchDamage = 1,
            projectileSpeed = 0.48,
            moveSpeed = 0.15,
            preferredDistance = 0.37,
            minimumDistance = 0.25,
            maximumDistance = 0.48,
            strafeStrength = 0.8,
        },
        boss = {
            hp = 8,
            radius = 0.075,
            telegraphDuration = 0.75,
            dashDuration = 0.42,
            recoveryDuration = 0.62,
            dashSpeed = 0.82,
            projectileSpeed = 0.55,
            touchDamage = 1,
            moveSpeed = 0.11,
            preferredDistance = 0.31,
            minimumDistance = 0.25,
            maximumDistance = 0.42,
            strafeStrength = 0.55,
        },
    },

    Projectile = {
        radius = 0.016,
        lifetime = 4.0,
        reflectedSpeedMultiplier = 1.45,
        playerDamage = 1,
    },

    Chests = {
        chance = 0.10,
        pickupRadius = 0.06,
    },

    Upgrades = {
        definitions = {
            { id = "wide_guard", name = "广域招架", description = "招架扇形扩大 12°", maxStacks = 2, color = { 115, 232, 255 } },
            { id = "quick_hands", name = "疾速招架", description = "招架冷却缩短 0.06 秒", maxStacks = 3, color = { 165, 140, 255 } },
            { id = "heavy_return", name = "沉重反击", description = "反射投射物伤害 +1", maxStacks = 3, color = { 255, 164, 105 } },
            { id = "repulse", name = "震荡反冲", description = "近战反制击退距离增加", maxStacks = 3, color = { 255, 115, 150 } },
            { id = "piercing_echo", name = "穿透回响", description = "反射投射物额外穿透 1 个敌人", maxStacks = 2, color = { 255, 220, 110 } },
            { id = "perfect_repair", name = "完美修复", description = "完美招架成功时回复 1 点生命", maxStacks = 1, color = { 115, 255, 175 } },
        },
    },
}

return Config
