package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Feedback = require "Feedback"

local feedback = Feedback.New()
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016)
assert(Feedback.GetHudPulse(feedback) == 0)

Feedback.ProcessEvents(feedback, {
    { name = "parry_start", data = { x = 0.4, y = 0.5, directionX = 1, directionY = 0 } },
})
assert(#feedback.bursts == 1, "starting a parry must create a player guard burst")
assert(feedback.bursts[1].kind == "parry_guard")

Feedback.ProcessEvents(feedback, {
    {
        name = "parry_success",
        data = { x = 0.4, y = 0.5, originX = 0.35, originY = 0.5, directionX = 1, directionY = 0, damage = 0.5 },
    },
})
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016, "normal parries must not pause gameplay")
assert(#feedback.impacts == 0, "normal parries must not create visible world feedback")
assert(#feedback.bursts == 1, "normal parries must not create success bursts")
assert(#feedback.floatingTexts == 0, "normal parries must not add damage text")
assert(feedback.shake == nil and feedback.flash == nil, "normal parries must stay world-local")
Feedback.Update(feedback, 1.0)
assert(#feedback.impacts == 0)

local peak = Feedback.New()
Feedback.ProcessEvents(peak, {
    { name = "perfect_parry", data = { x = 0.6, y = 0.5, damage = 0.75 } },
    { name = "projectile_reflect", data = { x = 0.6, y = 0.5 } },
    { name = "projectile_hit", data = { x = 0.6, y = 0.5, damage = 1 } },
    { name = "enemy_defeat", data = { x = 0.6, y = 0.5 } },
})
assert(Feedback.GetSimulationDelta(peak, 0.016) == 0, "perfect parries are a gameplay peak")
assert(#peak.impacts == 1, "non-critical combat events must not stack visual impacts")
assert(#peak.floatingTexts == 0, "perfect parry text must not compete with the lightning feedback")
assert(peak.perfectStreakDisplay ~= nil and peak.perfectStreakDisplay.count == 1,
    "perfect parries must create a top-screen lightning display")

local hurt = Feedback.New()
Feedback.ProcessEvents(hurt, {
    { name = "player_hurt", data = { x = 0.5, y = 0.5, amount = 1 } },
})
assert(Feedback.GetSimulationDelta(hurt, 0.016) == 0.016, "damage feedback must not freeze gameplay")
assert(#hurt.impacts == 0 and #hurt.floatingTexts == 0, "damage feedback belongs to the screen and HUD")
assert(Feedback.GetHudPulse(hurt) > 0, "damage needs to pulse the health HUD")
assert(hurt.shake ~= nil and hurt.flash ~= nil, "damage needs a restrained screen warning")

local wraithHit = Feedback.New()
Feedback.ProcessEvents(wraithHit, {
    {
        name = "luminous_wraith_hit",
        data = { x = 0.5, y = 0.5, originX = 0.57, originY = 0.5, directionX = -1, directionY = 0 },
    },
})
assert(#wraithHit.bursts == 1 and wraithHit.bursts[1].kind == "wraith_touch",
    "luminous wraith contact must create a spectral strike burst")

Feedback.Update(peak, 1.0)
assert(Feedback.GetSimulationDelta(peak, 0.016) == 0.016)
assert(#peak.impacts == 0)
assert(#peak.floatingTexts == 0)
Feedback.Update(hurt, 1.0)
assert(Feedback.GetHudPulse(hurt) == 0)

Feedback.ProcessEvents(feedback, { { name = "enemy_defeat" }, { name = "unknown" } })
assert(#feedback.impacts == 0, "feedback must ignore events without usable positions")

Feedback.ProcessEvents(feedback, {
    { name = "boss_defeat", data = { x = 0.5, y = 0.5 } },
})
assert(#feedback.impacts == 1)
assert(#feedback.floatingTexts == 1)
assert(feedback.floatingTexts[1].text == "净化")

local defense = Feedback.New()
Feedback.ProcessEvents(defense, {
    { name = "perfect_parry", data = { x = 0.5, y = 0.5, damage = 0, defenseOnly = true, perfectStreak = 3 } },
})
assert(#defense.floatingTexts == 0, "defensive parries must not display zero damage")
assert(defense.perfectStreakDisplay.count == 3, "the renderer needs the exact perfect streak count")
assert(defense.perfectStreakDisplay.focusIndex == 3, "the newest lightning must receive the entry animation")
Feedback.Update(defense, 1.0)
assert(defense.perfectStreakDisplay == nil, "lightning feedback must fade instead of becoming a permanent HUD")

local combo = Feedback.New()
Feedback.ProcessEvents(combo, {
    { name = "combo_tier_up", data = { x = 0.5, y = 0.5, tier = 2, count = 6 } },
    { name = "combo_shockwave", data = { x = 0.5, y = 0.5, tier = 2 } },
    { name = "overdrive_start", data = { x = 0.5, y = 0.5, tier = 3 } },
})
assert(#combo.shockwaves == 3, "combo events must create layered world shockwaves")
assert(Feedback.GetSimulationDelta(combo, 0.016) == 0, "tier upgrades need a brief hit stop")
Feedback.Update(combo, 1.0)
assert(#combo.shockwaves == 0, "shockwaves must clean themselves up")
Feedback.Update(feedback, 1.0)
Feedback.Update(wraithHit, 1.0)
assert(#feedback.bursts == 0 and #wraithHit.bursts == 0, "bursts must clean themselves up")

local phase = Feedback.New()
Feedback.ProcessEvents(phase, {
    { name = "boss_phase_changed", data = { x = 0.5, y = 0.5, phase = 2 } },
    { name = "boss_mechanism_completed", data = { mechanism = "fog" } },
})
assert(#phase.impacts == 1 and phase.flash ~= nil and phase.shake ~= nil)

print("PASS test_feedback")
