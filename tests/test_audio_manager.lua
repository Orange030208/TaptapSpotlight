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
assert(requestedPaths["audio/SFX/parry_start.ogg"])
assert(requestedPaths["audio/SFX/victory.ogg"])
assert(requestedPaths["audio/SFX/gauge_full.ogg"])
assert(requestedPaths["audio/SFX/buff_gain.ogg"])
assert(requestedPaths["audio/SFX/buff_end.ogg"])

assert(AudioManager.Play("parry_start"))
assert(#createdSources == 1)
assert(createdSources[1].soundType == SOUND_EFFECT)
assert(createdSources[1].autoRemoveMode == REMOVE_NODE)
assert(createdSources[1].frequency > 40000)

assert(not AudioManager.Play("parry_start"), "cue cooldown should suppress immediate repeats")
AudioManager.Update(1.0)
assert(AudioManager.Play("parry_start"))

local before = #createdSources
AudioManager.ProcessEvents({ { name = "player_hurt" }, { name = "missing_cue" } })
assert(#createdSources == before + 1, "known events should play and unknown events should be ignored")

AudioManager.Shutdown()
assert(disposed)

print("PASS test_audio_manager")
