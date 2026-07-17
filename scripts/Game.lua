local Config = require "Config"
local RoomData = require "RoomData"
local Entities = require "Entities"

local Game = {}

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

local function GetAvailableUpgrades(player)
    local available = {}
    for _, definition in ipairs(Config.Upgrades.definitions) do
        if (player.abilities[definition.id] or 0) < definition.maxStacks then
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
    if enemy.kind == "boss" or math.random() > Config.Chests.chance then
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
            SpawnChestForEnemy(game, enemy)
            AddParticles(game, enemy.x, enemy.y,
                enemy.kind == "boss" and { 255, 120, 70 } or { 255, 215, 90 },
                enemy.kind == "boss" and 24 or 10
            )
            table.remove(game.enemies, index)
        end
    end
end

local function LoadRoom(game, roomIndex)
    game.roomIndex = roomIndex
    game.room = RoomData[roomIndex]
    game.enemies = {}
    game.projectiles = {}
    game.chests = {}
    game.chestOptions = nil
    game.state = "intro"
    game.stateTimer = Config.Room.introDuration
    game.message = game.room.boss and "监牢守卫正在注视" or "识别到敌对目标"
    game.messageTimer = Config.Room.introDuration

    local group = game.room.groups[math.random(1, #game.room.groups)]
    for index, kind in ipairs(group) do
        local spawn = game.room.spawns[((index - 1) % #game.room.spawns) + 1]
        table.insert(game.enemies, Entities.NewEnemy(kind, spawn, game.nextEntityId))
        game.nextEntityId = game.nextEntityId + 1
    end

    print("加载房间 " .. tostring(roomIndex) .. ": " .. game.room.name)
end

local function FinishRoom(game)
    game.state = "clear"
    local hasChests = #game.chests > 0
    game.stateTimer = hasChests and Config.Room.dropPickupDuration or Config.Room.clearDuration
    SetMessage(game,
        game.room.boss and "监牢守卫已倒下" or (hasChests and "房间已清理 - 拾取宝箱" or "房间已清理"),
        game.stateTimer
    )
    AddParticles(game, game.player.x, game.player.y, { 130, 255, 185 }, 18)
end

local function StartRun(game)
    game.player = Entities.NewPlayer()
    game.enemies = {}
    game.projectiles = {}
    game.chests = {}
    game.chestOptions = nil
    game.particles = {}
    game.roomIndex = 0
    game.nextEntityId = 1
    game.runTime = 0
    game.message = ""
    game.messageTimer = 0
    LoadRoom(game, 1)
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
    return true
end

local function UpdateChests(game, dt)
    for index = #game.chests, 1, -1 do
        local chest = game.chests[index]
        chest.bobTime = chest.bobTime + dt * 4
        if Entities.PlayerCanPickupChest(game.player, chest) then
            table.remove(game.chests, index)
            OpenChest(game, chest)
            return true
        end
    end
    return false
end

local function MoveProjectiles(game, dt)
    for _, projectile in ipairs(game.projectiles) do
        Entities.UpdateProjectile(projectile, dt)
    end
end

local function ResolveProjectileContacts(game)
    for _, projectile in ipairs(game.projectiles) do
        if Entities.ProjectileHitsPlayer(projectile, game.player) then
            projectile.dead = true
            if Entities.DamagePlayer(game.player, Config.Projectile.playerDamage) then
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, "受到伤害", 0.5)
            end
        end

        if projectile.owner == "player" and not projectile.dead then
            for _, enemy in ipairs(game.enemies) do
                if Entities.ProjectileHitsEnemy(projectile, enemy) then
                    enemy.hp = enemy.hp - projectile.damage
                    Entities.RegisterProjectileHit(projectile, enemy)
                    AddParticles(game, enemy.x, enemy.y, { 255, 230, 115 }, 9)
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                    break
                end
            end
        end
    end

    for index = #game.projectiles, 1, -1 do
        if game.projectiles[index].dead then
            table.remove(game.projectiles, index)
        end
    end
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
    end
    return true
end

local function ResolveParries(game)
    if not Entities.IsParrying(game.player) then
        return
    end

    for _, enemy in ipairs(game.enemies) do
        if Entities.TryParryEnemy(game.player, enemy) then
            AddParticles(game, enemy.x, enemy.y, { 115, 240, 255 }, 15)
            if not TryPerfectRepair(game) then
                SetMessage(game, enemy.kind == "boss" and "Boss 招架成功" or "招架成功", 0.65)
            end
        end
    end

    for _, projectile in ipairs(game.projectiles) do
        if Entities.TryParryProjectile(game.player, projectile) then
            AddParticles(game, projectile.x, projectile.y, { 115, 240, 255 }, 11)
            if not TryPerfectRepair(game) then
                SetMessage(game, "反射成功", 0.65)
            end
        end
    end
end

local function UpdateEnemies(game, dt)
    local function EmitProjectile(projectile)
        table.insert(game.projectiles, projectile)
    end

    for _, enemy in ipairs(game.enemies) do
        Entities.UpdateEnemy(enemy, game.player, dt, EmitProjectile)
        if Entities.EnemyTouchesPlayer(enemy, game.player) then
            if Entities.DamagePlayer(game.player, Config.Enemy[enemy.kind].touchDamage) then
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, "受到伤害", 0.5)
            end
        end
    end
    Entities.ResolveEnemySeparation(game.enemies)
end

local function UpdateBattle(game, dt, moveX, moveY)
    Entities.UpdatePlayer(game.player, dt, moveX, moveY)
    UpdateEnemies(game, dt)
    MoveProjectiles(game, dt)
    ResolveParries(game)
    ResolveProjectileContacts(game)
    HandleEnemyDeaths(game)
    if UpdateChests(game, dt) then
        return
    end

    if game.player.hp <= 0 then
        game.state = "dead"
        game.stateTimer = 0
        SetMessage(game, "本局失败", 999)
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
        roomIndex = 0,
        room = nil,
        player = Entities.NewPlayer(),
        enemies = {},
        projectiles = {},
        chests = {},
        chestOptions = nil,
        stateBeforeChest = nil,
        particles = {},
        message = "按回车开始",
        messageTimer = 999,
        nextEntityId = 1,
        perfectRepairConsumed = false,
        debug = Config.Debug,
    }
end

function Game.StartOrRestart(game)
    StartRun(game)
end

function Game.TryParry(game)
    if game.state ~= "battle" then
        return false
    end

    local started = Entities.BeginParry(game.player)
    if started then
        game.perfectRepairConsumed = false
        AddParticles(game, game.player.x, game.player.y, { 110, 215, 255 }, 5)
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
    game.state = game.stateBeforeChest or "battle"
    game.stateBeforeChest = nil
    return true
end

function Game.ToggleDebug(game)
    game.debug = not game.debug
    SetMessage(game, game.debug and "调试开启" or "调试关闭", 0.8)
end

function Game.Update(game, dt, moveX, moveY)
    game.time = game.time + dt
    if game.messageTimer > 0 and game.messageTimer < 900 then
        game.messageTimer = math.max(0, game.messageTimer - dt)
    end
    UpdateParticles(game, dt)

    if game.state == "menu" or game.state == "dead" or game.state == "victory" or game.state == "chest_select" then
        return
    end

    game.runTime = game.runTime + dt
    if game.state == "intro" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY)
        game.stateTimer = game.stateTimer - dt
        if game.stateTimer <= 0 then
            game.state = "battle"
            SetMessage(game, "敌人开始行动", 1.0)
        end
        return
    end

    if game.state == "battle" then
        UpdateBattle(game, dt, moveX, moveY)
        return
    end

    if game.state == "clear" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY)
        if UpdateChests(game, dt) then
            return
        end
        game.stateTimer = game.stateTimer - dt
        if #game.chests == 0 or game.stateTimer <= 0 then
            if game.roomIndex >= #RoomData then
                game.state = "victory"
                SetMessage(game, "成功逃离", 999)
            else
                LoadRoom(game, game.roomIndex + 1)
            end
        end
    end
end

function Game.GetHud(game)
    local hearts = ""
    for index = 1, Config.Player.maxHp do
        hearts = hearts .. (index <= game.player.hp and "●" or "○")
    end

    local cooldown = game.player.parryCooldown
    local cooldownText = cooldown <= 0 and "就绪" or string.format("%.2f 秒", cooldown)
    local upgradeLines = {}
    for _, definition in ipairs(Config.Upgrades.definitions) do
        local stacks = game.player.abilities[definition.id] or 0
        if stacks > 0 then
            table.insert(upgradeLines, definition.name .. " ×" .. tostring(stacks))
        end
    end

    return {
        health = "生命 " .. hearts,
        room = game.roomIndex > 0 and ("房间 " .. tostring(game.roomIndex) .. "/" .. tostring(#RoomData)) or "尚未开始",
        parry = "招架 " .. cooldownText,
        message = game.messageTimer > 0 and game.message or "",
        upgrades = #upgradeLines > 0 and table.concat(upgradeLines, "\n") or "暂无强化",
    }
end

return Game
