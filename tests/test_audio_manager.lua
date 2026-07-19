package.path = "./scripts/?.lua;" .. package.path

SOUND_EFFECT = "Effect"
REMOVE_NODE = 2

local requestedPaths = {}
local createdSources = {}
local disposed = false
local nextNodeId = 1

cache = {
    GetResource = function(_, resourceType, path)
        assert(resourceType == "Sound")
        requestedPaths[path] = true
        local file = assert(io.open("assets/" .. path, "rb"), "missing test sound: " .. path)
        file:close()
        return { frequency = 44100, path = path }
    end,
}

local function NewSource()
    local source = { playing = false }
    function source:SetSoundType(soundType)
        self.soundType = soundType
    end
    function source:Play(sound, frequency, gain, panning)
        self.sound = sound
        self.frequency = frequency
        self.gain = gain
        self.panning = panning
        self.playing = true
    end
    function source:SetAutoRemoveMode(mode)
        self.autoRemoveMode = mode
    end
    function source:IsPlaying()
        return self.playing
    end
    function source:StopImmediate()
        self.playing = false
    end
    return source
end

local function NewNode()
    local node = { id = nextNodeId, removed = false }
    nextNodeId = nextNodeId + 1
    function node:CreateComponent(componentType)
        assert(componentType == "SoundSource")
        local source = NewSource()
        table.insert(createdSources, source)
        return source
    end
    function node:GetID()
        return self.removed and 0 or self.id
    end
    function node:Remove()
        self.removed = true
    end
    return node
end

Scene = function()
    local scene = {}
    function scene:CreateChild()
        return NewNode()
    end
    function scene:Dispose()
        disposed = true
    end
    return scene
end

local AudioManager = require "AudioManager"

assert(AudioManager.Initialize())
local expectedCues = {
    "run_start", "battle_start", "parry_start", "parry_success", "perfect_parry",
    "projectile_fire", "projectile_reflect", "projectile_hit", "player_hurt",
    "enemy_defeat", "boss_defeat", "chest_open", "crystal_acquired", "gauge_full",
    "room_clear", "room_transition", "game_over", "victory",
}
for _, name in ipairs(expectedCues) do
    local file = name == "crystal_acquired" and "upgrade_select.ogg" or name .. ".ogg"
    assert(requestedPaths["audio/SFX/" .. file], "missing cue mapping: " .. name)
end

assert(AudioManager.Play("parry_start"))
assert(#createdSources == 1)
assert(createdSources[1].soundType == SOUND_EFFECT)
assert(createdSources[1].autoRemoveMode == REMOVE_NODE)
assert(createdSources[1].frequency > 40000)

assert(not AudioManager.Play("parry_start"), "cue cooldown should suppress immediate repeats")
AudioManager.Update(1.0)
assert(AudioManager.Play("parry_start"))
assert(AudioManager.Play("boss_phase_changed"), "boss phase change should reuse the battle cue")

local before = #createdSources
AudioManager.ProcessEvents({ { name = "player_hurt" }, { name = "missing_cue" } })
assert(#createdSources == before + 1, "known events should play and unknown events should be ignored")

before = #createdSources
AudioManager.ProcessEvents({
    { name = "combo_tier_up", data = { tier = 3 } },
    { name = "overdrive_start", data = { tier = 3 } },
})
assert(#createdSources == before + 2, "combo stages must reuse their mapped sound cues")

before = #createdSources
AudioManager.ProcessEvents({
    { name = "perfect_parry", data = { perfectStreak = 1 } },
    { name = "perfect_parry", data = { perfectStreak = 2 } },
    { name = "perfect_parry", data = { perfectStreak = 3 } },
})
assert(#createdSources == before + 3, "each perfect parry in a streak must receive its own rising cue")
assert(createdSources[before + 1].frequency < createdSources[before + 2].frequency)
assert(createdSources[before + 2].frequency < createdSources[before + 3].frequency)
assert(createdSources[before + 3].frequency <= 44100 * 1.43, "perfect streak pitch must remain capped")
assert(createdSources[before + 1].gain < createdSources[before + 3].gain,
    "perfect streak feedback must become stronger as the chain grows")

AudioManager.Shutdown()
assert(disposed)

print("PASS test_audio_manager")
