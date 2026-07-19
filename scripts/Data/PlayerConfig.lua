local PLAYER_SIZE_MULTIPLIER = 2.25

return {
    sizeMultiplier = PLAYER_SIZE_MULTIPLIER,
    maxHp = 3,
    radius = 0.035 * PLAYER_SIZE_MULTIPLIER,
    speed = 0.54,
    invulnerabilityDuration = 0.62,
    parryWindow = 0.22,
    perfectParryWindow = 0.10,
    parryCooldown = 3.0,
    normalParryCooldownRefund = 0.80,
    perfectParryCooldownRefund = 1.00,
    parryInputBuffer = 0.08,
    parryRange = 0.19,
    parryHalfAngleCos = math.cos(math.rad(60)), -- 120 degree cone
    meleeKnockback = 0.1125,
    meleeKnockbackDuration = 0.24,
}
