-- Shared tuning for the Game Jam prototype. All coordinates use room space: 0..1.
local Config = {
    Title = "Parry Room",
    Debug = false,

    Room = {
        minX = 0.08,
        maxX = 0.92,
        minY = 0.14,
        maxY = 0.88,
        introDuration = 1.0,
        clearDuration = 1.1,
        doorwayWidth = 0.1,
    },

    Player = {
        maxHp = 3,
        radius = 0.035,
        speed = 0.54,
        invulnerabilityDuration = 0.62,
        parryWindow = 0.22,
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
            touchDamage = 1,
        },
        ranged = {
            hp = 1,
            radius = 0.04,
            telegraphDuration = 0.86,
            recoveryDuration = 0.95,
            touchDamage = 1,
            projectileSpeed = 0.48,
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
        },
    },

    Projectile = {
        radius = 0.016,
        lifetime = 4.0,
        reflectedSpeedMultiplier = 1.45,
        playerDamage = 1,
    },

    Drops = {
        chance = 0.45,
        pickupRadius = 0.06,
        definitions = {
            { id = "wide_guard", name = "Wide Guard", description = "Parry cone widens.", maxStacks = 2 },
            { id = "quick_hands", name = "Quick Hands", description = "Parry cooldown is shorter.", maxStacks = 3 },
            { id = "heavy_return", name = "Heavy Return", description = "Reflected shots deal extra damage.", maxStacks = 3 },
            { id = "repulse", name = "Repulse", description = "Parried melee enemies fly farther.", maxStacks = 3 },
        },
    },
}

return Config
