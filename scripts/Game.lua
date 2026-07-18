local ChestConfig = require "Data.ChestConfig"
local EnemyConfig = require "Data.EnemyConfig"
local GaugeConfig = require "Data.GaugeConfig"
local PlayerConfig = require "Data.PlayerConfig"
local ProjectileConfig = require "Data.ProjectileConfig"
local RoomConfig = require "Data.RoomConfig"
local RoomData = require "Data.RoomData"
local UpgradeConfig = require "Data.UpgradeConfig"
local Entities = require "Entities"
local Boss = require "Boss"

local Game = {}

local function EmitEvent(game, name, data)
    table.insert(game.events, { name = name, data = data })
end

local OPPOSITE_DIRECTION = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}

local function GetRoomCount()
    local count = 0
    for _ in pairs(RoomData.rooms) do
        count = count + 1
    end
    return count
end

local function GetRoomState(game, roomId)
    local state = game.roomStates[roomId]
    if state == nil then
        state = { visited = false, cleared = false, chests = {} }
        game.roomStates[roomId] = state
    end
    return state
end

local function CopyColor(color)
    return { color[1], color[2], color[3] }
end

local function AddParticles(game, x, y, color, count)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 0.05 + math.random() * 0.18
        table.insert(game.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.3 + math.random() * 0.35,
            maxLife = 0.65,
            color = CopyColor(color),
        })
    end
end

local function SetMessage(game, text, duration)
    game.message = text
    game.messageTimer = duration or 1.2
end

local function CreateGauge()
    return {
        value = 0,
        threshold = GaugeConfig.threshold,
        pulse = 0,
    }
end

local function GetActiveBuffMultiplier(game, field)
    local multiplier = 1
    for _, active in pairs(game.activeBuffs) do
        if active.remaining > 0 then
            multiplier = multiplier * (active.definition[field] or 1)
        end
    end
    return multiplier
end

local function UpdateTemporaryBuffs(game, dt)
    for id, active in pairs(game.activeBuffs) do
        local definition = active.definition
        if definition.healPerSecond ~= nil and game.player.hp > 0 then
            Entities.HealPlayer(game.player, definition.healPerSecond * dt)
        end

        active.remaining = active.remaining - dt
        if active.remaining <= 0 then
            game.activeBuffs[id] = nil
            SetMessage(game, definition.name .. " 已结束", 0.65)
            EmitEvent(game, "buff_end", { id = id })
        end
    end

    game.gauge.pulse = math.max(0, game.gauge.pulse - dt)
end

local function GrantRandomBuff(game, x, y)
    local definition = GaugeConfig.buffs[math.random(1, #GaugeConfig.buffs)]
    game.activeBuffs[definition.id] = {
        definition = definition,
        remaining = definition.duration,
    }
    AddParticles(game, x, y, definition.color, 18)
    EmitEvent(game, "buff_gain", { id = definition.id, duration = definition.duration })
    return definition
end

local function AddGaugeProgress(game, amount, x, y)
    local gauge = game.gauge
    gauge.value = gauge.value + amount
    local rewarded = false
    while gauge.value >= gauge.threshold do
        gauge.value = gauge.value - gauge.threshold
        gauge.pulse = 0.6
        local buff = GrantRandomBuff(game, x, y)
        SetMessage(game, GaugeConfig.label .. "充满 - 获得 " .. buff.name, 1.4)
        EmitEvent(game, "gauge_full", { buffId = buff.id })
        rewarded = true
    end
    return rewarded
end

local function GetAvailableUpgrades(player)
    local available = {}
    for _, definition in ipairs(UpgradeConfig.definitions) do
        if player.abilities[definition.id] < definition.maxStacks then
            table.insert(available, definition)
        end
    end
    return available
end

local function CreateChestOptions(player)
    local available = GetAvailableUpgrades(player)
    local options = {}
    local count = math.min(3, #available)
    for _ = 1, count do
        local index = math.random(1, #available)
        table.insert(options, table.remove(available, index))
    end
    return options
end

local function SpawnChestForEnemy(game, enemy)
    if enemy.kind == "boss" or math.random() > ChestConfig.chance then
        return
    end
    if #GetAvailableUpgrades(game.player) > 0 then
        table.insert(game.chests, Entities.NewChest(enemy.x, enemy.y))
    end
end

local function HandleEnemyDeaths(game)
    for index = #game.enemies, 1, -1 do
        local enemy = game.enemies[index]
        if enemy.dead then
            EmitEvent(game, enemy.kind == "boss" and "boss_defeat" or "enemy_defeat", {
                x = enemy.x,
                y = enemy.y,
                kind = enemy.kind,
            })
            SpawnChestForEnemy(game, enemy)
            AddParticles(game, enemy.x, enemy.y,
                enemy.kind == "boss" and { 255, 120, 70 } or { 255, 215, 90 },
                enemy.kind == "boss" and 24 or 10
            )
            table.remove(game.enemies, index)
        end
    end
end

local function PlacePlayerAtEntry(player, travelDirection)
    if travelDirection == nil then
        player.x = 0.5
        player.y = 0.72
        return
    end

    local entryDirection = OPPOSITE_DIRECTION[travelDirection]
    local inset = RoomConfig.doorEntryInset
    if entryDirection == "north" then
        player.x, player.y = 0.5, RoomConfig.minY + inset
    elseif entryDirection == "south" then
        player.x, player.y = 0.5, RoomConfig.maxY - inset
    elseif entryDirection == "west" then
        player.x, player.y = RoomConfig.minX + inset, 0.5
    else
        player.x, player.y = RoomConfig.maxX - inset, 0.5
    end
end

local function EnterRoom(game, roomId, travelDirection)
    local room = RoomData.rooms[roomId]
    assert(room ~= nil, "Unknown room id: " .. tostring(roomId))

    game.currentRoomId = roomId
    game.room = room
    game.enemies = {}
    game.projectiles = {}
    game.chestOptions = nil
    local roomState = GetRoomState(game, roomId)
    game.chests = roomState.chests
    game.roomCleared = roomState.cleared
    PlacePlayerAtEntry(game.player, travelDirection)

    if not roomState.visited then
        roomState.visited = true
        game.discoveredRooms[roomId] = true
        game.visitedRoomCount = game.visitedRoomCount + 1
    end

    local arrivalState = "clear"
    if not roomState.cleared then
        arrivalState = "intro"
        local group = room.groups[math.random(1, #room.groups)]
        for index, kind in ipairs(group) do
            local spawn = room.spawns[((index - 1) % #room.spawns) + 1]
            table.insert(game.enemies, Entities.NewEnemy(kind, spawn, game.nextEntityId))
            game.nextEntityId = game.nextEntityId + 1
        end
    end

    game.stateTimer = RoomConfig.introDuration
    game.message = room.boss and "晦暗低鸣苏醒" or (roomState.cleared and "返回已清理房间" or "识别到敌对目标")
    game.messageTimer = roomState.cleared and 0.8 or RoomConfig.introDuration
    if game.transition ~= nil then
        game.transition.arrivalState = arrivalState
        game.state = "room_transition"
    else
        game.state = arrivalState
    end

end

local function FinishRoom(game)
    local roomState = GetRoomState(game, game.currentRoomId)
    if not roomState.cleared then
        roomState.cleared = true
        game.clearedRoomCount = game.clearedRoomCount + 1
    end
    game.roomCleared = true
    local hasChests = #game.chests > 0
    game.state = game.room.boss and "victory" or "clear"
    SetMessage(game,
        game.room.boss and "诅咒已净化" or (hasChests and "房间已清理 - 拾取宝箱或进入门" or "房间已清理 - 门已开启"),
        game.room.boss and 999 or 1.8
    )
    AddParticles(game, game.player.x, game.player.y, { 130, 255, 185 }, 18)
    EmitEvent(game, game.room.boss and "victory" or "room_clear")
end

local function StartRun(game)
    game.player = Entities.NewPlayer()
    game.enemies = {}
    game.projectiles = {}
    game.chests = {}
    game.chestOptions = nil
    game.stateBeforeChest = nil
    game.particles = {}
    game.gauge = CreateGauge()
    game.activeBuffs = {}
    game.currentRoomId = nil
    game.roomStates = {}
    game.discoveredRooms = {}
    game.visitedRoomCount = 0
    game.clearedRoomCount = 0
    game.roomCleared = false
    game.transition = nil
    game.doorCooldown = 0
    game.nextEntityId = 1
    game.runTime = 0
    game.message = ""
    game.messageTimer = 0
    game.events = {}
    EnterRoom(game, RoomData.startRoomId, nil)
end

local function UpdateParticles(game, dt)
    for index = #game.particles, 1, -1 do
        local particle = game.particles[index]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + 0.04 * dt
        if particle.life <= 0 then
            table.remove(game.particles, index)
        end
    end
end

local function OpenChest(game, chest)
    local options = CreateChestOptions(game.player)
    if #options == 0 then
        SetMessage(game, "所有强化均已达到上限", 1.0)
        return false
    end

    game.stateBeforeChest = game.state
    game.state = "chest_select"
    game.chestOptions = options
    SetMessage(game, "选择一项强化", 999)
    AddParticles(game, chest.x, chest.y, { 255, 215, 100 }, 18)
    EmitEvent(game, "chest_open")
    return true
end

local function UpdateChests(game, dt)
    for index = #game.chests, 1, -1 do
        local chest = game.chests[index]
        chest.bobTime = chest.bobTime + dt * 4
        if chest.openImmediately or Entities.PlayerCanPickupChest(game.player, chest) then
            table.remove(game.chests, index)
            OpenChest(game, chest)
            return true
        end
    end
    return false
end

-- Door trigger layout in normalized room space:
--
--                 north (x centered, y = minY)
--       +--------------------[ ]--------------------+
-- west [ ]                 room                    [ ] east
--       +--------------------[ ]--------------------+
--                 south (x centered, y = maxY)
--
-- Doors are locked until the room is cleared. Arrival points are placed farther
-- inside than doorTriggerDepth so holding a movement key cannot bounce back.
local function GetTouchedDoor(player)
    local halfWidth = RoomConfig.doorwayWidth * 0.5
    local depth = RoomConfig.doorTriggerDepth
    if math.abs(player.x - 0.5) <= halfWidth then
        if player.y <= RoomConfig.minY + depth then return "north" end
        if player.y >= RoomConfig.maxY - depth then return "south" end
    end
    if math.abs(player.y - 0.5) <= halfWidth then
        if player.x <= RoomConfig.minX + depth then return "west" end
        if player.x >= RoomConfig.maxX - depth then return "east" end
    end
    return nil
end

local function TryBeginRoomTransition(game)
    if not game.roomCleared or game.doorCooldown > 0 then
        return false
    end

    local direction = GetTouchedDoor(game.player)
    local targetRoomId = direction ~= nil and game.room.connections[direction] or nil
    if targetRoomId == nil then
        return false
    end

    game.transition = {
        direction = direction,
        targetRoomId = targetRoomId,
        elapsed = 0,
        duration = RoomConfig.transitionDuration,
        switched = false,
        arrivalState = "clear",
    }
    game.state = "room_transition"
    game.projectiles = {}
    SetMessage(game, "", 0)
    EmitEvent(game, "room_transition")
    return true
end

local function UpdateRoomTransition(game, dt)
    local transition = game.transition
    if transition == nil then
        return
    end

    transition.elapsed = math.min(transition.duration, transition.elapsed + dt)
    if not transition.switched and transition.elapsed >= transition.duration * 0.5 then
        transition.switched = true
        EnterRoom(game, transition.targetRoomId, transition.direction)
    end

    if transition.elapsed >= transition.duration then
        game.state = transition.arrivalState
        game.transition = nil
        game.doorCooldown = 0.2
    end
end

local function MoveProjectiles(game, dt)
    for _, projectile in ipairs(game.projectiles) do
        Entities.UpdateProjectile(projectile, dt)
    end
end

local function RemoveDeadProjectiles(game)
    for index = #game.projectiles, 1, -1 do
        if game.projectiles[index].dead then
            table.remove(game.projectiles, index)
        end
    end
end

local function ResolveProjectileContacts(game)
    for _, projectile in ipairs(game.projectiles) do
        if Entities.ProjectileHitsPlayer(projectile, game.player) then
            projectile.dead = true
            if Entities.DamagePlayer(game.player, ProjectileConfig.playerDamage) then
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, "受到伤害", 0.5)
                EmitEvent(game, "player_hurt", {
                    x = game.player.x,
                    y = game.player.y,
                    amount = ProjectileConfig.playerDamage,
                    sourceKind = projectile.sourceKind,
                })
            end
        end

        if projectile.owner == "player" and not projectile.dead then
            for _, enemy in ipairs(game.enemies) do
                if Entities.ProjectileHitsEnemy(projectile, enemy) then
                    if enemy.kind == "boss" then
                        Entities.RegisterProjectileHit(projectile, enemy)
                        EmitEvent(game, "projectile_hit", {
                            x = enemy.x, y = enemy.y, damage = 0, sourceKind = projectile.sourceKind,
                        })
                        break
                    end
                    local appliedDamage = math.min(enemy.hp, projectile.damage)
                    enemy.hp = enemy.hp - appliedDamage
                    Entities.RegisterProjectileHit(projectile, enemy)
                    AddParticles(game, enemy.x, enemy.y, { 255, 230, 115 }, 9)
                    EmitEvent(game, "projectile_hit", {
                        x = enemy.x,
                        y = enemy.y,
                        damage = appliedDamage,
                        sourceKind = projectile.sourceKind,
                    })
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                    break
                end
            end
        end
    end

    RemoveDeadProjectiles(game)
end

local function TryPerfectRepair(game)
    if game.perfectRepairConsumed or game.player.abilities.perfect_repair <= 0 then
        return false
    end
    if not Entities.IsPerfectParry(game.player) then
        return false
    end

    game.perfectRepairConsumed = true
    if Entities.HealPlayer(game.player, 1) then
        SetMessage(game, "完美招架 - 生命恢复", 0.8)
        return true
    end
    return false
end

local function GetParryDamage(game, perfect)
    local damage = GaugeConfig.normalDamage
    if perfect then
        damage = damage * GaugeConfig.perfectDamageMultiplier
    end
    return damage * GetActiveBuffMultiplier(game, "parryDamageMultiplier")
end

local function GetGaugeGain(game, perfect)
    local gain = perfect and GaugeConfig.perfectGain or GaugeConfig.normalGain
    return gain * GetActiveBuffMultiplier(game, "gaugeGainMultiplier")
end

local function FormatParryMessage(perfect, damage)
    local prefix = perfect and "完美招架" or "招架成功"
    return prefix .. " - " .. string.format("%.2f", damage) .. " 伤害"
end

local function ResolveParries(game)
    if not Entities.IsParrying(game.player) then
        return
    end

    local perfect = Entities.IsPerfectParry(game.player)
    local damage = GetParryDamage(game, perfect)
    local gain = GetGaugeGain(game, perfect)

    for _, enemy in ipairs(game.enemies) do
        local hitX, hitY = enemy.x, enemy.y
        if enemy.kind == "boss" then
            local result = Boss.TryParry(enemy, game.player, damage)
            if result ~= nil then
                local eventData = {
                    x = result.x or hitX, y = result.y or hitY, damage = result.damage,
                    sourceKind = enemy.kind, defenseOnly = result.damage <= 0,
                }
                EmitEvent(game, perfect and "perfect_parry" or "parry_success", eventData)
                AddParticles(game, hitX, hitY,
                    result.kind == "mechanism" and { 245, 205, 105 } or { 115, 240, 255 }, 15)
                local repaired = TryPerfectRepair(game)
                if result.kind == "mechanism" then
                    EmitEvent(game, "projectile_reflect", eventData)
                    EmitEvent(game, "boss_mechanism_progress", {
                        x = result.x or hitX, y = result.y or hitY,
                        mechanism = result.mechanism, progress = result.progress,
                    })
                    if result.completed then
                        EmitEvent(game, "boss_mechanism_completed", { mechanism = result.mechanism })
                        EmitEvent(game, "gauge_full")
                    end
                    SetMessage(game, result.completed and "净化目标完成" or "净化进度推进", 0.7)
                elseif enemy.phaseChanged then
                    game.projectiles = {}
                    EmitEvent(game, "boss_phase_changed", { phase = 2, x = enemy.x, y = enemy.y })
                    SetMessage(game, "第二阶段 - 诅咒显形", 1.2)
                elseif not repaired then
                    SetMessage(game,
                        result.damage > 0 and FormatParryMessage(perfect, result.damage) or "防御成功 - Boss 无效",
                        0.65)
                end
            end
        else
            local parried, appliedDamage = Entities.TryParryEnemy(game.player, enemy, damage)
            if parried then
                EmitEvent(game, perfect and "perfect_parry" or "parry_success", {
                    x = hitX, y = hitY, damage = appliedDamage, sourceKind = enemy.kind,
                })
                AddParticles(game, hitX, hitY, { 115, 240, 255 }, 15)
                local repaired = TryPerfectRepair(game)
                local rewarded = AddGaugeProgress(game, gain, hitX, hitY)
                if not rewarded and not repaired then
                    SetMessage(game, FormatParryMessage(perfect, appliedDamage), 0.65)
                end
            end
        end
    end

    for _, projectile in ipairs(game.projectiles) do
        local hitX, hitY = projectile.x, projectile.y
        if Entities.TryParryProjectile(game.player, projectile, GetActiveBuffMultiplier(game, "parryDamageMultiplier")) then
            local eventData = {
                x = hitX,
                y = hitY,
                damage = projectile.damage,
                sourceKind = projectile.sourceKind,
            }
            EmitEvent(game, perfect and "perfect_parry" or "parry_success", eventData)
            EmitEvent(game, "projectile_reflect", eventData)
            AddParticles(game, hitX, hitY, { 115, 240, 255 }, 11)
            local repaired = TryPerfectRepair(game)
            local rewarded = AddGaugeProgress(game, gain, hitX, hitY)
            if not rewarded and not repaired then
                SetMessage(game, "反射成功", 0.65)
            end
        end
    end
end

local function UpdateEnemies(game, dt)
    local function EmitProjectile(projectile)
        table.insert(game.projectiles, projectile)
        EmitEvent(game, "projectile_fire")
    end

    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            Boss.Update(enemy, game.player, dt)
        else
            Entities.UpdateEnemy(enemy, game.player, dt, EmitProjectile)
        end
    end
    Entities.ResolveEnemySeparation(game.enemies)
end

local function ResolveEnemyContacts(game)
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            for _, hit in ipairs(Boss.CollectPlayerHits(enemy, game.player)) do
                if Entities.DamagePlayer(game.player, hit.amount, hit.invulnerability) then
                    AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                    SetMessage(game, hit.source == "thorns" and "遭到荆棘鞭打" or "受到伤害", 0.5)
                    EmitEvent(game, "player_hurt", {
                        x = game.player.x, y = game.player.y, amount = hit.amount, sourceKind = hit.source,
                    })
                end
            end
        elseif Entities.EnemyTouchesPlayer(enemy, game.player) then
            if Entities.DamagePlayer(game.player, EnemyConfig[enemy.kind].touchDamage) then
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, "受到伤害", 0.5)
                EmitEvent(game, "player_hurt", {
                    x = game.player.x,
                    y = game.player.y,
                    amount = EnemyConfig[enemy.kind].touchDamage,
                    sourceKind = enemy.kind,
                })
            end
        end
    end
end

local function UpdateBattle(game, dt, moveX, moveY)
    Entities.UpdatePlayer(game.player, dt, moveX, moveY, GetActiveBuffMultiplier(game, "moveSpeedMultiplier"))
    UpdateEnemies(game, dt)
    MoveProjectiles(game, dt)
    ResolveParries(game)
    ResolveEnemyContacts(game)
    ResolveProjectileContacts(game)
    HandleEnemyDeaths(game)
    if UpdateChests(game, dt) then
        return
    end

    if game.player.hp <= 0 then
        game.state = "dead"
        game.stateTimer = 0
        SetMessage(game, "本局失败", 999)
        EmitEvent(game, "game_over")
        return
    end

    if #game.enemies == 0 then
        FinishRoom(game)
    end
end

function Game.New()
    return {
        state = "menu",
        stateTimer = 0,
        time = 0,
        runTime = 0,
        currentRoomId = nil,
        room = nil,
        roomStates = {},
        discoveredRooms = {},
        visitedRoomCount = 0,
        clearedRoomCount = 0,
        roomCount = GetRoomCount(),
        roomCleared = false,
        map = RoomData,
        transition = nil,
        doorCooldown = 0,
        player = Entities.NewPlayer(),
        enemies = {},
        projectiles = {},
        chests = {},
        chestOptions = nil,
        stateBeforeChest = nil,
        particles = {},
        gauge = CreateGauge(),
        activeBuffs = {},
        message = "按回车开始",
        messageTimer = 999,
        nextEntityId = 1,
        perfectRepairConsumed = false,
        events = {},
    }
end

function Game.StartOrRestart(game)
    StartRun(game)
    EmitEvent(game, "run_start")
end

function Game.TryParry(game)
    if game.state ~= "battle" then
        return false
    end

    local started = Entities.BeginParry(game.player)
    if started then
        game.perfectRepairConsumed = false
        AddParticles(game, game.player.x, game.player.y, { 110, 215, 255 }, 5)
        EmitEvent(game, "parry_start", { x = game.player.x, y = game.player.y })
    end
    return started
end

function Game.SelectUpgrade(game, index)
    if game.state ~= "chest_select" or game.chestOptions == nil then
        return false
    end

    local definition = game.chestOptions[index]
    if definition == nil or not Entities.ApplyUpgrade(game.player, definition) then
        return false
    end

    AddParticles(game, game.player.x, game.player.y, definition.color, 18)
    SetMessage(game, "获得强化：" .. definition.name, 1.4)
    game.chestOptions = nil
    game.state = game.stateBeforeChest
    game.stateBeforeChest = nil
    EmitEvent(game, "upgrade_select")
    return true
end

function Game.ConsumeEvents(game)
    local events = game.events
    game.events = {}
    return events
end

function Game.Update(game, dt, moveX, moveY, realDt)
    dt = math.max(0, dt or 0)
    realDt = math.max(0, realDt or dt)
    game.time = game.time + dt
    if game.messageTimer > 0 and game.messageTimer < 900 then
        game.messageTimer = math.max(0, game.messageTimer - dt)
    end
    UpdateParticles(game, dt)

    if game.state == "room_transition" or game.state == "intro" or game.state == "battle" or game.state == "clear" then
        UpdateTemporaryBuffs(game, dt)
    end

    if game.doorCooldown > 0 then
        game.doorCooldown = math.max(0, game.doorCooldown - dt)
    end

    -- A feedback hit stop freezes world simulation, but parry, cooldown, and
    -- invulnerability timers keep using real time so combat windows do not grow.
    if dt <= 0 and realDt > 0 then
        if game.player ~= nil then
            Entities.UpdatePlayerTimers(game.player, realDt)
        end
        return
    end

    if game.state == "room_transition" then
        UpdateRoomTransition(game, dt)
        return
    end

    if game.state == "victory" then
        -- Victory freezes combat, but reflected piercing projectiles should finish their flight.
        MoveProjectiles(game, dt)
        RemoveDeadProjectiles(game)
        return
    end

    if game.state == "menu" or game.state == "dead" or game.state == "chest_select" then
        return
    end

    game.runTime = game.runTime + dt
    if game.state == "intro" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY, GetActiveBuffMultiplier(game, "moveSpeedMultiplier"))
        game.stateTimer = game.stateTimer - dt
        if game.stateTimer <= 0 then
            game.state = "battle"
            SetMessage(game, "敌人开始行动", 1.0)
            EmitEvent(game, "battle_start")
        end
        return
    end

    if game.state == "battle" then
        UpdateBattle(game, dt, moveX, moveY)
        return
    end

    if game.state == "clear" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY, GetActiveBuffMultiplier(game, "moveSpeedMultiplier"))
        -- A room can be cleared by a piercing projectile; keep it moving until it expires.
        MoveProjectiles(game, dt)
        RemoveDeadProjectiles(game)
        if UpdateChests(game, dt) then
            return
        end
        TryBeginRoomTransition(game)
    end
end

function Game.GetHud(game)
    local cooldown = game.player.parryCooldown
    local cooldownText = cooldown <= 0 and "就绪" or "恢复中"
    local upgradeLines = {}
    for _, definition in ipairs(UpgradeConfig.definitions) do
        local stacks = game.player.abilities[definition.id]
        if stacks > 0 then
            table.insert(upgradeLines, definition.name .. " ×" .. tostring(stacks))
        end
    end

    local buffLines = {}
    for _, definition in ipairs(GaugeConfig.buffs) do
        local active = game.activeBuffs[definition.id]
        if active ~= nil and active.remaining > 0 then
            table.insert(buffLines, definition.name .. " · " .. tostring(math.ceil(active.remaining)) .. "秒")
        end
    end

    local bossHud = nil
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            bossHud = Boss.GetHud(enemy)
            break
        end
    end

    local healthRatio = math.max(0, math.min(1, game.player.hp / PlayerConfig.maxHp))
    local gaugeRatio = math.max(0, math.min(1, game.gauge.value / game.gauge.threshold))
    local hudVisible = game.state ~= "menu" and game.state ~= "dead" and game.state ~= "victory"

    return {
        hudVisible = hudVisible,
        healthRatio = healthRatio,
        gaugeRatio = gaugeRatio,
        room = game.room ~= nil and game.room.name or "尚未开始",
        roomProgress = "探索 " .. tostring(game.clearedRoomCount) .. "/" .. tostring(game.roomCount),
        parry = "招架 " .. cooldownText,
        parryReady = cooldown <= 0,
        message = game.messageTimer > 0 and game.message or "",
        upgrades = #upgradeLines > 0 and table.concat(upgradeLines, "\n") or "暂无强化",
        buffs = #buffLines > 0 and table.concat(buffLines, "\n") or "暂无临时增益",
        boss = bossHud,
    }
end

return Game
