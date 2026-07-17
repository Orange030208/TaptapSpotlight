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
            x = x,
            y = y,
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

local function GetDropDefinition(player)
    local available = {}
    for _, definition in ipairs(Config.Drops.definitions) do
        local stacks = player.abilities[definition.id] or 0
        if stacks < definition.maxStacks then
            table.insert(available, definition)
        end
    end

    if #available == 0 then
        return nil
    end
    return available[math.random(1, #available)]
end

local function SpawnDropForEnemy(game, enemy)
    if enemy.kind == "boss" or math.random() > Config.Drops.chance then
        return
    end

    local definition = GetDropDefinition(game.player)
    if definition ~= nil then
        table.insert(game.drops, Entities.NewDrop(enemy.x, enemy.y, definition))
    end
end

local function HandleEnemyDeaths(game)
    for index = #game.enemies, 1, -1 do
        local enemy = game.enemies[index]
        if enemy.dead then
            SpawnDropForEnemy(game, enemy)
            AddParticles(game, enemy.x, enemy.y, enemy.kind == "boss" and { 255, 120, 70 } or { 255, 215, 90 }, enemy.kind == "boss" and 24 or 10)
            table.remove(game.enemies, index)
        end
    end
end

local function LoadRoom(game, roomIndex)
    game.roomIndex = roomIndex
    game.room = RoomData[roomIndex]
    game.enemies = {}
    game.projectiles = {}
    game.drops = {}
    game.state = "intro"
    game.stateTimer = Config.Room.introDuration
    game.message = game.room.boss and "THE WARDEN IS WATCHING" or "THREATS IDENTIFIED"
    game.messageTimer = Config.Room.introDuration

    local group = game.room.groups[math.random(1, #game.room.groups)]
    for index, kind in ipairs(group) do
        local spawn = game.room.spawns[((index - 1) % #game.room.spawns) + 1]
        table.insert(game.enemies, Entities.NewEnemy(kind, spawn, game.nextEntityId))
        game.nextEntityId = game.nextEntityId + 1
    end

    print("Loaded room " .. tostring(roomIndex) .. ": " .. game.room.name)
end

local function FinishRoom(game)
    game.state = "clear"
    game.stateTimer = Config.Room.clearDuration
    SetMessage(game, game.room.boss and "THE WARDEN FALLS" or "ROOM CLEARED", Config.Room.clearDuration)
    AddParticles(game, game.player.x, game.player.y, { 130, 255, 185 }, 18)
end

local function StartRun(game)
    game.player = Entities.NewPlayer()
    game.enemies = {}
    game.projectiles = {}
    game.drops = {}
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

local function UpdateDrops(game, dt)
    for index = #game.drops, 1, -1 do
        local drop = game.drops[index]
        drop.bobTime = drop.bobTime + dt * 4
        if Entities.PlayerCanPickup(game.player, drop) then
            if Entities.ApplyDrop(game.player, drop.definition) then
                SetMessage(game, drop.definition.name .. " acquired", 1.4)
                AddParticles(game, drop.x, drop.y, { 150, 230, 255 }, 14)
            else
                SetMessage(game, "Ability already maxed", 0.8)
            end
            table.remove(game.drops, index)
        end
    end
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
                SetMessage(game, "Hit", 0.5)
            end
        end

        if projectile.owner == "player" and not projectile.dead then
            for _, enemy in ipairs(game.enemies) do
                if Entities.ProjectileHitsEnemy(projectile, enemy) then
                    enemy.hp = enemy.hp - projectile.damage
                    projectile.dead = true
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

local function ResolveParries(game)
    if not Entities.IsParrying(game.player) then
        return
    end

    for _, enemy in ipairs(game.enemies) do
        if Entities.TryParryEnemy(game.player, enemy) then
            AddParticles(game, enemy.x, enemy.y, { 115, 240, 255 }, 15)
            SetMessage(game, enemy.kind == "boss" and "BOSS PARRIED" or "PARRY", 0.65)
        end
    end

    for _, projectile in ipairs(game.projectiles) do
        if Entities.TryParryProjectile(game.player, projectile) then
            AddParticles(game, projectile.x, projectile.y, { 115, 240, 255 }, 11)
            SetMessage(game, "REFLECT", 0.65)
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
                SetMessage(game, "Hit", 0.5)
            end
        end
    end
end

local function UpdateBattle(game, dt, moveX, moveY)
    Entities.UpdatePlayer(game.player, dt, moveX, moveY)
    UpdateEnemies(game, dt)
    MoveProjectiles(game, dt)
    ResolveParries(game)
    ResolveProjectileContacts(game)
    HandleEnemyDeaths(game)
    UpdateDrops(game, dt)

    if game.player.hp <= 0 then
        game.state = "dead"
        game.stateTimer = 0
        SetMessage(game, "RUN LOST", 999)
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
        drops = {},
        particles = {},
        message = "PRESS ENTER",
        messageTimer = 999,
        nextEntityId = 1,
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
        AddParticles(game, game.player.x, game.player.y, { 110, 215, 255 }, 5)
    end
    return started
end

function Game.ToggleDebug(game)
    game.debug = not game.debug
    SetMessage(game, game.debug and "DEBUG ON" or "DEBUG OFF", 0.8)
end

function Game.Update(game, dt, moveX, moveY)
    game.time = game.time + dt
    if game.messageTimer > 0 and game.messageTimer < 900 then
        game.messageTimer = math.max(0, game.messageTimer - dt)
    end
    UpdateParticles(game, dt)

    if game.state == "menu" or game.state == "dead" or game.state == "victory" then
        return
    end

    game.runTime = game.runTime + dt
    if game.state == "intro" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY)
        game.stateTimer = game.stateTimer - dt
        if game.stateTimer <= 0 then
            game.state = "battle"
            SetMessage(game, "PARRY TO SURVIVE", 1.0)
        end
        return
    end

    if game.state == "battle" then
        UpdateBattle(game, dt, moveX, moveY)
        return
    end

    if game.state == "clear" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY)
        UpdateDrops(game, dt)
        game.stateTimer = game.stateTimer - dt
        if game.stateTimer <= 0 then
            if game.roomIndex >= #RoomData then
                game.state = "victory"
                SetMessage(game, "RUN COMPLETE", 999)
            else
                LoadRoom(game, game.roomIndex + 1)
            end
        end
    end
end

function Game.GetHud(game)
    local maxHp = Config.Player.maxHp
    local hearts = ""
    for index = 1, maxHp do
        hearts = hearts .. (index <= game.player.hp and "●" or "○")
    end

    local cooldown = game.player.parryCooldown
    local cooldownText = cooldown <= 0 and "READY" or string.format("%.2fs", cooldown)
    return {
        health = hearts,
        room = game.roomIndex > 0 and ("ROOM " .. tostring(game.roomIndex) .. "/" .. tostring(#RoomData)) or "RUN NOT STARTED",
        parry = "PARRY " .. cooldownText,
        message = game.messageTimer > 0 and game.message or "",
        abilityCount = game.player.abilities.wide_guard + game.player.abilities.quick_hands
            + game.player.abilities.heavy_return + game.player.abilities.repulse,
    }
end

return Game
