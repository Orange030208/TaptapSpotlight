local ChestConfig = require "Data.ChestConfig"
local EnemyConfig = require "Data.EnemyConfig"
local PlayerConfig = require "Data.PlayerConfig"
local ProjectileConfig = require "Data.ProjectileConfig"
local RoomConfig = require "Data.RoomConfig"
local CrystalConfig = require "Data.CrystalConfig"
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

local function Dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function Rotate(x, y, radians)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    return x * cosine - y * sine, x * sine + y * cosine
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

local function GetInitialAttackTimer(spec)
    local attack = spec.attack
    if attack == nil then
        return 0.8
    end
    if attack.repeatInterval ~= nil then
        return math.max(0, attack.repeatInterval - (attack.telegraph or 0))
    end
    return attack.interval * (0.55 + math.random() * 0.25)
end

local function GetRecoveryAttackTimer(spec)
    local attack = spec.attack
    if attack.repeatInterval ~= nil then
        return math.max(0, attack.repeatInterval - (attack.telegraph or 0) - (attack.active or 0) - (attack.recovery or 0))
    end
    return attack.interval * (0.8 + math.random() * 0.25)
end

function Entities.NewPlayer()
    local crystals = {}
    for _, definition in ipairs(CrystalConfig.definitions) do
        crystals[definition.id] = 0
    end

    return {
        x = 0.5,
        y = 0.72,
        hp = PlayerConfig.maxHp,
        radius = PlayerConfig.radius,
        facing = "right",
        isMoving = false,
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
        crystals = crystals,
        crystalOrder = {},
    }
end

function Entities.NewEnemy(kind, spawn, id)
    local spec = EnemyConfig[kind]
    assert(spec ~= nil, "Unknown enemy kind: " .. tostring(kind))
    local enemy = {
        id = id,
        kind = kind,
        x = spawn.x,
        y = spawn.y,
        radius = spec.radius,
        hp = spec.hp,
        maxHp = spec.hp,
        state = "idle",
        stateTimer = GetInitialAttackTimer(spec),
        vx = 0,
        vy = 0,
        facing = "right",
        dashX = 0,
        dashY = 0,
        attackMode = "dash",
        attackX = 1,
        attackY = 0,
        attackArc = 0,
        attackSerial = 0,
        attackHitSerial = -1,
        contactTimer = 0,
        mossTouching = false,
        splitGeneration = spawn.splitGeneration or 0,
        strafeDirection = math.random() < 0.5 and -1 or 1,
        strafeTimer = 0.55 + math.random() * 0.75,
        dead = false,
    }
    if spawn.hp ~= nil then
        enemy.hp = spawn.hp
        enemy.maxHp = spawn.hp
    end
    if kind == "boss" then
        return Boss.Initialize(enemy)
    end
    return enemy
end

function Entities.NewProjectile(x, y, vx, vy, owner, damage, sourceKind, style, radius)
    return {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        owner = owner,
        sourceKind = sourceKind,
        style = style or "bolt",
        damage = damage,
        radius = radius or ProjectileConfig.radius,
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
    player.isMoving = math.abs(directionX) > 0.001 or math.abs(directionY) > 0.001

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
        player.parryCooldown = PlayerConfig.parryCooldown
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
    player.parryCooldown = PlayerConfig.parryCooldown
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

local function IsCircleTouch(first, second)
    return DistanceSquared(first, second) <= (first.radius + second.radius) ^ 2
end

local function IsInsideAttackArc(enemy, player, range, arc)
    local dx = player.x - enemy.x
    local dy = player.y - enemy.y
    local distance = Length(dx, dy)
    if distance > range + player.radius then
        return false
    end
    if distance <= 0.0001 or arc >= 359 then
        return true
    end
    return Dot(dx / distance, dy / distance, enemy.attackX, enemy.attackY) >= math.cos(math.rad(arc * 0.5))
end

function Entities.IsEnemyInTrackingRange(enemy, player)
    local spec = EnemyConfig[enemy.kind]
    local range = spec.trackingRange or EnemyConfig.defaultTrackingRange
    return range > 0 and IsInRange(player, enemy, range)
end

function Entities.IsEnemyInAttackRange(enemy, player)
    local spec = EnemyConfig[enemy.kind]
    return spec.attackRange ~= nil and spec.attackRange > 0 and IsInRange(player, enemy, spec.attackRange)
end

function Entities.IsEnemyActive(enemy, player)
    return Entities.IsEnemyInTrackingRange(enemy, player)
end

local function MoveMeleeEnemy(enemy, player, spec, dt)
    local dx, dy = player.x - enemy.x, player.y - enemy.y
    local distance = Length(dx, dy)
    local preferredDistance = spec.preferredDistance or spec.attackRange * 0.54
    if distance > math.max(enemy.radius + player.radius + 0.045, preferredDistance) then
        MoveEnemy(enemy, dx, dy, spec.moveSpeed, dt)
    else
        enemy.vx, enemy.vy = 0, 0
    end
end

local function MoveRangedEnemy(enemy, player, spec, dt)
    if spec.moveSpeed <= 0 then
        enemy.vx, enemy.vy = 0, 0
        return
    end
    local dx, dy = player.x - enemy.x, player.y - enemy.y
    local distance = Length(dx, dy)
    local direction = 0
    if distance < spec.minimumDistance then
        direction = -1
    elseif distance > spec.maximumDistance then
        direction = 1
    end
    MoveEnemy(enemy, dx * direction, dy * direction, spec.moveSpeed, dt)
end

local function BeginTelegraph(enemy, player, spec)
    local attack = spec.attack
    enemy.attackX, enemy.attackY = Normalize(player.x - enemy.x, player.y - enemy.y)
    if enemy.attackX == 0 and enemy.attackY == 0 then
        enemy.attackX = enemy.facing == "left" and -1 or 1
    end
    if math.abs(enemy.attackX) > 0.02 then
        enemy.facing = enemy.attackX < 0 and "left" or "right"
    end
    if spec.behavior == "tree_swing" then
        enemy.attackArc = math.random() < 0.5 and attack.narrowArc or attack.wideArc
    else
        enemy.attackArc = attack.arc or 360
    end
    enemy.state = "telegraph"
    enemy.stateTimer = attack.telegraph
end

local function EmitConfiguredProjectiles(enemy, spec, emitProjectile)
    local projectile = spec.projectile
    local count = projectile.count
    if projectile.pattern == "radial_random" then
        local minRadius = projectile.minRadius or projectile.radius
        local maxRadius = projectile.maxRadius or projectile.radius
        for _ = 1, count do
            local angle = math.random() * math.pi * 2
            local radius = minRadius + (maxRadius - minRadius) * math.random()
            emitProjectile(Entities.NewProjectile(
                enemy.x, enemy.y,
                math.cos(angle) * projectile.speed, math.sin(angle) * projectile.speed,
                "enemy", projectile.damage, enemy.kind, projectile.style, radius
            ))
        end
        return
    end

    for index = 1, count do
        local offset = 0
        if count > 1 then
            offset = math.rad(projectile.spread) * ((index - 1) / (count - 1) - 0.5)
        end
        local directionX, directionY = Rotate(enemy.attackX, enemy.attackY, offset)
        emitProjectile(Entities.NewProjectile(
            enemy.x, enemy.y,
            directionX * projectile.speed, directionY * projectile.speed,
            "enemy", projectile.damage, enemy.kind, projectile.style, projectile.radius
        ))
    end
end

function Entities.UpdateEnemy(enemy, player, dt, emitProjectile)
    if enemy.dead then
        return
    end

    local spec = EnemyConfig[enemy.kind]
    local behavior = spec.behavior
    enemy.contactTimer = math.max(0, enemy.contactTimer - dt)

    if enemy.state == "stagger" then
        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer <= 0 then
            enemy.state = "idle"
            enemy.stateTimer = (spec.attack and spec.attack.interval or 0.75) * 0.55
        end
        return
    end

    if behavior == "ground_hazard" then
        enemy.vx, enemy.vy = 0, 0
        return
    end

    if behavior == "contact_chase" then
        if Entities.IsEnemyActive(enemy, player) then
            MoveEnemy(enemy, player.x - enemy.x, player.y - enemy.y, spec.moveSpeed, dt)
        else
            enemy.vx, enemy.vy = 0, 0
        end
        return
    end

    if enemy.state == "idle" then
        if not Entities.IsEnemyInTrackingRange(enemy, player) then
            enemy.vx, enemy.vy = 0, 0
            return
        end

        if spec.immovable then
            enemy.vx, enemy.vy = 0, 0
        elseif behavior == "ranged_single" or behavior == "ranged_fan" then
            MoveRangedEnemy(enemy, player, spec, dt)
        else
            MoveMeleeEnemy(enemy, player, spec, dt)
        end

        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer <= 0 and Entities.IsEnemyInAttackRange(enemy, player) then
            BeginTelegraph(enemy, player, spec)
        end
        return
    end

    if enemy.state == "telegraph" then
        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer > 0 then
            return
        end

        if behavior == "ranged_single" or behavior == "ranged_fan" then
            EmitConfiguredProjectiles(enemy, spec, emitProjectile)
            enemy.state = "recovery"
            enemy.stateTimer = spec.attack.recovery
        elseif behavior == "tree_swing" or behavior == "aoe_pulse" then
            enemy.attackSerial = enemy.attackSerial + 1
            enemy.state = "active"
            enemy.stateTimer = spec.attack.active
        else
            enemy.dashX, enemy.dashY = enemy.attackX, enemy.attackY
            enemy.attackSerial = enemy.attackSerial + 1
            enemy.state = "dash"
            enemy.stateTimer = spec.attack.active
        end
        return
    end

    if enemy.state == "dash" then
        MoveEnemy(enemy, enemy.dashX, enemy.dashY, spec.attack.dashSpeed, dt)
        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer <= 0 then
            enemy.state = "recovery"
            enemy.stateTimer = spec.attack.recovery
        end
        return
    end

    if enemy.state == "active" then
        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer <= 0 then
            enemy.state = "recovery"
            enemy.stateTimer = spec.attack.recovery
        end
        return
    end

    if enemy.state == "recovery" then
        enemy.stateTimer = enemy.stateTimer - dt
        if enemy.stateTimer <= 0 then
            enemy.state = "idle"
            enemy.stateTimer = GetRecoveryAttackTimer(spec)
        end
    end
end

function Entities.GetSplitChildren(enemy)
    local spec = EnemyConfig[enemy.kind]
    if spec.split == nil or enemy.splitGeneration >= 1 then
        return {}
    end

    local children = {}
    for index = 1, spec.split.count do
        local angle = (index - 1) * math.pi * 2 / spec.split.count
        table.insert(children, {
            x = Clamp(enemy.x + math.cos(angle) * spec.split.offset, RoomConfig.minX, RoomConfig.maxX),
            y = Clamp(enemy.y + math.sin(angle) * spec.split.offset, RoomConfig.minY, RoomConfig.maxY),
            hp = spec.hp * spec.split.childHpRatio,
            splitGeneration = enemy.splitGeneration + 1,
        })
    end
    return children
end

function Entities.CollectEnemyHit(enemy, player)
    if enemy.dead then
        return nil
    end

    local spec = EnemyConfig[enemy.kind]
    local behavior = spec.behavior
    local touching = IsCircleTouch(enemy, player)

    if behavior == "ground_hazard" then
        local entered = touching and not enemy.mossTouching
        enemy.mossTouching = touching
        if entered then
            return { amount = spec.touchDamage, sourceKind = enemy.kind }
        end
        return nil
    end

    if behavior == "contact_chase" then
        if touching and Entities.IsEnemyActive(enemy, player) and enemy.contactTimer <= 0 then
            enemy.contactTimer = spec.contactCooldown
            return { amount = spec.touchDamage, sourceKind = enemy.kind }
        end
        return nil
    end

    if enemy.state == "dash" and touching and enemy.attackHitSerial ~= enemy.attackSerial then
        enemy.attackHitSerial = enemy.attackSerial
        return { amount = spec.touchDamage, sourceKind = enemy.kind }
    end

    if enemy.state == "active" and behavior == "tree_swing"
        and enemy.attackHitSerial ~= enemy.attackSerial
        and IsInsideAttackArc(enemy, player, spec.attack.range, enemy.attackArc) then
        enemy.attackHitSerial = enemy.attackSerial
        return { amount = spec.touchDamage, sourceKind = enemy.kind }
    end

    if enemy.state == "active" and behavior == "aoe_pulse"
        and enemy.attackHitSerial ~= enemy.attackSerial
        and IsInRange(player, enemy, spec.attack.range + player.radius) then
        enemy.attackHitSerial = enemy.attackSerial
        return { amount = spec.touchDamage, sourceKind = enemy.kind }
    end
    return nil
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
                        local nx, ny
                        if distance <= 0.0001 then
                            nx = first.id < second.id and 1 or -1
                            ny = 0
                            distance = 0
                        else
                            nx, ny = dx / distance, dy / distance
                        end
                        local overlap = minimum - distance
                        local firstFixed = EnemyConfig[first.kind].immovable
                        local secondFixed = EnemyConfig[second.kind].immovable
                        if not (firstFixed and secondFixed) then
                            local firstPush = firstFixed and 0 or (secondFixed and overlap or overlap * 0.5)
                            local secondPush = secondFixed and 0 or (firstFixed and overlap or overlap * 0.5)
                            first.x = Clamp(first.x - nx * firstPush, RoomConfig.minX, RoomConfig.maxX)
                            first.y = Clamp(first.y - ny * firstPush, RoomConfig.minY, RoomConfig.maxY)
                            second.x = Clamp(second.x + nx * secondPush, RoomConfig.minX, RoomConfig.maxX)
                            second.y = Clamp(second.y + ny * secondPush, RoomConfig.minY, RoomConfig.maxY)
                        end
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

local function EnemyCanBeParried(enemy, player)
    local spec = EnemyConfig[enemy.kind]
    if spec.behavior == "melee_lunge" or spec.behavior == "rolling" then
        return enemy.state == "dash"
    end
    if spec.behavior == "tree_swing" then
        return enemy.state == "active"
    end
    if spec.behavior == "contact_chase" then
        return enemy.state ~= "stagger" and Entities.IsEnemyActive(enemy, player)
    end
    if spec.behavior == "ground_hazard" then
        return true
    end
    return spec.behavior == "aoe_pulse" and enemy.state == "telegraph"
end

function Entities.TryParryEnemy(player, enemy, damage)
    if enemy.kind == "boss" or not Entities.IsParrying(player) or enemy.dead or not EnemyCanBeParried(enemy, player) then
        return false
    end

    local range = PlayerConfig.parryRange + player.radius + enemy.radius
    if not IsInRange(player, enemy, range) or not IsInsideParryCone(player, enemy) then
        return false
    end

    local appliedDamage = math.min(enemy.hp, damage)
    enemy.hp = enemy.hp - appliedDamage
    local spec = EnemyConfig[enemy.kind]
    if spec.behavior == "contact_chase" then
        enemy.state = "stagger"
        enemy.stateTimer = spec.parryStagger
    elseif spec.behavior == "ground_hazard" then
        enemy.state = "idle"
        enemy.stateTimer = 0
    else
        enemy.state = "recovery"
        enemy.stateTimer = spec.attack.recovery + 0.3
    end
    local knockback = PlayerConfig.meleeKnockback
    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    directionX, directionY = Normalize(directionX, directionY)
    if spec.behavior ~= "ground_hazard" then
        enemy.x = Clamp(enemy.x + directionX * knockback, RoomConfig.minX, RoomConfig.maxX)
        enemy.y = Clamp(enemy.y + directionY * knockback, RoomConfig.minY, RoomConfig.maxY)
    end
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
    projectile.damage = baseDamage * damageMultiplier
    projectile.pierceRemaining = 0
    projectile.chainsRemaining = perfect and ProjectileConfig.perfectReflectionChains or 0
    projectile.hitEnemies = {}
    projectile.lifetime = ProjectileConfig.lifetime
    return true
end

function Entities.EnemyTouchesPlayer(enemy, player)
    return not enemy.dead and IsCircleTouch(enemy, player)
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

function Entities.ApplyCrystal(player, definition)
    local current = player.crystals[definition.id]
    if current >= definition.maxStacks then
        return false
    end

    player.crystals[definition.id] = current + 1
    if current == 0 then
        table.insert(player.crystalOrder, definition.id)
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
