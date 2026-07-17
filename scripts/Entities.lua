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

function Entities.NewPlayer()
    return {
        x = 0.5,
        y = 0.72,
        hp = Config.Player.maxHp,
        radius = Config.Player.radius,
        facing = "right",
        parryTimer = 0,
        parryCooldown = 0,
        invulnerabilityTimer = 0,
        parryHalfAngleCos = Config.Player.parryHalfAngleCos,
        abilities = {
            wide_guard = 0,
            quick_hands = 0,
            heavy_return = 0,
            repulse = 0,
        },
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
        state = "idle",
        stateTimer = 0.45 + math.random() * 0.35,
        vx = 0,
        vy = 0,
        dashX = 0,
        dashY = 0,
        attackMode = "dash",
        dead = false,
        activationDelay = 0,
    }
end

function Entities.NewProjectile(x, y, vx, vy, owner, damage)
    return {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        owner = owner,
        damage = damage or 1,
        radius = Config.Projectile.radius,
        lifetime = Config.Projectile.lifetime,
        reflected = false,
        dead = false,
    }
end

function Entities.NewDrop(x, y, definition)
    return {
        x = x,
        y = y,
        definition = definition,
        radius = 0.02,
        bobTime = math.random() * math.pi * 2,
        dead = false,
    }
end

function Entities.UpdatePlayer(player, dt, moveX, moveY)
    local directionX, directionY = Normalize(moveX, moveY)
    player.x = Clamp(player.x + directionX * Config.Player.speed * dt, Config.Room.minX, Config.Room.maxX)
    player.y = Clamp(player.y + directionY * Config.Player.speed * dt, Config.Room.minY, Config.Room.maxY)

    if math.abs(directionX) > 0.05 then
        player.facing = directionX < 0 and "left" or "right"
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
    player.parryCooldown = Config.Player.parryCooldown - player.abilities.quick_hands * 0.06
    player.parryCooldown = math.max(0.2, player.parryCooldown)
    return true
end

function Entities.IsParrying(player)
    return player.parryTimer > 0
end

function Entities.DamagePlayer(player, amount)
    if player.invulnerabilityTimer > 0 then
        return false
    end

    player.hp = math.max(0, player.hp - amount)
    player.invulnerabilityTimer = Config.Player.invulnerabilityDuration
    return true
end

function Entities.UpdateEnemy(enemy, player, dt, emitProjectile)
    if enemy.dead then
        return
    end

    local spec = Config.Enemy[enemy.kind]
    enemy.stateTimer = enemy.stateTimer - dt

    if enemy.state == "idle" and enemy.stateTimer <= 0 then
        enemy.state = "telegraph"
        enemy.stateTimer = spec.telegraphDuration
        if enemy.kind == "boss" then
            enemy.attackMode = enemy.attackMode == "dash" and "volley" or "dash"
        end
        return
    end

    if enemy.state == "telegraph" and enemy.stateTimer <= 0 then
        if enemy.kind == "ranged" or (enemy.kind == "boss" and enemy.attackMode == "volley") then
            local dx, dy = Normalize(player.x - enemy.x, player.y - enemy.y)
            emitProjectile(Entities.NewProjectile(
                enemy.x, enemy.y,
                dx * spec.projectileSpeed, dy * spec.projectileSpeed,
                "enemy", 1
            ))
            if enemy.kind == "boss" then
                emitProjectile(Entities.NewProjectile(enemy.x, enemy.y, (dx - dy * 0.35) * spec.projectileSpeed, (dy + dx * 0.35) * spec.projectileSpeed, "enemy", 1))
                emitProjectile(Entities.NewProjectile(enemy.x, enemy.y, (dx + dy * 0.35) * spec.projectileSpeed, (dy - dx * 0.35) * spec.projectileSpeed, "enemy", 1))
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
        enemy.x = Clamp(enemy.x + enemy.dashX * spec.dashSpeed * dt, Config.Room.minX, Config.Room.maxX)
        enemy.y = Clamp(enemy.y + enemy.dashY * spec.dashSpeed * dt, Config.Room.minY, Config.Room.maxY)
        if enemy.stateTimer <= 0 then
            enemy.state = "recovery"
            enemy.stateTimer = spec.recoveryDuration
        end
        return
    end

    if enemy.state == "recovery" and enemy.stateTimer <= 0 then
        enemy.state = "idle"
        enemy.stateTimer = 0.35 + math.random() * 0.5
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

function Entities.TryParryEnemy(player, enemy)
    if not Entities.IsParrying(player) or enemy.dead or enemy.state ~= "dash" then
        return false
    end

    local range = Config.Player.parryRange + player.radius + enemy.radius
    if not IsInRange(player, enemy, range) or not IsInsideParryCone(player, enemy) then
        return false
    end

    local damage = enemy.kind == "boss" and 1 or enemy.hp
    enemy.hp = enemy.hp - damage
    enemy.state = "recovery"
    enemy.stateTimer = Config.Enemy[enemy.kind].recoveryDuration + 0.3
    local knockback = Config.Player.meleeKnockback + player.abilities.repulse * 0.12
    local facingX = player.facing == "left" and -1 or 1
    enemy.x = Clamp(enemy.x + facingX * knockback, Config.Room.minX, Config.Room.maxX)
    if enemy.hp <= 0 then
        enemy.dead = true
    end
    return true
end

function Entities.TryParryProjectile(player, projectile)
    if not Entities.IsParrying(player) or projectile.dead or projectile.owner ~= "enemy" then
        return false
    end

    local range = Config.Player.parryRange + player.radius + projectile.radius
    if not IsInRange(player, projectile, range) or not IsInsideParryCone(player, projectile) then
        return false
    end

    local facingX = player.facing == "left" and -1 or 1
    local incomingY = projectile.vy
    local normalizedX, normalizedY = Normalize(facingX, incomingY * 0.55)
    local speed = Length(projectile.vx, projectile.vy) * Config.Projectile.reflectedSpeedMultiplier
    projectile.vx = normalizedX * speed
    projectile.vy = normalizedY * speed
    projectile.owner = "player"
    projectile.reflected = true
    projectile.damage = projectile.damage + player.abilities.heavy_return
    projectile.lifetime = Config.Projectile.lifetime
    return true
end

function Entities.EnemyTouchesPlayer(enemy, player)
    local isAttacking = enemy.state == "dash"
    return isAttacking and not enemy.dead and DistanceSquared(enemy, player) <= (enemy.radius + player.radius) ^ 2
end

function Entities.ProjectileHitsPlayer(projectile, player)
    return projectile.owner == "enemy" and not projectile.dead and DistanceSquared(projectile, player) <= (projectile.radius + player.radius) ^ 2
end

function Entities.ProjectileHitsEnemy(projectile, enemy)
    return projectile.owner == "player" and not projectile.dead and not enemy.dead
        and DistanceSquared(projectile, enemy) <= (projectile.radius + enemy.radius) ^ 2
end

function Entities.ApplyDrop(player, definition)
    local current = player.abilities[definition.id] or 0
    if current >= definition.maxStacks then
        return false
    end

    player.abilities[definition.id] = current + 1
    if definition.id == "wide_guard" then
        local halfAngle = math.rad(60 + current * 12)
        player.parryHalfAngleCos = math.cos(halfAngle)
    end
    return true
end

function Entities.PlayerCanPickup(player, drop)
    return not drop.dead and DistanceSquared(player, drop) <= Config.Drops.pickupRadius * Config.Drops.pickupRadius
end

function Entities.GetDistanceSquared(a, b)
    return DistanceSquared(a, b)
end

return Entities
