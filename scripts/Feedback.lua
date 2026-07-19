local FeedbackConfig = require "Data.FeedbackConfig"

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

local function AddFloatingText(state, profile, data, text, options)
    if text == nil or not HasPosition(data) then
        return
    end

    options = options or {}

    table.insert(state.floatingTexts, {
        x = data.x,
        y = data.y,
        text = text,
        life = options.duration or FeedbackConfig.floatingText.duration,
        maxLife = options.duration or FeedbackConfig.floatingText.duration,
        rise = options.rise or FeedbackConfig.floatingText.rise,
        size = profile.textSize,
        color = CopyColor(profile.textColor),
        offsetX = options.offsetX or 0,
    })
end

local function FormatDamage(amount)
    if math.abs(amount - math.floor(amount + 0.5)) <= 0.001 then
        return tostring(math.floor(amount + 0.5))
    end
    return string.format("%.1f", amount)
end

local function AddDamagePopup(state, data)
    if not HasPosition(data) or type(data.damage) ~= "number" or data.damage <= 0 then
        return
    end
    local config = FeedbackConfig.damagePopup
    local profile = config.profiles[data.popupKind] or config.profiles.reflect
    state.damagePopupSerial = (state.damagePopupSerial or 0) + 1
    local laneIndex = (state.damagePopupSerial - 1) % #config.laneOffsets + 1
    local text = FormatDamage(data.damage)
    if data.killed then
        text = text .. " 击破"
    end
    AddFloatingText(state, profile, data, text, {
        duration = config.duration,
        rise = config.rise,
        offsetX = config.laneOffsets[laneIndex],
    })
end

local function AddShockwave(state, profile, data)
    if not HasPosition(data) or profile.shockwaveDuration == nil then
        return false
    end

    table.insert(state.shockwaves, {
        x = data.x,
        y = data.y,
        life = profile.shockwaveDuration,
        maxLife = profile.shockwaveDuration,
        startRadius = profile.shockwaveStart,
        endRadius = profile.shockwaveEnd,
        stroke = profile.shockwaveStroke,
        color = CopyColor(profile.shockwaveColor),
    })
    return true
end

local function AddBurst(state, profile, data)
    if not HasPosition(data) or profile.burstDuration == nil then
        return false
    end

    local directionX = type(data.directionX) == "number" and data.directionX or 1
    local directionY = type(data.directionY) == "number" and data.directionY or 0
    local directionLength = math.sqrt(directionX * directionX + directionY * directionY)
    if directionLength <= 0.0001 and type(data.originX) == "number" and type(data.originY) == "number" then
        directionX = data.x - data.originX
        directionY = data.y - data.originY
        directionLength = math.sqrt(directionX * directionX + directionY * directionY)
    end
    if directionLength <= 0.0001 then
        directionX, directionY = 1, 0
    else
        directionX, directionY = directionX / directionLength, directionY / directionLength
    end

    table.insert(state.bursts, {
        kind = profile.burstKind,
        x = data.x,
        y = data.y,
        originX = data.originX,
        originY = data.originY,
        directionX = directionX,
        directionY = directionY,
        life = profile.burstDuration,
        maxLife = profile.burstDuration,
        startRadius = profile.burstStart,
        endRadius = profile.burstEnd,
        stroke = profile.burstStroke,
        arcDegrees = profile.burstArcDegrees,
        color = CopyColor(profile.burstColor),
    })
    return true
end

local function ApplyScreenProfile(state, profile)
    local hitStop = profile.hitStop or 0
    if hitStop > 0 then
        state.hitStopTimer = math.max(state.hitStopTimer, hitStop)
    end

    local shake = profile.shake or 0
    if shake > 0 and profile.shakeDuration ~= nil and (state.shake == nil or shake >= state.shake.strength) then
        state.shake = {
            timer = profile.shakeDuration or 0,
            maxTimer = profile.shakeDuration or 0,
            strength = shake,
        }
    end

    local flashAlpha = profile.flashAlpha or 0
    if flashAlpha > 0 and profile.flashDuration ~= nil and (state.flash == nil or flashAlpha >= state.flash.alpha) then
        state.flash = {
            timer = profile.flashDuration or 0,
            maxTimer = profile.flashDuration or 0,
            alpha = flashAlpha,
            color = CopyColor(profile.flashColor),
        }
    end
    if profile.hudPulseDuration ~= nil then
        state.hudPulseTimer = math.max(state.hudPulseTimer, profile.hudPulseDuration)
        state.hudPulseDuration = math.max(state.hudPulseDuration, profile.hudPulseDuration)
    end
end

local function ApplyWorldProfile(state, profile, data, text)
    if not AddImpact(state, profile, data) then
        return
    end

    ApplyScreenProfile(state, profile)
    AddFloatingText(state, profile, data, text)
end

local function StartGuardStreakDisplay(state, data, kind)
    local profile = kind == "perfect" and FeedbackConfig.perfectStreak or FeedbackConfig.normalParry
    local perfectCount = type(data) == "table" and data.perfectStreak or 1
    state.guardStreakCount = (state.guardStreakCount or 0) + 1
    state.guardStreakDisplay = {
        kind = kind,
        count = kind == "perfect" and math.max(1, math.floor(perfectCount or 1)) or 1,
        comboCount = type(data) == "table" and math.max(1, math.floor(data.comboCount or data.count or 1)) or 1,
        x = type(data) == "table" and (data.originX or data.x) or 0,
        y = type(data) == "table" and (data.originY or data.y) or 0,
        comboX = type(data) == "table" and data.x or 0,
        comboY = type(data) == "table" and data.y or 0,
        life = profile.displayDuration,
        maxLife = profile.displayDuration,
        popDuration = profile.popDuration,
    }

    local strength = kind == "perfect"
        and math.min(FeedbackConfig.perfectStreak.shakeMax,
            FeedbackConfig.perfectStreak.shakeBase + (state.guardStreakCount - 1) * FeedbackConfig.perfectStreak.shakePerStack)
        or (profile.shake or 0)
    if state.shake == nil or strength >= state.shake.strength then
        state.shake = {
            timer = kind == "perfect" and FeedbackConfig.perfectStreak.shakeDuration or (profile.shakeDuration or 0),
            maxTimer = kind == "perfect" and FeedbackConfig.perfectStreak.shakeDuration or (profile.shakeDuration or 0),
            strength = strength,
        }
    end
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
        shockwaves = {},
        bursts = {},
        floatingTexts = {},
        perfectStreakDisplay = nil,
        guardStreakDisplay = nil,
        guardStreakCount = 0,
        damagePopupSerial = 0,
    }
end

function Feedback.ProcessEvents(state, events)
    for _, event in ipairs(events or {}) do
        local name = event.name
        local data = event.data
        if name == "parry_start" then
            AddBurst(state, FeedbackConfig.parryStart, data)
        elseif name == "perfect_parry" then
            ApplyWorldProfile(state, FeedbackConfig.perfectParry, data, nil)
            AddBurst(state, FeedbackConfig.perfectParry, data)
        elseif name == "parry_success" then
            ApplyWorldProfile(state, FeedbackConfig.normalParry, data, nil)
            AddBurst(state, FeedbackConfig.normalParry, data)
        elseif name == "guard_combo_feedback" then
            StartGuardStreakDisplay(state, data, data ~= nil and data.kind == "perfect" and "perfect" or "normal")
        elseif name == "damage_dealt" then
            AddDamagePopup(state, data)
        elseif name == "crystal_orbit_block" then
            AddFloatingText(state, FeedbackConfig.orbitGuard, data, "格挡")
        elseif name == "player_hurt" then
            ApplyScreenProfile(state, FeedbackConfig.playerHurt)
        elseif name == "shadow_wraith_hit" then
            AddBurst(state, FeedbackConfig.shadowWraithHit, data)
        elseif name == "boss_defeat" then
            ApplyWorldProfile(state, FeedbackConfig.bossDefeat, data, "净化")
        elseif name == "boss_attack_hit" then
            local attack = data ~= nil and data.attack or nil
            local profile = FeedbackConfig.bossAttack[attack]
            if profile ~= nil then
                ApplyWorldProfile(state, profile, data, nil)
            end
        elseif name == "boss_phase_changed" then
            ApplyWorldProfile(state, FeedbackConfig.bossPhase, data, "诅咒显形")
        elseif name == "boss_mechanism_completed" then
            ApplyScreenProfile(state, FeedbackConfig.mechanismComplete)
        elseif name == "combo_tier_up" then
            local profile = FeedbackConfig.comboTiers[data ~= nil and data.tier or 0]
            if profile ~= nil then
                ApplyScreenProfile(state, profile)
                AddShockwave(state, profile, data)
                AddFloatingText(state, profile, data, "连击 " .. tostring(data.count or ""))
            end
        elseif name == "combo_shockwave" then
            local profile = FeedbackConfig.comboTiers[data ~= nil and data.tier or 0]
                or FeedbackConfig.comboShockwave
            AddShockwave(state, profile, data)
        elseif name == "overdrive_start" then
            ApplyScreenProfile(state, FeedbackConfig.overdrive)
            AddShockwave(state, FeedbackConfig.overdrive, data)
            AddFloatingText(state, FeedbackConfig.overdrive, data, "超载")
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
    if state.guardStreakDisplay ~= nil then
        state.guardStreakDisplay.life = state.guardStreakDisplay.life - dt
        if state.guardStreakDisplay.life <= 0 then
            state.guardStreakDisplay = nil
        end
    end

    for index = #state.impacts, 1, -1 do
        local impact = state.impacts[index]
        impact.life = impact.life - dt
        if impact.life <= 0 then
            table.remove(state.impacts, index)
        end
    end
    for index = #state.shockwaves, 1, -1 do
        local shockwave = state.shockwaves[index]
        shockwave.life = shockwave.life - dt
        if shockwave.life <= 0 then
            table.remove(state.shockwaves, index)
        end
    end
    for index = #state.bursts, 1, -1 do
        local burst = state.bursts[index]
        burst.life = burst.life - dt
        if burst.life <= 0 then
            table.remove(state.bursts, index)
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

function Feedback.GetGuardStreakDisplay(state)
    return state ~= nil and state.guardStreakDisplay or nil
end

function Feedback.GetPerfectStreakDisplay(state)
    return state ~= nil and state.perfectStreakDisplay or nil
end

return Feedback
