local CrystalConfig = require "Data.CrystalConfig"
local Entities = require "Entities"
local RoomConfig = require "Data.RoomConfig"

local CrystalAbilities = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
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

local function Rotate(x, y, radians)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    return x * cosine - y * sine, x * sine + y * cosine
end

local function DistanceSquaredToSegment(px, py, startX, startY, endX, endY)
    local segmentX, segmentY = endX - startX, endY - startY
    local segmentLengthSquared = segmentX * segmentX + segmentY * segmentY
    if segmentLengthSquared <= 0.000001 then
        local dx, dy = px - startX, py - startY
        return dx * dx + dy * dy
    end
    local projection = ((px - startX) * segmentX + (py - startY) * segmentY) / segmentLengthSquared
    projection = Clamp(projection, 0, 1)
    local closestX = startX + segmentX * projection
    local closestY = startY + segmentY * projection
    local dx, dy = px - closestX, py - closestY
    return dx * dx + dy * dy
end

local function DistanceSquared(first, second)
    local dx, dy = first.x - second.x, first.y - second.y
    return dx * dx + dy * dy
end

local function HasCrystal(player, id)
    return player ~= nil and player.crystals ~= nil and (player.crystals[id] or 0) > 0
end

local function Emit(game, name, data)
    table.insert(game.events, { name = name, data = data or {} })
end

local function DamageEnemy(game, enemy, amount, popupKind)
    if enemy == nil or enemy.dead or enemy.kind == "boss" then
        return 0
    end
    local applied = math.min(enemy.hp, amount)
    enemy.hp = enemy.hp - applied
    if enemy.hp <= 0 then
        enemy.dead = true
    end
    if popupKind ~= nil and applied > 0 then
        Emit(game, "damage_dealt", {
            x = enemy.x,
            y = enemy.y,
            damage = applied,
            popupKind = popupKind,
            killed = enemy.dead,
        })
    end
    return applied
end

local function AddLightningBurst(state, points)
    table.insert(state.lightningBursts, {
        points = points,
        timer = 0.24,
        maxTimer = 0.24,
    })
end

function CrystalAbilities.NewState()
    return {
        dashWindow = 0,
        dash = nil,
        dashTrail = nil,
        perfectCount = 0,
        orbitShards = {},
        lightningBursts = {},
        latticeAnchors = {},
        latticeSerial = 0,
        mirrorGate = nil,
        riftPerfectCount = 0,
        riftAnchor = nil,
        riftNova = nil,
        nova = nil,
        timeBreak = nil,
        timeHeartUsed = false,
    }
end

function CrystalAbilities.GetState(game)
    if game.crystalState == nil then
        game.crystalState = CrystalAbilities.NewState()
    end
    return game.crystalState
end

function CrystalAbilities.OnPerfectParry(game)
    local player = game.player
    local state = CrystalAbilities.GetState(game)
    if HasCrystal(player, "crystal_lattice") then
        state.latticeSerial = state.latticeSerial + 1
        table.insert(state.latticeAnchors, {
            x = player.x,
            y = player.y,
            remaining = CrystalConfig.lattice.duration,
            duration = CrystalConfig.lattice.duration,
        })
        while #state.latticeAnchors > CrystalConfig.lattice.maxAnchors do
            table.remove(state.latticeAnchors, 1)
        end
        Emit(game, "crystal_lattice_anchor", { x = player.x, y = player.y })
    end
    if HasCrystal(player, "prism_dash") then
        state.dashWindow = CrystalConfig.dash.window
        Emit(game, "crystal_dash_ready", { x = player.x, y = player.y })
    end

    if HasCrystal(player, "orbit_shards") and #state.orbitShards < CrystalConfig.orbit.maxShards then
        table.insert(state.orbitShards, {
            remaining = CrystalConfig.orbit.duration,
            duration = CrystalConfig.orbit.duration,
            radius = CrystalConfig.orbit.shardRadius,
        })
        Emit(game, "crystal_orbit_gain", { x = player.x, y = player.y })
    end

    if HasCrystal(player, "thunder_chime") then
        state.perfectCount = state.perfectCount + 1
        if state.perfectCount >= CrystalConfig.lightning.requiredPerfects then
            state.perfectCount = 0

            local candidates = {}
            for _, enemy in ipairs(game.enemies) do
                if not enemy.dead and enemy.kind ~= "boss" then
                    local dx, dy = enemy.x - player.x, enemy.y - player.y
                    local distance = Length(dx, dy)
                    if distance <= CrystalConfig.lightning.range then
                        table.insert(candidates, { enemy = enemy, distance = distance })
                    end
                end
            end
            table.sort(candidates, function(a, b) return a.distance < b.distance end)

            local points = { { x = player.x, y = player.y } }
            local targetCount = math.min(CrystalConfig.lightning.targetCount, #candidates)
            for index = 1, targetCount do
                local enemy = candidates[index].enemy
                DamageEnemy(game, enemy, CrystalConfig.lightning.damage, "lightning")
                table.insert(points, { x = enemy.x, y = enemy.y })
            end
            if #points > 1 then
                AddLightningBurst(state, points)
                Emit(game, "crystal_lightning", { x = player.x, y = player.y, targets = #points - 1 })
            end
        end
    end

end

function CrystalAbilities.OnParryResult(game, perfect)
    local player = game.player
    local state = CrystalAbilities.GetState(game)
    if not HasCrystal(player, "rift_shift") then
        return
    end
    if not perfect then
        state.riftPerfectCount = 0
        return
    end

    state.riftPerfectCount = state.riftPerfectCount + 1
    if state.riftPerfectCount >= CrystalConfig.riftShift.requiredPerfects then
        state.riftPerfectCount = 0
        state.riftAnchor = { x = player.x, y = player.y }
        Emit(game, "crystal_rift_anchor", { x = player.x, y = player.y })
    end
end

function CrystalAbilities.OnEnemyDefeated(game, enemy)
    if enemy == nil or not enemy.mirrorGateEligible or not HasCrystal(game.player, "mirror_gate") then
        return
    end
    local state = CrystalAbilities.GetState(game)
    state.mirrorGate = {
        x = enemy.x,
        y = enemy.y,
        timer = CrystalConfig.mirrorGate.duration,
        maxTimer = CrystalConfig.mirrorGate.duration,
    }
    Emit(game, "crystal_mirror_gate", { x = enemy.x, y = enemy.y })
end

function CrystalAbilities.TrySwapDamage(game)
    local player = game.player
    local state = CrystalAbilities.GetState(game)
    local anchor = state.riftAnchor
    if not HasCrystal(player, "rift_shift") or anchor == nil then
        return false
    end

    local originX, originY = player.x, player.y
    player.x, player.y = anchor.x, anchor.y
    player.invulnerabilityTimer = math.max(player.invulnerabilityTimer, CrystalConfig.riftShift.invulnerability)
    state.riftAnchor = nil
    state.riftNova = {
        x = originX,
        y = originY,
        timer = 0.48,
        maxTimer = 0.48,
    }
    for _, enemy in ipairs(game.enemies) do
        if not enemy.dead and enemy.kind ~= "boss"
            and DistanceSquared(enemy, { x = originX, y = originY }) <= CrystalConfig.riftShift.novaRadius ^ 2 then
            DamageEnemy(game, enemy, CrystalConfig.riftShift.novaDamage, "rift")
        end
    end
    Emit(game, "crystal_rift_swap", { x = originX, y = originY, anchorX = anchor.x, anchorY = anchor.y })
    return true
end

function CrystalAbilities.OnProjectileReflected(game, projectile, perfect)
    if not perfect then
        return
    end

    if not HasCrystal(game.player, "mirror_split") or projectile.crystalSplit then
        return
    end

    local speed = Length(projectile.vx, projectile.vy)
    if speed <= 0.0001 then
        return
    end
    projectile.crystalSplit = true
    local directionX, directionY = projectile.vx / speed, projectile.vy / speed
    for _, angle in ipairs({ -CrystalConfig.split.angle, CrystalConfig.split.angle }) do
        local splitX, splitY = Rotate(directionX, directionY, angle)
        table.insert(game.projectiles, {
            x = projectile.x,
            y = projectile.y,
            vx = splitX * speed * CrystalConfig.split.speedMultiplier,
            vy = splitY * speed * CrystalConfig.split.speedMultiplier,
            owner = "player",
            sourceKind = "crystal_split",
            style = projectile.style,
            damage = projectile.damage * CrystalConfig.split.damageMultiplier,
            radius = projectile.radius * 0.84,
            lifetime = projectile.lifetime,
            reflected = true,
            crystalSplit = true,
            pierceRemaining = 0,
            hitEnemies = {},
            dead = false,
        })
    end
    Emit(game, "crystal_split", { x = projectile.x, y = projectile.y })
end

function CrystalAbilities.OnOverdrive(game)
    local player = game.player
    local state = CrystalAbilities.GetState(game)
    if HasCrystal(player, "nova_core") then
        state.nova = {
            x = player.x,
            y = player.y,
            timer = 0.46,
            maxTimer = 0.46,
        }
        for _, enemy in ipairs(game.enemies) do
            local dx, dy = enemy.x - player.x, enemy.y - player.y
            if dx * dx + dy * dy <= CrystalConfig.nova.radius * CrystalConfig.nova.radius then
                DamageEnemy(game, enemy, CrystalConfig.nova.damage, "nova")
            end
        end
        Emit(game, "crystal_nova", { x = player.x, y = player.y })
    end

end

function CrystalAbilities.TryPreventLethalDamage(game, amount)
    local player = game.player
    local state = CrystalAbilities.GetState(game)
    if not HasCrystal(player, "time_heart") or state.timeHeartUsed or player.hp > amount then
        return false
    end

    state.timeHeartUsed = true
    player.hp = 1
    player.invulnerabilityTimer = CrystalConfig.timeHeart.invulnerability
    game.projectiles = {}
    state.timeBreak = {
        x = player.x,
        y = player.y,
        timer = 0.72,
        maxTimer = 0.72,
    }
    Emit(game, "crystal_time_break", { x = player.x, y = player.y })
    return true
end

local function UpdateDash(game, state, dt, moveX, moveY)
    local player = game.player
    if state.dash == nil and state.dashWindow > 0 then
        state.dashWindow = math.max(0, state.dashWindow - dt)
        local directionX, directionY = Normalize(moveX, moveY)
        if directionX ~= 0 or directionY ~= 0 then
            state.dashWindow = 0
            state.dash = {
                startX = player.x,
                startY = player.y,
                directionX = directionX,
                directionY = directionY,
                timer = CrystalConfig.dash.duration,
                maxTimer = CrystalConfig.dash.duration,
                hitEnemies = {},
            }
            Emit(game, "crystal_dash_start", { x = player.x, y = player.y, directionX = directionX, directionY = directionY })
        end
    end

    local dash = state.dash
    if dash == nil then
        return
    end

    local previousX, previousY = player.x, player.y
    local step = math.min(dt, dash.timer)
    player.x, player.y = RoomConfig.ClampPlayerPosition(
        player.x + dash.directionX * CrystalConfig.dash.speed * step,
        player.y + dash.directionY * CrystalConfig.dash.speed * step,
        player.radius
    )
    player.isMoving = true
    if math.abs(dash.directionX) > 0.01 then
        player.facing = dash.directionX < 0 and "left" or "right"
    end
    dash.timer = math.max(0, dash.timer - step)
    state.dashTrail = {
        startX = previousX,
        startY = previousY,
        endX = player.x,
        endY = player.y,
        timer = 0.16,
        maxTimer = 0.16,
    }

    for _, enemy in ipairs(game.enemies) do
        if not enemy.dead and enemy.kind ~= "boss" and not dash.hitEnemies[enemy.id] then
            local hitRadius = CrystalConfig.dash.radius + enemy.radius
            if DistanceSquaredToSegment(enemy.x, enemy.y, previousX, previousY, player.x, player.y) <= hitRadius * hitRadius then
                dash.hitEnemies[enemy.id] = true
                DamageEnemy(game, enemy, CrystalConfig.dash.damage, "dash")
                Emit(game, "crystal_dash_hit", { x = enemy.x, y = enemy.y })
            end
        end
    end
    if dash.timer <= 0 then
        state.dash = nil
    end
end

local function UpdateOrbitShards(game, state, dt)
    local player = game.player
    for index = #state.orbitShards, 1, -1 do
        local shard = state.orbitShards[index]
        shard.remaining = math.max(0, (shard.remaining or CrystalConfig.orbit.duration) - dt)
        if shard.remaining <= 0 then
            table.remove(state.orbitShards, index)
            Emit(game, "crystal_orbit_expire", { x = player.x, y = player.y })
        end
    end
    local shardCount = #state.orbitShards
    for index, shard in ipairs(state.orbitShards) do
        local angle = game.time * 5.4 + (index - 1) * math.pi * 2 / shardCount
        shard.x = player.x + math.cos(angle) * CrystalConfig.orbit.radius
        shard.y = player.y + math.sin(angle) * CrystalConfig.orbit.radius
    end
end

local function UpdateLattice(game, state, dt)
    for index = #state.latticeAnchors, 1, -1 do
        local anchor = state.latticeAnchors[index]
        anchor.remaining = math.max(0, anchor.remaining - dt)
        if anchor.remaining <= 0 then
            table.remove(state.latticeAnchors, index)
            state.latticeSerial = state.latticeSerial + 1
            Emit(game, "crystal_lattice_expire", { x = anchor.x, y = anchor.y })
        end
    end

    if #state.latticeAnchors < 2 then
        return
    end

    local first, second = state.latticeAnchors[1], state.latticeAnchors[2]
    local lineRadius = CrystalConfig.lattice.lineRadius
    for _, projectile in ipairs(game.projectiles) do
        if projectile.owner == "enemy" and not projectile.dead
            and DistanceSquaredToSegment(projectile.x, projectile.y, first.x, first.y, second.x, second.y)
                <= (lineRadius + projectile.radius) ^ 2 then
            projectile.dead = true
            Emit(game, "crystal_lattice_cut", { x = projectile.x, y = projectile.y, kind = "projectile" })
        end
    end

    for _, enemy in ipairs(game.enemies) do
        if not enemy.dead and enemy.kind ~= "boss" and enemy.latticeHitSerial ~= state.latticeSerial
            and DistanceSquaredToSegment(enemy.x, enemy.y, first.x, first.y, second.x, second.y)
                <= (lineRadius + enemy.radius) ^ 2 then
            enemy.latticeHitSerial = state.latticeSerial
            DamageEnemy(game, enemy, CrystalConfig.lattice.enemyDamage, "lattice")
            Emit(game, "crystal_lattice_cut", { x = enemy.x, y = enemy.y, kind = "enemy" })
        end
    end
end

local function UpdateMirrorGate(game, state, dt)
    local gate = state.mirrorGate
    if gate == nil then
        return
    end
    gate.timer = math.max(0, gate.timer - dt)
    if gate.timer <= 0 then
        state.mirrorGate = nil
        Emit(game, "crystal_mirror_gate_expire", { x = gate.x, y = gate.y })
        return
    end

    for _, projectile in ipairs(game.projectiles) do
        if projectile.owner == "enemy" and not projectile.dead
            and DistanceSquared(projectile, gate) <= (projectile.radius + CrystalConfig.mirrorGate.radius) ^ 2 then
            projectile.vx = -projectile.vx * CrystalConfig.mirrorGate.speedMultiplier
            projectile.vy = -projectile.vy * CrystalConfig.mirrorGate.speedMultiplier
            projectile.owner = "player"
            projectile.sourceKind = "mirror_gate"
            projectile.reflected = true
            projectile.damage = CrystalConfig.mirrorGate.damage
            projectile.pierceRemaining = 0
            projectile.hitEnemies = {}
            projectile.lifetime = math.min(projectile.lifetime, 1.8)
            Emit(game, "crystal_mirror_gate_reflect", { x = projectile.x, y = projectile.y })
        end
    end
end

local function UpdateTransientEffects(state, dt)
    if state.dashTrail ~= nil then
        state.dashTrail.timer = math.max(0, state.dashTrail.timer - dt)
        if state.dashTrail.timer <= 0 then state.dashTrail = nil end
    end
    for index = #state.lightningBursts, 1, -1 do
        local burst = state.lightningBursts[index]
        burst.timer = math.max(0, burst.timer - dt)
        if burst.timer <= 0 then table.remove(state.lightningBursts, index) end
    end
    if state.nova ~= nil then
        state.nova.timer = math.max(0, state.nova.timer - dt)
        if state.nova.timer <= 0 then state.nova = nil end
    end
    if state.timeBreak ~= nil then
        state.timeBreak.timer = math.max(0, state.timeBreak.timer - dt)
        if state.timeBreak.timer <= 0 then state.timeBreak = nil end
    end
    if state.riftNova ~= nil then
        state.riftNova.timer = math.max(0, state.riftNova.timer - dt)
        if state.riftNova.timer <= 0 then state.riftNova = nil end
    end
end

function CrystalAbilities.UpdateCombat(game, dt, moveX, moveY)
    local state = CrystalAbilities.GetState(game)
    UpdateDash(game, state, dt, moveX, moveY)
end

function CrystalAbilities.UpdatePassive(game, dt)
    local state = CrystalAbilities.GetState(game)
    UpdateOrbitShards(game, state, dt)
    UpdateLattice(game, state, dt)
    UpdateMirrorGate(game, state, dt)
    UpdateTransientEffects(state, dt)
end

local function ReflectProjectileFromOrbit(shard, projectile)
    local speed = Length(projectile.vx, projectile.vy)
    if speed <= 0.0001 then
        projectile.vx, projectile.vy = 0, -0.4
    else
        projectile.vx = -projectile.vx / speed * speed * CrystalConfig.orbit.reflectionSpeedMultiplier
        projectile.vy = -projectile.vy / speed * speed * CrystalConfig.orbit.reflectionSpeedMultiplier
    end
    projectile.owner = "player"
    projectile.sourceKind = "orbit_guard"
    projectile.reflected = true
    projectile.crystalGuard = true
    projectile.damage = CrystalConfig.orbit.guardDamage
    projectile.pierceRemaining = 0
    projectile.hitEnemies = {}
    projectile.lifetime = math.min(projectile.lifetime, 1.8)
end

function CrystalAbilities.ResolveOrbitGuards(game)
    local state = CrystalAbilities.GetState(game)
    for shardIndex = #state.orbitShards, 1, -1 do
        local shard = state.orbitShards[shardIndex]
        if shard.x ~= nil then
            local blocked = false
            for _, projectile in ipairs(game.projectiles) do
                if projectile.owner == "enemy" and not projectile.dead
                    and DistanceSquared(shard, projectile) <= (shard.radius + projectile.radius) ^ 2 then
                    ReflectProjectileFromOrbit(shard, projectile)
                    table.remove(state.orbitShards, shardIndex)
                    Emit(game, "crystal_orbit_block", {
                        x = shard.x,
                        y = shard.y,
                        kind = "projectile",
                    })
                    blocked = true
                    break
                end
            end
            if not blocked then
                for _, enemy in ipairs(game.enemies) do
                    local parried, damage = Entities.TryOrbitGuardEnemy(
                        shard, enemy, game.player, CrystalConfig.orbit.guardDamage)
                    if parried then
                        table.remove(state.orbitShards, shardIndex)
                        Emit(game, "crystal_orbit_block", {
                            x = shard.x,
                            y = shard.y,
                            kind = "enemy",
                            damage = damage,
                        })
                        break
                    end
                end
            end
        end
    end
end

function CrystalAbilities.Update(game, dt, moveX, moveY)
    CrystalAbilities.UpdateCombat(game, dt, moveX, moveY)
    CrystalAbilities.UpdatePassive(game, dt)
end

function CrystalAbilities.IsDashing(game)
    local state = CrystalAbilities.GetState(game)
    return state.dash ~= nil
end

return CrystalAbilities
