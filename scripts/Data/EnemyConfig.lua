-- Design-owned enemy roster. World coordinates are normalized to room width.
local ROOM_WIDTH_METERS = 30
local DEFAULT_TRACKING_RANGE_METERS = ROOM_WIDTH_METERS * math.sqrt(2)

local function MetersToWorld(meters)
    return meters / ROOM_WIDTH_METERS
end

local function Visual(primary, secondary, outline)
    return { primary = primary, secondary = secondary, outline = outline }
end

return {
    roomWidthMeters = ROOM_WIDTH_METERS,
    defaultTrackingRangeMeters = DEFAULT_TRACKING_RANGE_METERS,
    defaultTrackingRange = MetersToWorld(DEFAULT_TRACKING_RANGE_METERS),
    MetersToWorld = MetersToWorld,

    soot = {
        behavior = "melee_lunge", hp = 2, radius = 0.035,
        attackRangeMeters = 5, attackRange = MetersToWorld(5),
        moveSpeed = 0.19, touchDamage = 1,
        attack = { interval = 1.45, telegraph = 0.44, active = 0.24, recovery = 0.52, dashSpeed = 0.88, arc = 70 },
        visual = Visual({ 55, 58, 68 }, { 136, 140, 154 }, { 18, 20, 30 }),
    },
    blue_swarm = {
        behavior = "melee_lunge", hp = 2, radius = 0.04,
        attackRangeMeters = 5, attackRange = MetersToWorld(5),
        moveSpeed = 0.34, touchDamage = 1,
        attack = { interval = 0.9, telegraph = 0.24, active = 0.22, recovery = 0.34, dashSpeed = 1.1, arc = 110 },
        visual = Visual({ 82, 166, 255 }, { 169, 225, 255 }, { 22, 69, 142 }),
    },
    tree = {
        behavior = "tree_swing", hp = 3, radius = 0.055,
        attackRangeMeters = 8, attackRange = MetersToWorld(8),
        moveSpeed = 0.11, touchDamage = 1,
        attack = {
            interval = 2.4, telegraph = 0.7, active = 0.18, recovery = 0.8,
            range = MetersToWorld(4.6), narrowArc = 70, wideArc = 180,
        },
        visual = Visual({ 29, 31, 39 }, { 75, 65, 86 }, { 7, 9, 16 }),
    },
    sap = {
        behavior = "melee_lunge", hp = 3, radius = 0.043,
        attackRangeMeters = 5, attackRange = MetersToWorld(5),
        moveSpeed = 0.19, touchDamage = 1,
        attack = { interval = 1.45, telegraph = 0.46, active = 0.26, recovery = 0.55, dashSpeed = 0.76, arc = 105 },
        split = { count = 2, childHpRatio = 0.5, childRadiusRatio = 0.72, offset = 0.04 },
        visual = Visual({ 178, 237, 225 }, { 106, 194, 181 }, { 61, 124, 131 }),
    },
    ghost_a = {
        behavior = "contact_chase", hp = 2, radius = 0.04,
        moveSpeed = 0.2, touchDamage = 1, contactCooldown = 2.25, parryStagger = 0.62,
        visual = Visual({ 255, 250, 238 }, { 251, 238, 111 }, { 197, 252, 72 }),
    },
    ghost_b = {
        behavior = "contact_chase", hp = 2, radius = 0.04,
        moveSpeed = 0.2, touchDamage = 1, contactCooldown = 2.25, parryStagger = 0.62,
        visual = Visual({ 244, 250, 255 }, { 92, 219, 255 }, { 64, 162, 255 }),
    },
    luminous_wraith = {
        behavior = "contact_chase", hp = 2, radius = 0.043,
        -- Medium pursuit, low contact damage, and a slow repeat hit interval.
        moveSpeed = 0.2, touchDamage = 1, contactCooldown = 2.45, parryStagger = 0.65,
        visual = Visual({ 248, 252, 250 }, { 232, 255, 142 }, { 211, 255, 72 }),
    },
    stone = {
        behavior = "rolling", hp = 3, radius = 0.052,
        attackRangeMeters = 30, attackRange = MetersToWorld(30),
        -- A fast, immediate melee charge: contact during the roll is the only damage window.
        moveSpeed = 0.26, preferredDistance = MetersToWorld(4.5), touchDamage = 1,
        attack = { interval = 0.92, telegraph = 0, active = 0.72, recovery = 0.24, dashSpeed = 1.45, arc = 360 },
        visual = Visual({ 93, 100, 121 }, { 159, 169, 190 }, { 39, 42, 57 }),
    },
    mushroom = {
        behavior = "ranged_single", hp = 2, radius = 0.04,
        attackRangeMeters = 8, attackRange = MetersToWorld(8),
        moveSpeed = 0.1, touchDamage = 1, minimumDistance = 0.2, maximumDistance = 0.43,
        attack = { interval = 0.36, repeatInterval = 0.5, telegraph = 0.07, recovery = 0.07 },
        projectile = { count = 1, speed = 0.48, style = "spore", radius = 0.016, damage = 1 },
        visual = Visual({ 69, 47, 83 }, { 139, 99, 154 }, { 28, 18, 39 }),
    },
    dandelion = {
        behavior = "ranged_fan", hp = 2, radius = 0.047,
        attackRangeMeters = 15, attackRange = MetersToWorld(15),
        moveSpeed = 0, immovable = true, touchDamage = 1,
        attack = { interval = 2.45, telegraph = 0.76, recovery = 0.75 },
        projectile = { count = 5, spread = 78, speed = 0.42, style = "seed", radius = 0.014, damage = 1 },
        visual = Visual({ 56, 52, 73 }, { 133, 119, 158 }, { 22, 20, 35 }),
    },
    purple_orb = {
        behavior = "aoe_pulse", hp = 2, radius = 0.043,
        attackRangeMeters = 8, attackRange = MetersToWorld(8),
        moveSpeed = 0.18, preferredDistance = MetersToWorld(2.8), touchDamage = 1,
        attack = { interval = 1.0, telegraph = 0.58, active = 0.12, recovery = 0.3, range = MetersToWorld(3.7) },
        visual = Visual({ 253, 247, 255 }, { 208, 114, 255 }, { 115, 57, 160 }),
    },
    toxic_moss = {
        behavior = "ground_hazard", hp = 1, radius = 0.07,
        moveSpeed = 0, immovable = true, touchDamage = 1,
        visual = Visual({ 108, 65, 145 }, { 181, 95, 224 }, { 61, 35, 92 }),
    },

    -- Boss tuning remains isolated in BossConfig; these fields construct its base entity.
    boss = {
        hp = 4, radius = 0.075, telegraphDuration = 0.75, dashDuration = 0.42,
        recoveryDuration = 0.62, dashSpeed = 0.82, projectileSpeed = 0.55,
        touchDamage = 1, moveSpeed = 0.11, preferredDistance = 0.31,
        minimumDistance = 0.25, maximumDistance = 0.42, strafeStrength = 0.55,
    },
}
