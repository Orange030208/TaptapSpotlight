package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Feedback = require "Feedback"

local feedback = Feedback.New()
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016)
assert(Feedback.GetHudPulse(feedback) == 0)

Feedback.ProcessEvents(feedback, {
    { name = "parry_success", data = { x = 0.4, y = 0.5, damage = 0.5 } },
})
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016, "normal parries must not pause gameplay")
assert(#feedback.impacts == 1)
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
assert(#peak.floatingTexts == 1)
assert(peak.floatingTexts[1].text == "完美 0.8")

local hurt = Feedback.New()
Feedback.ProcessEvents(hurt, {
    { name = "player_hurt", data = { x = 0.5, y = 0.5, amount = 1 } },
})
assert(Feedback.GetSimulationDelta(hurt, 0.016) == 0.016, "damage feedback must not freeze gameplay")
assert(#hurt.impacts == 0 and #hurt.floatingTexts == 0, "damage feedback belongs to the screen and HUD")
assert(Feedback.GetHudPulse(hurt) > 0, "damage needs to pulse the health HUD")
assert(hurt.shake ~= nil and hurt.flash ~= nil, "damage needs a restrained screen warning")

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
    { name = "perfect_parry", data = { x = 0.5, y = 0.5, damage = 0, defenseOnly = true } },
})
assert(defense.floatingTexts[1].text == "完美", "defensive parries must not display zero damage")

local phase = Feedback.New()
Feedback.ProcessEvents(phase, {
    { name = "boss_phase_changed", data = { x = 0.5, y = 0.5, phase = 2 } },
    { name = "boss_mechanism_completed", data = { mechanism = "fog" } },
})
assert(#phase.impacts == 1 and phase.flash ~= nil and phase.shake ~= nil)

print("PASS test_feedback")
