-- Design-owned tuning for the boss "晦暗低鸣". Room coordinates are normalized 0..1.
return {
    name = "晦暗低鸣",
    phaseThreshold = 0.30,
    phaseTransitionDuration = 1.2,
    mechanismTransitionDuration = 0.6,
    purificationDuration = 2.0,
    attackIntervalMin = 0.7,
    attackIntervalMax = 1.0,
    recoveryDuration = 0.52,
    farDistance = 0.35,
    attacks = {
        sweep = { weight = 25, telegraph = 0.72, active = 0.14, range = 0.16, arc = 180, damage = 1 },
        skewer = { weight = 20, telegraph = 0.82, active = 0.14, length = 0.32, halfWidth = 0.055, damage = 1 },
        charge = {
            weight = 12, farWeight = 40, telegraph = 0.68, active = 0.22,
            sideOffset = 0.24, dashSpeed = 1.20, hitRadius = 0.075, damage = 1,
        },
        quake = { weight = 23, telegraph = 0.88, active = 0.16, range = 0.23, arc = 270, damage = 1 },
        feathers = {
            weight = 20, telegraph = 0.76, pulseCount = 8, pulseInterval = 0.18,
            range = 0.24, arc = 180, damage = 0.25, invulnerability = 0.14,
        },
    },
    attackOrder = { "sweep", "skewer", "charge", "quake", "feathers" },
    mechanisms = {
        fog = { required = 3, lightRadius = 0.11, coreDistance = 0.105 },
        thorns = {
            required = 4, interval = 1.0, telegraph = 0.45, active = 0.15,
            reach = 0.22, halfWidth = 0.055, damage = 0.5,
            positions = {
                { x = 0.20, y = 0.28 }, { x = 0.80, y = 0.28 },
                { x = 0.20, y = 0.72 }, { x = 0.80, y = 0.72 },
            },
        },
        metal = { required = 5, backOffset = 0.085, stagger = 0.2 },
    },
}
