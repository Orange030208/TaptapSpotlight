package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Feedback = require "Feedback"

local feedback = Feedback.New()
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016)
assert(Feedback.GetHudPulse(feedback) == 0)

Feedback.ProcessEvents(feedback, {
    { name = "parry_success", data = { x = 0.4, y = 0.5, damage = 0.5 } },
})
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0, "normal parries need a short hit stop")
assert(#feedback.impacts == 1)
assert(#feedback.floatingTexts == 1)
assert(feedback.floatingTexts[1].text == "0.5")

Feedback.ProcessEvents(feedback, {
    { name = "perfect_parry", data = { x = 0.6, y = 0.5, damage = 0.75 } },
    { name = "projectile_reflect", data = { x = 0.6, y = 0.5 } },
    { name = "player_hurt", data = { x = 0.5, y = 0.5, amount = 1 } },
})
assert(#feedback.impacts == 4, "each combat result needs a visible impact")
assert(Feedback.GetHudPulse(feedback) > 0, "damage needs to pulse the health HUD")

Feedback.Update(feedback, 1.0)
assert(Feedback.GetSimulationDelta(feedback, 0.016) == 0.016)
assert(#feedback.impacts == 0)
assert(#feedback.floatingTexts == 0)
assert(Feedback.GetHudPulse(feedback) == 0)

Feedback.ProcessEvents(feedback, { { name = "enemy_defeat" }, { name = "unknown" } })
assert(#feedback.impacts == 0, "feedback must ignore events without usable positions")

print("PASS test_feedback")
