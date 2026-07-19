-- Design-owned tuning for the boss "晦暗低鸣". Room coordinates are normalized 0..1.
return {
    name = "晦暗低鸣",
    phaseThreshold = 0.50,
    phaseTransitionDuration = 1.2,
    mechanismTransitionDuration = 0.6,
    purificationDuration = 2.0,
    attackIntervalMin = 0.7,
    attackIntervalMax = 1.0,
    recoveryDuration = 0.52,
    farDistance = 0.35,
    attacks = {
        sweep = { weight = 25, telegraph = 0.61, active = 0.14, range = 0.16, arc = 180, damage = 0.75 },
        skewer = { weight = 20, telegraph = 0.70, active = 0.14, length = 0.32, halfWidth = 0.055, damage = 0.75 },
        charge = {
            weight = 12, farWeight = 40, telegraph = 0.58, active = 0.22,
            sideOffset = 0.24, dashSpeed = 1.20, hitRadius = 0.075, damage = 0.75,
        },
        quake = { weight = 23, telegraph = 0.75, active = 0.16, range = 0.23, arc = 270, damage = 0.75 },
        feathers = {
            weight = 20, takeoff = 0.36, airborne = 0.78, landingTelegraph = 0.61,
            active = 0.16, landingRadius = 0.095, damage = 0.75,
            invulnerability = 0.24,
        },
    },
    attackOrder = { "sweep", "skewer", "charge", "quake", "feathers" },
    mechanisms = {
        fog = { required = 1, lightRadius = 0.11, coreDistance = 0.105 },
        metal = { required = 1, backOffset = 0.085, stagger = 0.2 },
    },
}
