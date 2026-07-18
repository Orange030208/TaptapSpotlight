local ChestConfig = require "Data.ChestConfig"
local EnemyConfig = require "Data.EnemyConfig"
local PlayerConfig = require "Data.PlayerConfig"
local ProjectileConfig = require "Data.ProjectileConfig"
local RoomConfig = require "Data.RoomConfig"
local UpgradeConfig = require "Data.UpgradeConfig"
local Boss = require "Boss"

local Entities = {}

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Length(x, y)
    return math.sqrt(x * x + y * y)
end

local function Normalize(x, y)
    local length = Length(x, y)
    if length <= 0.0001 then
        return 0, 0
    end
    return x / length, y / length
end

local function DistanceSquared(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

local function IsInsideParryCone(player, target)
    local dx = target.x - player.x
    local dy = target.y - player.y
    local distance = Length(dx, dy)
    if distance <= 0.0001 then
        return true
    end

    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    directionX, directionY = Normalize(directionX, directionY)
    return (dx / distance) * directionX + (dy / distance) * directionY >= player.parryHalfAngleCos
end

local function IsInRange(player, target, range)
    return DistanceSquared(player, target) <= range * range
end

local function MoveEnemy(enemy, moveX, moveY, speed, dt)
    local directionX, directionY = Normalize(moveX, moveY)
    enemy.vx = directionX * speed
    enemy.vy = directionY * speed
    enemy.x = Clamp(enemy.x + enemy.vx * dt, RoomConfig.minX, RoomConfig.maxX)
    enemy.y = Clamp(enemy.y + enemy.vy * dt, RoomConfig.minY, RoomConfig.maxY)
    if math.abs(directionX) > 0.02 then
        enemy.facing = directionX < 0 and "left" or "right"
    end
end

function Entities.NewPlayer()
    local abilities = {}
    for _, definition in ipairs(UpgradeConfig.definitions) do
        abilities[definition.id] = 0
    end

    return {
        x = 0.5,
        y = 0.72,
        hp = PlayerConfig.maxHp,
        radius = PlayerConfig.radius,
        facing = "right",
        parryTimer = 0,
        parryElapsed = 0,
        parryCooldown = 0,
        parrySerial = 0,
        parryDirectionX = 1,
        parryDirectionY = 0,
        parryBuffered = false,
        bufferedParryDirectionX = 1,
        bufferedParryDirectionY = 0,
        invulnerabilityTimer = 0,
        parryHalfAngleCos = PlayerConfig.parryHalfAngleCos,
        abilities = abilities,
    }
end

function Entities.NewEnemy(kind, spawn, id)
    local spec = EnemyConfig[kind]
    local enemy = {
        id = id,
        kind = kind,
        x = spawn.x,
        y = spawn.y,
        radius = spec.radius,
        hp = spec.hp,
        maxHp = spec.hp,
        state = "idle",
        stateTimer = 0.55 + math.random() * 0.45,
        vx = 0,
        vy = 0,
        facing = "right",
        dashX = 0,
        dashY = 0,
        attackMode = "dash",
        strafeDirection = math.random() < 0.5 and -1 or 1,
        strafeTimer = 0.55 + math.random() * 0.75,
        dead = false,
    }
    if kind == "boss" then
        return Boss.Initialize(enemy)
    end
    return enemy
end

function Entities.NewProjectile(x, y, vx, vy, owner, damage, sourceKind)
    return {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        owner = owner,
        sourceKind = sourceKind,
        damage = damage,
        radius = ProjectileConfig.radius,
        lifetime = ProjectileConfig.lifetime,
        reflected = false,
        pierceRemaining = 0,
        chainsRemaining = 0,
        turnFromX = 0,
        turnFromY = 0,
        turnTimer = 0,
        turnDuration = 0,
        hitEnemies = {},
        dead = false,
    }
end

function Entities.NewChest(x, y)
    return {
        x = x,
        y = y,
        radius = 0.026,
        bobTime = math.random() * math.pi * 2,
        openImmediately = true,
        dead = false,
    }
end

function Entities.UpdatePlayer(player, dt, moveX, moveY, speedMultiplier)
    local directionX, directionY = 0, 0
    if not Entities.IsParrying(player) then
        directionX, directionY = Normalize(moveX, moveY)
    end
    local speed = PlayerConfig.speed * speedMultiplier
    player.x = Clamp(player.x + directionX * speed * dt, RoomConfig.minX, RoomConfig.maxX)
    player.y = Clamp(player.y + directionY * speed * dt, RoomConfig.minY, RoomConfig.maxY)

    if math.abs(directionX) > 0.05 then
        player.facing = directionX < 0 and "left" or "right"
    end

    return Entities.UpdatePlayerTimers(player, dt)
end

function Entities.UpdatePlayerTimers(player, dt)
    if player.parryTimer > 0 then
        player.parryElapsed = player.parryElapsed + dt
    end
    player.parryTimer = math.max(0, player.parryTimer - dt)
    player.parryCooldown = math.max(0, player.parryCooldown - dt)
    player.invulnerabilityTimer = math.max(0, player.invulnerabilityTimer - dt)
    if player.parryBuffered and player.parryCooldown <= 0 then
        player.parryDirectionX = player.bufferedParryDirectionX
        player.parryDirectionY = player.bufferedParryDirectionY
        if math.abs(player.parryDirectionX) > 0.05 then
            player.facing = player.parryDirectionX < 0 and "left" or "right"
        end
        player.parryBuffered = false
        player.parryTimer = PlayerConfig.parryWindow
        player.parryElapsed = 0
        player.parrySerial = (player.parrySerial or 0) + 1
        player.parryCooldown = PlayerConfig.parryCooldown - player.abilities.quick_hands * 0.06
        player.parryCooldown = math.max(0.2, player.parryCooldown)
        return true
    end
    return false
end

local function GetRequestedParryDirection(player, targetX, targetY)
    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    if targetX ~= nil and targetY ~= nil then
        local requestedX, requestedY = Normalize(targetX - player.x, targetY - player.y)
        if requestedX ~= 0 or requestedY ~= 0 then
            directionX, directionY = requestedX, requestedY
        end
    end
    return Normalize(directionX, directionY)
end

local function ApplyParryDirection(player, directionX, directionY)
    player.parryDirectionX = directionX
    player.parryDirectionY = directionY
    if math.abs(directionX) > 0.05 then
        player.facing = directionX < 0 and "left" or "right"
    end
end

function Entities.BeginParry(player, targetX, targetY)
    if player.parryCooldown > PlayerConfig.parryInputBuffer then
        return false, false
    end

    local directionX, directionY = GetRequestedParryDirection(player, targetX, targetY)
    if player.parryCooldown > 0 then
        player.parryBuffered = true
        player.bufferedParryDirectionX = directionX
        player.bufferedParryDirectionY = directionY
        return true, false
    end

    ApplyParryDirection(player, directionX, directionY)
    player.parryBuffered = false

    player.parryTimer = PlayerConfig.parryWindow
    player.parryElapsed = 0
    player.parrySerial = (player.parrySerial or 0) + 1
    player.parryCooldown = PlayerConfig.parryCooldown - player.abilities.quick_hands * 0.06
    player.parryCooldown = math.max(0.2, player.parryCooldown)
    return true, true
end

function Entities.RegisterParrySuccess(player)
    player.parryCooldown = math.min(player.parryCooldown, PlayerConfig.successfulParryCooldown)
end

function Entities.IsParrying(player)
    return player.parryTimer > 0
end

function Entities.IsPerfectParry(player)
    return player.parryTimer > 0 and player.parryElapsed <= PlayerConfig.perfectParryWindow
end

function Entities.DamagePlayer(player, amount, invulnerabilityDuration)
    if player.invulnerabilityTimer > 0 then
        return false
    end

    player.hp = math.max(0, player.hp - amount)
    player.invulnerabilityTimer = invulnerabilityDuration or PlayerConfig.invulnerabilityDuration
    return true
end

function Entities.HealPlayer(player, amount)
    local previousHp = player.hp
    player.hp = math.min(PlayerConfig.maxHp, player.hp + amount)
    return player.hp > previousHp
end

function Entities.UpdateTacticalMovement(enemy, player, dt)
    local spec = EnemyConfig[enemy.kind]
    local toPlayerX, toPlayerY = Normalize(player.x - enemy.x, player.y - enemy.y)
    local distance = Length(player.x - enemy.x, player.y - enemy.y)
    enemy.strafeTimer = enemy.strafeTimer - dt
    if enemy.strafeTimer <= 0 then
        enemy.strafeDirection = -enemy.strafeDirection
        enemy.strafeTimer = 0.55 + math.random() * 0.75
    end

    local sideX = -toPlayerY * enemy.strafeDirection
    local sideY = toPlayerX * enemy.strafeDirection
    local radial = 0
    if enemy.kind == "melee" then
        if distance > spec.preferredDistance then
            radial = 1
        elseif distance < spec.preferredDistance * 0.72 then
            radial = -0.4
        end
    else
        if distance < spec.minimumDistance then
            radial = -1
        elseif distance > spec.maximumDistance then
            radial = 1
        end
    end

    MoveEnemy(enemy,
        toPlayerX * radial + sideX * spec.strafeStrength,
        toPlayerY * radial + sideY * spec.strafeStrength,
        spec.moveSpeed,
        dt
    )
end

function Entities.UpdateEnemy(enemy, player, dt, emitProjectile)
    if enemy.dead then
        return
    end

    local spec = EnemyConfig[enemy.kind]
    enemy.stateTimer = enemy.stateTimer - dt

    if enemy.state == "idle" then
        Entities.UpdateTacticalMovement(enemy, player, dt)
        if enemy.stateTimer <= 0 then
            enemy.state = "telegraph"
            enemy.stateTimer = spec.telegraphDuration
            if enemy.kind == "boss" then
                enemy.attackMode = enemy.attackMode == "dash" and "volley" or "dash"
            end
        end
        return
    end

    if enemy.state == "telegraph" and enemy.stateTimer <= 0 then
        if enemy.kind == "ranged" or (enemy.kind == "boss" and enemy.attackMode == "volley") then
            local dx, dy = Normalize(player.x - enemy.x, player.y - enemy.y)
            emitProjectile(Entities.NewProjectile(enemy.x, enemy.y, dx * spec.projectileSpeed, dy * spec.projectileSpeed, "enemy", 1, enemy.kind))
            if enemy.kind == "boss" then
                emitProjectile(Entities.NewProjectile(enemy.x, enemy.y, (dx - dy * 0.35) * spec.projectileSpeed, (dy + dx * 0.35) * spec.projectileSpeed, "enemy", 1, enemy.kind))
                emitProjectile(Entities.NewProjectile(enemy.x, enemy.y, (dx + dy * 0.35) * spec.projectileSpeed, (dy - dx * 0.35) * spec.projectileSpeed, "enemy", 1, enemy.kind))
            end
            enemy.state = "recovery"
            enemy.stateTimer = spec.recoveryDuration
        else
            enemy.dashX, enemy.dashY = Normalize(player.x - enemy.x, player.y - enemy.y)
            enemy.state = "dash"
            enemy.stateTimer = spec.dashDuration
        end
        return
    end

    if enemy.state == "dash" then
        MoveEnemy(enemy, enemy.dashX, enemy.dashY, spec.dashSpeed, dt)
        if enemy.stateTimer <= 0 then
            enemy.state = "recovery"
            enemy.stateTimer = spec.recoveryDuration
        end
        return
    end

    if enemy.state == "recovery" and enemy.stateTimer <= 0 then
        enemy.state = "idle"
        enemy.stateTimer = 0.45 + math.random() * 0.55
    end
end

function Entities.ResolveEnemySeparation(enemies)
    for firstIndex = 1, #enemies - 1 do
        local first = enemies[firstIndex]
        if not first.dead then
            for secondIndex = firstIndex + 1, #enemies do
                local second = enemies[secondIndex]
                if not second.dead then
                    local dx = second.x - first.x
                    local dy = second.y - first.y
                    local distance = Length(dx, dy)
                    local minimum = first.radius + second.radius + 0.018
                    if distance < minimum then
                        if distance <= 0.0001 then
                            dx = first.id < second.id and 1 or -1
                            dy = 0
                            distance = 1
                        end
                        local push = (minimum - distance) * 0.5
                        local nx, ny = dx / distance, dy / distance
                        first.x = Clamp(first.x - nx * push, RoomConfig.minX, RoomConfig.maxX)
                        first.y = Clamp(first.y - ny * push, RoomConfig.minY, RoomConfig.maxY)
                        second.x = Clamp(second.x + nx * push, RoomConfig.minX, RoomConfig.maxX)
                        second.y = Clamp(second.y + ny * push, RoomConfig.minY, RoomConfig.maxY)
                    end
                end
            end
        end
    end
end

function Entities.UpdateProjectile(projectile, dt)
    projectile.x = projectile.x + projectile.vx * dt
    projectile.y = projectile.y + projectile.vy * dt
    projectile.lifetime = projectile.lifetime - dt
    projectile.turnTimer = math.max(0, (projectile.turnTimer or 0) - dt)
    if projectile.lifetime <= 0 or projectile.x < 0 or projectile.x > 1 or projectile.y < 0 or projectile.y > 1 then
        projectile.dead = true
    end
end

function Entities.TryParryEnemy(player, enemy, damage)
    if enemy.kind == "boss" or not Entities.IsParrying(player) or enemy.dead or enemy.state ~= "dash" then
        return false
    end

    local range = PlayerConfig.parryRange + player.radius + enemy.radius
    if not IsInRange(player, enemy, range) or not IsInsideParryCone(player, enemy) then
        return false
    end

    local appliedDamage = math.min(enemy.hp, damage)
    enemy.hp = enemy.hp - appliedDamage
    enemy.state = "recovery"
    enemy.stateTimer = EnemyConfig[enemy.kind].recoveryDuration + 0.3
    local knockback = PlayerConfig.meleeKnockback + player.abilities.repulse * 0.12
    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    directionX, directionY = Normalize(directionX, directionY)
    enemy.x = Clamp(enemy.x + directionX * knockback, RoomConfig.minX, RoomConfig.maxX)
    enemy.y = Clamp(enemy.y + directionY * knockback, RoomConfig.minY, RoomConfig.maxY)
    if enemy.hp <= 0 then
        enemy.dead = true
    end
    return true, appliedDamage
end

function Entities.TryParryProjectile(player, projectile, damageMultiplier, perfect)
    if not Entities.IsParrying(player) or projectile.dead or projectile.owner ~= "enemy" then
        return false
    end

    local range = PlayerConfig.parryRange + player.radius + projectile.radius
    if not IsInRange(player, projectile, range) or not IsInsideParryCone(player, projectile) then
        return false
    end

    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    local normalizedX, normalizedY = Normalize(directionX, directionY)
    local speed = Length(projectile.vx, projectile.vy) * ProjectileConfig.reflectedSpeedMultiplier
    projectile.vx = normalizedX * speed
    projectile.vy = normalizedY * speed
    projectile.owner = "player"
    projectile.reflected = true
    local baseDamage = projectile.damage
    if perfect then
        baseDamage = math.max(baseDamage, ProjectileConfig.perfectReflectedDamage)
    end
    projectile.damage = (baseDamage + player.abilities.heavy_return) * damageMultiplier
    projectile.pierceRemaining = player.abilities.piercing_echo
    projectile.chainsRemaining = perfect and ProjectileConfig.perfectReflectionChains or 0
    projectile.hitEnemies = {}
    projectile.lifetime = ProjectileConfig.lifetime
    return true
end

function Entities.EnemyTouchesPlayer(enemy, player)
    return enemy.state == "dash" and not enemy.dead
        and DistanceSquared(enemy, player) <= (enemy.radius + player.radius) ^ 2
end

function Entities.ProjectileHitsPlayer(projectile, player)
    return projectile.owner == "enemy" and not projectile.dead
        and DistanceSquared(projectile, player) <= (projectile.radius + player.radius) ^ 2
end

function Entities.ProjectileHitsEnemy(projectile, enemy)
    return projectile.owner == "player" and not projectile.dead and not enemy.dead
        and not projectile.hitEnemies[enemy.id]
        and DistanceSquared(projectile, enemy) <= (projectile.radius + enemy.radius) ^ 2
end

function Entities.ApplyUpgrade(player, definition)
    local current = player.abilities[definition.id]
    if current >= definition.maxStacks then
        return false
    end

    player.abilities[definition.id] = current + 1
    if definition.id == "wide_guard" then
        local halfAngle = math.rad(60 + (current + 1) * 12)
        player.parryHalfAngleCos = math.cos(halfAngle)
    end
    return true
end

function Entities.PlayerCanPickupChest(player, chest)
    return not chest.dead and DistanceSquared(player, chest) <= ChestConfig.pickupRadius * ChestConfig.pickupRadius
end

function Entities.GetDistanceSquared(a, b)
    return DistanceSquared(a, b)
end

function Entities.CanParryTarget(player, target, extraRange)
    local range = PlayerConfig.parryRange + player.radius + (target.radius or 0) + (extraRange or 0)
    return IsInRange(player, target, range) and IsInsideParryCone(player, target)
end

return Entities
