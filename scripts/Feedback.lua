local Config = require "Data.FeedbackConfig"

local Feedback = {}

local function HasPosition(data)
    return type(data) == "table" and type(data.x) == "number" and type(data.y) == "number"
end

local function CopyColor(color)
    return { color[1], color[2], color[3] }
end

local function AddImpact(state, profile, data)
    if not HasPosition(data) then
        return false
    end

    table.insert(state.impacts, {
        x = data.x,
        y = data.y,
        life = profile.impactDuration,
        maxLife = profile.impactDuration,
        startRadius = profile.impactStart,
        endRadius = profile.impactEnd,
        stroke = profile.impactStroke,
        color = CopyColor(profile.impactColor),
    })
    return true
end

local function AddFloatingText(state, profile, data, text)
    if text == nil or not HasPosition(data) then
        return
    end

    table.insert(state.floatingTexts, {
        x = data.x,
        y = data.y,
        text = text,
        life = Config.floatingText.duration,
        maxLife = Config.floatingText.duration,
        rise = Config.floatingText.rise,
        size = profile.textSize,
        color = CopyColor(profile.textColor),
    })
end

local function ApplyProfile(state, profile, data, text)
    if not AddImpact(state, profile, data) then
        return
    end

    state.hitStopTimer = math.max(state.hitStopTimer, profile.hitStop or 0)
    if state.shake == nil or (profile.shake or 0) >= state.shake.strength then
        state.shake = {
            timer = profile.shakeDuration or 0,
            maxTimer = profile.shakeDuration or 0,
            strength = profile.shake or 0,
        }
    end
    if state.flash == nil or (profile.flashAlpha or 0) >= state.flash.alpha then
        state.flash = {
            timer = profile.flashDuration or 0,
            maxTimer = profile.flashDuration or 0,
            alpha = profile.flashAlpha or 0,
            color = CopyColor(profile.flashColor),
        }
    end
    if profile.hudPulseDuration ~= nil then
        state.hudPulseTimer = math.max(state.hudPulseTimer, profile.hudPulseDuration)
        state.hudPulseDuration = math.max(state.hudPulseDuration, profile.hudPulseDuration)
    end
    AddFloatingText(state, profile, data, text)
end

local function FormatDamage(data)
    if type(data) ~= "table" or type(data.damage) ~= "number" then
        return nil
    end
    return string.format("%.1f", data.damage)
end

function Feedback.New()
    return {
        time = 0,
        hitStopTimer = 0,
        shake = nil,
        flash = nil,
        hudPulseTimer = 0,
        hudPulseDuration = 0,
        impacts = {},
        floatingTexts = {},
    }
end

function Feedback.ProcessEvents(state, events)
    for _, event in ipairs(events or {}) do
        local name = event.name
        local data = event.data
        if name == "parry_success" then
            ApplyProfile(state, Config.normalParry, data, FormatDamage(data))
        elseif name == "perfect_parry" then
            local damage = FormatDamage(data)
            ApplyProfile(state, Config.perfectParry, data, damage ~= nil and ("完美 " .. damage) or "完美")
        elseif name == "projectile_reflect" then
            ApplyProfile(state, Config.projectileReflect, data, "反射")
        elseif name == "projectile_hit" then
            ApplyProfile(state, Config.projectileHit, data, FormatDamage(data))
        elseif name == "player_hurt" then
            ApplyProfile(state, Config.playerHurt, data, "受击")
        elseif name == "enemy_defeat" then
            ApplyProfile(state, Config.enemyDefeat, data, nil)
        elseif name == "boss_defeat" then
            ApplyProfile(state, Config.bossDefeat, data, "处决")
        end
    end
end

function Feedback.Update(state, dt)
    dt = math.max(0, dt or 0)
    state.time = state.time + dt
    state.hitStopTimer = math.max(0, state.hitStopTimer - dt)
    state.hudPulseTimer = math.max(0, state.hudPulseTimer - dt)

    if state.shake ~= nil then
        state.shake.timer = state.shake.timer - dt
        if state.shake.timer <= 0 then
            state.shake = nil
        end
    end
    if state.flash ~= nil then
        state.flash.timer = state.flash.timer - dt
        if state.flash.timer <= 0 then
            state.flash = nil
        end
    end

    for index = #state.impacts, 1, -1 do
        local impact = state.impacts[index]
        impact.life = impact.life - dt
        if impact.life <= 0 then
            table.remove(state.impacts, index)
        end
    end
    for index = #state.floatingTexts, 1, -1 do
        local text = state.floatingTexts[index]
        text.life = text.life - dt
        if text.life <= 0 then
            table.remove(state.floatingTexts, index)
        end
    end
end

function Feedback.GetSimulationDelta(state, dt)
    if state ~= nil and state.hitStopTimer > 0 then
        return 0
    end
    return math.max(0, dt or 0)
end

function Feedback.GetScreenShake(state)
    if state == nil or state.shake == nil or state.shake.maxTimer <= 0 then
        return 0, 0
    end

    local ratio = math.max(0, state.shake.timer / state.shake.maxTimer)
    local strength = state.shake.strength * ratio * ratio
    return math.sin(state.time * 167) * strength, math.cos(state.time * 211) * strength * 0.58
end

function Feedback.GetHudPulse(state)
    if state == nil or state.hudPulseTimer <= 0 or state.hudPulseDuration <= 0 then
        return 0
    end
    return math.max(0, state.hudPulseTimer / state.hudPulseDuration)
end

return Feedback
