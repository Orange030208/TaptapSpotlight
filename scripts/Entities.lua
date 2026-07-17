local Config = require "Config"

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

    local facingX = player.facing == "left" and -1 or 1
    return (dx / distance) * facingX >= player.parryHalfAngleCos
end

local function IsInRange(player, target, range)
    return DistanceSquared(player, target) <= range * range
end

local function MoveEnemy(enemy, moveX, moveY, speed, dt)
    local directionX, directionY = Normalize(moveX, moveY)
    enemy.vx = directionX * speed
    enemy.vy = directionY * speed
    enemy.x = Clamp(enemy.x + enemy.vx * dt, Config.Room.minX, Config.Room.maxX)
    enemy.y = Clamp(enemy.y + enemy.vy * dt, Config.Room.minY, Config.Room.maxY)
    if math.abs(directionX) > 0.02 then
        enemy.facing = directionX < 0 and "left" or "right"
    end
end

function Entities.NewPlayer()
    local abilities = {}
    for _, definition in ipairs(Config.Upgrades.definitions) do
        abilities[definition.id] = 0
    end

    return {
        x = 0.5,
        y = 0.72,
        hp = Config.Player.maxHp,
        radius = Config.Player.radius,
        facing = "right",
        parryTimer = 0,
        parryElapsed = 0,
        parryCooldown = 0,
        invulnerabilityTimer = 0,
        parryHalfAngleCos = Config.Player.parryHalfAngleCos,
        abilities = abilities,
    }
end

function Entities.NewEnemy(kind, spawn, id)
    local spec = Config.Enemy[kind]
    return {
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
end

function Entities.NewProjectile(x, y, vx, vy, owner, damage, sourceKind)
    return {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        owner = owner,
        sourceKind = sourceKind,
        damage = damage or 1,
        radius = Config.Projectile.radius,
        lifetime = Config.Projectile.lifetime,
        reflected = false,
        pierceRemaining = 0,
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
    local directionX, directionY = Normalize(moveX, moveY)
    local speed = Config.Player.speed * (speedMultiplier or 1)
    player.x = Clamp(player.x + directionX * speed * dt, Config.Room.minX, Config.Room.maxX)
    player.y = Clamp(player.y + directionY * speed * dt, Config.Room.minY, Config.Room.maxY)

    if math.abs(directionX) > 0.05 then
        player.facing = directionX < 0 and "left" or "right"
    end

    if player.parryTimer > 0 then
        player.parryElapsed = player.parryElapsed + dt
    end
    player.parryTimer = math.max(0, player.parryTimer - dt)
    player.parryCooldown = math.max(0, player.parryCooldown - dt)
    player.invulnerabilityTimer = math.max(0, player.invulnerabilityTimer - dt)
end

function Entities.BeginParry(player)
    if player.parryCooldown > 0 then
        return false
    end

    player.parryTimer = Config.Player.parryWindow
    player.parryElapsed = 0
    player.parryCooldown = Config.Player.parryCooldown - player.abilities.quick_hands * 0.06
    player.parryCooldown = math.max(0.2, player.parryCooldown)
    return true
end

function Entities.IsParrying(player)
    return player.parryTimer > 0
end

function Entities.IsPerfectParry(player)
    return player.parryTimer > 0 and player.parryElapsed <= Config.Player.perfectParryWindow
end

function Entities.DamagePlayer(player, amount)
    if player.invulnerabilityTimer > 0 then
        return false
    end

    player.hp = math.max(0, player.hp - amount)
    player.invulnerabilityTimer = Config.Player.invulnerabilityDuration
    return true
end

function Entities.HealPlayer(player, amount)
    local previousHp = player.hp
    player.hp = math.min(Config.Player.maxHp, player.hp + amount)
    return player.hp > previousHp
end

function Entities.UpdateTacticalMovement(enemy, player, dt)
    local spec = Config.Enemy[enemy.kind]
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

    local spec = Config.Enemy[enemy.kind]
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
                        first.x = Clamp(first.x - nx * push, Config.Room.minX, Config.Room.maxX)
                        first.y = Clamp(first.y - ny * push, Config.Room.minY, Config.Room.maxY)
                        second.x = Clamp(second.x + nx * push, Config.Room.minX, Config.Room.maxX)
                        second.y = Clamp(second.y + ny * push, Config.Room.minY, Config.Room.maxY)
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
    if projectile.lifetime <= 0 or projectile.x < 0 or projectile.x > 1 or projectile.y < 0 or projectile.y > 1 then
        projectile.dead = true
    end
end

function Entities.TryParryEnemy(player, enemy, damage)
    if not Entities.IsParrying(player) or enemy.dead or enemy.state ~= "dash" then
        return false
    end

    local range = Config.Player.parryRange + player.radius + enemy.radius
    if not IsInRange(player, enemy, range) or not IsInsideParryCone(player, enemy) then
        return false
    end

    damage = damage or Config.Gauge.normalDamage
    local appliedDamage = math.min(enemy.hp, damage)
    enemy.hp = enemy.hp - appliedDamage
    enemy.state = "recovery"
    enemy.stateTimer = Config.Enemy[enemy.kind].recoveryDuration + 0.3
    local knockback = Config.Player.meleeKnockback + player.abilities.repulse * 0.12
    local facingX = player.facing == "left" and -1 or 1
    enemy.x = Clamp(enemy.x + facingX * knockback, Config.Room.minX, Config.Room.maxX)
    if enemy.hp <= 0 then
        enemy.dead = true
    end
    return true, appliedDamage
end

function Entities.TryParryProjectile(player, projectile, damageMultiplier)
    if not Entities.IsParrying(player) or projectile.dead or projectile.owner ~= "enemy" then
        return false
    end

    local range = Config.Player.parryRange + player.radius + projectile.radius
    if not IsInRange(player, projectile, range) or not IsInsideParryCone(player, projectile) then
        return false
    end

    local facingX = player.facing == "left" and -1 or 1
    local normalizedX, normalizedY = Normalize(facingX, projectile.vy * 0.55)
    local speed = Length(projectile.vx, projectile.vy) * Config.Projectile.reflectedSpeedMultiplier
    projectile.vx = normalizedX * speed
    projectile.vy = normalizedY * speed
    projectile.owner = "player"
    projectile.reflected = true
    projectile.damage = (projectile.damage + player.abilities.heavy_return) * (damageMultiplier or 1)
    projectile.pierceRemaining = player.abilities.piercing_echo
    projectile.hitEnemies = {}
    projectile.lifetime = Config.Projectile.lifetime
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

function Entities.RegisterProjectileHit(projectile, enemy)
    projectile.hitEnemies[enemy.id] = true
    if projectile.pierceRemaining > 0 then
        projectile.pierceRemaining = projectile.pierceRemaining - 1
    else
        projectile.dead = true
    end
end

function Entities.ApplyUpgrade(player, definition)
    local current = player.abilities[definition.id] or 0
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
    return not chest.dead and DistanceSquared(player, chest) <= Config.Chests.pickupRadius * Config.Chests.pickupRadius
end

function Entities.GetDistanceSquared(a, b)
    return DistanceSquared(a, b)
end

return Entities
