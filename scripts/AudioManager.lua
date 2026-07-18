local AudioManager = {}

local RESOURCE_ROOT = "audio/SFX/"
local MAX_ACTIVE_VOICES = 20

---@class AudioCueDefinition
---@field file string
---@field gain number
---@field pitchMin number
---@field pitchMax number
---@field cooldown number

---@type table<string, AudioCueDefinition>
local CUES = {
    run_start = { file = "run_start.ogg", gain = 0.52, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.08 },
    battle_start = { file = "battle_start.ogg", gain = 0.42, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.12 },
    boss_phase_changed = { file = "battle_start.ogg", gain = 0.58, pitchMin = 0.82, pitchMax = 0.86, cooldown = 0.40 },
    parry_start = { file = "parry_start.ogg", gain = 0.28, pitchMin = 1.08, pitchMax = 1.14, cooldown = 0.08 },
    parry_success = { file = "parry_success.ogg", gain = 0.66, pitchMin = 1.00, pitchMax = 1.08, cooldown = 0.04 },
    perfect_parry = { file = "perfect_parry.ogg", gain = 0.78, pitchMin = 1.02, pitchMax = 1.06, cooldown = 0.05 },
    projectile_fire = { file = "projectile_fire.ogg", gain = 0.24, pitchMin = 0.94, pitchMax = 1.08, cooldown = 0.025 },
    projectile_reflect = { file = "projectile_reflect.ogg", gain = 0.48, pitchMin = 1.04, pitchMax = 1.12, cooldown = 0.025 },
    projectile_hit = { file = "projectile_hit.ogg", gain = 0.38, pitchMin = 0.94, pitchMax = 1.08, cooldown = 0.02 },
    player_hurt = { file = "player_hurt.ogg", gain = 0.72, pitchMin = 0.96, pitchMax = 1.02, cooldown = 0.12 },
    enemy_defeat = { file = "enemy_defeat.ogg", gain = 0.40, pitchMin = 0.92, pitchMax = 1.08, cooldown = 0.025 },
    boss_defeat = { file = "boss_defeat.ogg", gain = 0.72, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.20 },
    chest_open = { file = "chest_open.ogg", gain = 0.62, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.12 },
    crystal_acquired = { file = "upgrade_select.ogg", gain = 0.58, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.10 },
    crystal_dash_start = { file = "crystal_dash_start.ogg", gain = 0.54, pitchMin = 0.98, pitchMax = 1.03, cooldown = 0.10 },
    gauge_full = { file = "gauge_full.ogg", gain = 0.58, pitchMin = 0.99, pitchMax = 1.03, cooldown = 0.12 },
    buff_gain = { file = "buff_gain.ogg", gain = 0.42, pitchMin = 0.99, pitchMax = 1.03, cooldown = 0.12 },
    buff_end = { file = "buff_end.ogg", gain = 0.26, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.10 },
    room_clear = { file = "room_clear.ogg", gain = 0.56, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.20 },
    room_transition = { file = "room_transition.ogg", gain = 0.48, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.18 },
    game_over = { file = "game_over.ogg", gain = 0.64, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.30 },
    victory = { file = "victory.ogg", gain = 0.74, pitchMin = 0.98, pitchMax = 1.02, cooldown = 0.30 },
    combo_tier_1 = { file = "parry_success.ogg", gain = 0.72, pitchMin = 1.16, pitchMax = 1.22, cooldown = 0.14 },
    combo_tier_2 = { file = "perfect_parry.ogg", gain = 0.84, pitchMin = 1.14, pitchMax = 1.21, cooldown = 0.16 },
    combo_tier_3 = { file = "gauge_full.ogg", gain = 0.92, pitchMin = 1.10, pitchMax = 1.16, cooldown = 0.22 },
    overdrive_start = { file = "battle_start.ogg", gain = 0.88, pitchMin = 1.20, pitchMax = 1.26, cooldown = 0.30 },
}

---@type Scene|nil
local audioScene = nil
---@type table<string, Sound>
local loadedSounds = {}
---@class AudioVoice
---@field node Node
---@field source SoundSource
---@type AudioVoice[]
local activeVoices = {}
---@type table<string, number>
local lastPlayedAt = {}
local elapsed = 0
local masterGain = 1.0

local function PruneVoices()
    for index = #activeVoices, 1, -1 do
        local voice = activeVoices[index]
        if voice ~= nil then
            local nodeAlive = voice.node ~= nil and voice.node:GetID() ~= 0
            local playing = nodeAlive and voice.source ~= nil and voice.source:IsPlaying()
            if not playing then
                if nodeAlive then
                    voice.node:Remove()
                end
                table.remove(activeVoices, index)
            end
        end
    end
end

function AudioManager.Initialize()
    if audioScene ~= nil then
        return true
    end

    audioScene = Scene()
    loadedSounds = {}
    activeVoices = {}
    lastPlayedAt = {}
    elapsed = 0

    local loadedCount = 0
    for name, definition in pairs(CUES) do
        local path = RESOURCE_ROOT .. definition.file
        local sound = cache:GetResource("Sound", path)
        if sound ~= nil then
            loadedSounds[name] = sound
            loadedCount = loadedCount + 1
        else
            print("WARNING: Missing sound cue " .. name .. " at " .. path)
        end
    end

    return loadedCount > 0
end

function AudioManager.SetMasterGain(gain)
    masterGain = math.max(0, math.min(1, gain or 1))
end

function AudioManager.Update(dt)
    elapsed = elapsed + math.max(0, dt or 0)
    PruneVoices()
end

function AudioManager.Play(name, options)
    if audioScene == nil then
        return false
    end

    local definition = CUES[name]
    local sound = loadedSounds[name]
    if definition == nil or sound == nil then
        return false
    end

    local bypassCooldown = options ~= nil and options.bypassCooldown == true
    if not bypassCooldown then
        local lastPlayed = lastPlayedAt[name]
        if lastPlayed ~= nil and elapsed - lastPlayed < definition.cooldown then
            return false
        end
    end
    lastPlayedAt[name] = elapsed

    PruneVoices()
    if #activeVoices >= MAX_ACTIVE_VOICES then
        local oldest = table.remove(activeVoices, 1)
        if oldest ~= nil and oldest.node ~= nil and oldest.node:GetID() ~= 0 then
            oldest.node:Remove()
        end
    end

    local pitch = options ~= nil and options.pitch
        or (definition.pitchMin + math.random() * (definition.pitchMax - definition.pitchMin))
    local gain = options ~= nil and options.gain or definition.gain
    local frequency = math.max(1, sound.frequency) * pitch
    local node = audioScene:CreateChild("SFX_" .. name)
    local source = node:CreateComponent("SoundSource")
    source:SetSoundType(SOUND_EFFECT)
    source:Play(sound, frequency, gain * masterGain, 0)
    source:SetAutoRemoveMode(REMOVE_NODE)
    table.insert(activeVoices, { node = node, source = source })
    return true
end

local function PlayPerfectStreak(streak)
    local step = math.max(0, math.min(9, (tonumber(streak) or 1) - 1))
    return AudioManager.Play("perfect_parry", {
        bypassCooldown = true,
        pitch = math.min(1.43, 1.02 + step * 0.045),
        gain = math.min(0.90, 0.76 + step * 0.014),
    })
end

function AudioManager.ProcessEvents(events)
    for _, event in ipairs(events or {}) do
        if event.name == "perfect_parry" then
            PlayPerfectStreak(event.data ~= nil and event.data.perfectStreak or 1)
        elseif event.name == "combo_tier_up" then
            local tier = event.data ~= nil and event.data.tier or 0
            AudioManager.Play("combo_tier_" .. tostring(tier))
        else
            AudioManager.Play(event.name)
        end
    end
end

function AudioManager.Shutdown()
    for _, voice in ipairs(activeVoices) do
        if voice.node ~= nil and voice.node:GetID() ~= 0 then
            voice.node:Remove()
        end
    end
    activeVoices = {}
    loadedSounds = {}
    lastPlayedAt = {}

    if audioScene ~= nil then
        audioScene:Dispose()
        audioScene = nil
    end
end

return AudioManager
