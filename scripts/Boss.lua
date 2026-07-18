local BossConfig = require "Data.BossConfig"
local EnemyConfig = require "Data.EnemyConfig"
local PlayerConfig = require "Data.PlayerConfig"
local RoomConfig = require "Data.RoomConfig"

local Boss = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Length(x, y)
    return math.sqrt(x * x + y * y)
end

local function Normalize(x, y)
    local length = Length(x, y)
    if length <= 0.0001 then return 0, 0 end
    return x / length, y / length
end

local function FacingVector(entity)
    return entity.facing == "left" and -1 or 1, 0
end

local function IsInPlayerParry(player, x, y, extraRadius)
    local dx, dy = x - player.x, y - player.y
    local distance = Length(dx, dy)
    local range = PlayerConfig.parryRange + player.radius + (extraRadius or 0)
    if distance > range then return false end
    if distance <= 0.0001 then return true end
    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    directionX, directionY = Normalize(directionX, directionY)
    return (dx / distance) * directionX + (dy / distance) * directionY >= player.parryHalfAngleCos
end

local function IsInsideArc(boss, target, range, arcDegrees, reverse)
    local dx, dy = target.x - boss.x, target.y - boss.y
    local distance = Length(dx, dy)
    if distance > range + (target.radius or 0) then return false end
    if distance <= 0.0001 then return true end
    ---@type number
    local facingX = boss.facing == "left" and -1 or 1
    if reverse then facingX = -facingX end
    local halfAngle = math.rad(arcDegrees * 0.5)
    return (dx / distance) * facingX >= math.cos(halfAngle)
end

-- Two opposing capsules share the boss origin:
--      <===========[ B ]===========>
-- The half-width includes grazing contacts at exactly the boundary.
local function IsInsideSkewer(boss, target)
    local spec = BossConfig.attacks.skewer
    local dx, dy = target.x - boss.x, target.y - boss.y
    return math.abs(dx) <= spec.length + (target.radius or 0)
        and math.abs(dy) <= spec.halfWidth + (target.radius or 0)
end

local function IsInsideCharge(boss, target)
    local spec = BossConfig.attacks.charge
    return Length(target.x - boss.x, target.y - boss.y)
        <= spec.hitRadius + boss.radius + (target.radius or 0)
end

local function IsAttackHitting(boss, player)
    if boss.state ~= "active" then return false end
    if boss.attack == "sweep" then
        -- 180-degree forward fan: [ B ] -----> )
        return IsInsideArc(boss, player, BossConfig.attacks.sweep.range, 180, false)
    elseif boss.attack == "skewer" then
        return IsInsideSkewer(boss, player)
    elseif boss.attack == "charge" then
        -- Contact is tested along the moving boss circle, including the end point.
        return IsInsideCharge(boss, player)
    elseif boss.attack == "quake" then
        -- 270-degree fan; only the 90-degree wedge directly behind B is safe.
        return IsInsideArc(boss, player, BossConfig.attacks.quake.range, 270, false)
    elseif boss.attack == "feathers" then
        -- 飞龙在天只在落地瞬间判定，伤害中心锁定在起飞前记录的玩家位置。
        local spec = BossConfig.attacks.feathers
        if boss.feathersPhase ~= "landing" then return false end
        return Length(player.x - boss.landingX, player.y - boss.landingY)
            <= spec.landingRadius + (player.radius or 0)
    end
    return false
end

local function ResetAttack(boss, recovery)
    boss.state = "recovery"
    boss.stateTimer = recovery or BossConfig.recoveryDuration
    boss.attackTimer = 0
    boss.attackHitToken = nil
    boss.vx, boss.vy = 0, 0
end

local function BeginMechanismTransition(boss, nextMechanism)
    boss.mechanism = nextMechanism
    boss.mechanismTransition = BossConfig.mechanismTransitionDuration
    boss.state = "recovery"
    boss.stateTimer = BossConfig.mechanismTransitionDuration
    boss.attack = nil
    boss.vx, boss.vy = 0, 0
end

local function PickThornPosition(boss, player)
    local best, bestDistance = nil, -1
    for _, position in ipairs(BossConfig.mechanisms.thorns.positions) do
        local playerDistance = (position.x - player.x) ^ 2 + (position.y - player.y) ^ 2
        local bossDistance = (position.x - boss.x) ^ 2 + (position.y - boss.y) ^ 2
        local score = math.min(playerDistance, bossDistance)
        if score > bestDistance then
            best, bestDistance = position, score
        end
    end
    boss.thorn = {
        x = best.x, y = best.y, direction = math.random() < 0.5 and -1 or 1,
        state = "waiting",
        timer = math.max(0, BossConfig.mechanisms.thorns.interval
            - BossConfig.mechanisms.thorns.telegraph - BossConfig.mechanisms.thorns.active),
        hitCycle = -1, cycle = 0,
    }
end

local function EnterPhaseTwo(boss, player)
    boss.phase = 2
    boss.state = "phase_transition"
    boss.stateTimer = BossConfig.phaseTransitionDuration
    boss.attack = nil
    boss.mechanism = "fog"
    boss.mechanismProgress = 0
    boss.mechanismTransition = 0
    boss.fogSide = -1
    boss.vx, boss.vy = 0, 0
    boss.phaseChanged = true
    boss.thorn = nil
    boss.metalProgress = 0
    boss.playerAtTransition = { x = player.x, y = player.y }
end

function Boss.Initialize(enemy)
    enemy.bossName = BossConfig.name
    enemy.phase = 1
    enemy.entrance = true
    enemy.attack = nil
    enemy.lastAttack = nil
    enemy.attackTimer = 0
    enemy.attackHitToken = nil
    enemy.mechanism = nil
    enemy.mechanismProgress = 0
    enemy.mechanismTransition = 0
    enemy.thorn = nil
    enemy.metalProgress = 0
    enemy.purificationProgress = 0
    enemy.phaseChanged = false
    enemy.mechanismChanged = false
    enemy.purified = false
    enemy.lastParrySerial = -1
    return enemy
end

function Boss.SelectAttack(boss, player, roll)
    local total = 0
    local choices = {}
    local distance = Length(player.x - boss.x, player.y - boss.y)
    for _, name in ipairs(BossConfig.attackOrder) do
        if name ~= boss.lastAttack then
            local spec = BossConfig.attacks[name]
            local weight = name == "charge" and distance >= BossConfig.farDistance and spec.farWeight or spec.weight
            total = total + weight
            table.insert(choices, { name = name, ceiling = total })
        end
    end
    local value = Clamp(roll or math.random(), 0, 0.999999) * total
    for _, choice in ipairs(choices) do
        if value < choice.ceiling then return choice.name end
    end
    return choices[#choices].name
end

local function BeginAttack(boss, player, name)
    local spec = BossConfig.attacks[name]
    boss.attack = name
    boss.lastAttack = name
    boss.attackTimer = 0
    boss.attackHitToken = nil
    boss.feathersPhase = nil
    boss.landingX, boss.landingY = nil, nil
    if name == "feathers" then
        boss.state = "airborne"
        boss.feathersPhase = "takeoff"
        boss.stateTimer = spec.takeoff
        boss.landingX, boss.landingY = player.x, player.y
        boss.vx, boss.vy = 0, 0
    else
        boss.state = "telegraph"
        boss.stateTimer = spec.telegraph
        if player.x < boss.x then boss.facing = "left" else boss.facing = "right" end
    end
end

local function StartActiveAttack(boss, player)
    local spec = BossConfig.attacks[boss.attack]
    boss.state = "active"
    boss.attackTimer = 0
    boss.attackHitToken = nil
    if boss.attack == "feathers" then
        if boss.feathersPhase == "landing" then
            boss.state = "active"
            boss.stateTimer = spec.active
            boss.x = Clamp(boss.landingX, RoomConfig.minX, RoomConfig.maxX)
            boss.y = Clamp(boss.landingY, RoomConfig.minY, RoomConfig.maxY)
        else
            boss.state = "airborne"
            boss.feathersPhase = "takeoff"
            boss.stateTimer = spec.takeoff
            boss.landingX, boss.landingY = player.x, player.y
            boss.vx, boss.vy = 0, 0
        end
    elseif boss.attack == "charge" then
        local side = math.random() < 0.5 and -1 or 1
        boss.x = Clamp(player.x + side * spec.sideOffset, RoomConfig.minX, RoomConfig.maxX)
        boss.y = Clamp(player.y, RoomConfig.minY, RoomConfig.maxY)
        boss.dashX, boss.dashY = Normalize(player.x - boss.x, player.y - boss.y)
        boss.facing = boss.dashX < 0 and "left" or "right"
        boss.stateTimer = spec.active
    else
        boss.stateTimer = spec.active
    end
end

local function UpdateThorn(boss, dt)
    if boss.mechanism ~= "thorns" or boss.thorn == nil or boss.mechanismTransition > 0 then return end
    local thorn = boss.thorn
    thorn.timer = thorn.timer - dt
    if thorn.timer > 0 then return end
    if thorn.state == "waiting" then
        thorn.state = "telegraph"
        thorn.direction = math.random() < 0.5 and -1 or 1
        thorn.timer = BossConfig.mechanisms.thorns.telegraph
        thorn.cycle = thorn.cycle + 1
    elseif thorn.state == "telegraph" then
        thorn.state = "active"
        thorn.timer = BossConfig.mechanisms.thorns.active
        thorn.hitCycle = -1
    else
        thorn.state = "waiting"
        thorn.timer = math.max(0, BossConfig.mechanisms.thorns.interval
            - BossConfig.mechanisms.thorns.telegraph - BossConfig.mechanisms.thorns.active)
    end
end

local function UpdateIdleMovement(boss, player, dt)
    local spec = EnemyConfig.boss
    local toPlayerX, toPlayerY = Normalize(player.x - boss.x, player.y - boss.y)
    local distance = Length(player.x - boss.x, player.y - boss.y)
    boss.strafeTimer = (boss.strafeTimer or 0) - dt
    if boss.strafeTimer <= 0 then
        boss.strafeDirection = -(boss.strafeDirection or 1)
        boss.strafeTimer = 0.65 + math.random() * 0.65
    end
    local radial = 0
    if distance > spec.maximumDistance then radial = 1 end
    if distance < spec.minimumDistance then radial = -0.65 end
    local sideX, sideY = -toPlayerY * boss.strafeDirection, toPlayerX * boss.strafeDirection
    local moveX, moveY = Normalize(toPlayerX * radial + sideX * spec.strafeStrength * 0.45,
        toPlayerY * radial + sideY * spec.strafeStrength * 0.45)
    boss.vx, boss.vy = moveX * spec.moveSpeed, moveY * spec.moveSpeed
    boss.x = Clamp(boss.x + boss.vx * dt, RoomConfig.minX, RoomConfig.maxX)
    boss.y = Clamp(boss.y + boss.vy * dt, RoomConfig.minY, RoomConfig.maxY)
    if math.abs(toPlayerX) > 0.02 then boss.facing = toPlayerX < 0 and "left" or "right" end
end

function Boss.Update(boss, player, dt)
    if boss.state == "defeat" then
        boss.stateTimer = boss.stateTimer - dt
        if boss.stateTimer <= 0 then
            boss.dead = true
        end
        return
    end
    if boss.dead or boss.purified then return end
    boss.phaseChanged = false
    boss.mechanismChanged = false
    boss.mechanismTransition = math.max(0, boss.mechanismTransition - dt)

    if boss.state == "purifying" then
        boss.stateTimer = boss.stateTimer - dt
        boss.purificationProgress = Clamp(1 - boss.stateTimer / BossConfig.purificationDuration, 0, 1)
        if boss.stateTimer <= 0 then
            boss.purified = true
            boss.dead = true
        end
        return
    end

    boss.stateTimer = boss.stateTimer - dt
    if boss.state == "phase_transition" then
        boss.entrance = false
        if boss.stateTimer <= 0 then
            boss.state = "idle"
            boss.stateTimer = BossConfig.attackIntervalMax
        end
        return
    end

    UpdateThorn(boss, dt)

    if boss.state == "idle" then
        UpdateIdleMovement(boss, player, dt)
        if boss.stateTimer <= 0 and boss.mechanismTransition <= 0 then
            BeginAttack(boss, player, Boss.SelectAttack(boss, player))
        end
        return
    end
    if boss.state == "telegraph" then
        if boss.stateTimer <= 0 then StartActiveAttack(boss, player) end
        return
    end
    if boss.state == "airborne" then
        local spec = BossConfig.attacks.feathers
        boss.vx, boss.vy = 0, 0
        if boss.feathersPhase == "takeoff" and boss.stateTimer <= 0 then
            boss.feathersPhase = "airborne"
            boss.stateTimer = spec.airborne
            boss.landingX, boss.landingY = player.x, player.y
        elseif boss.feathersPhase == "airborne" and boss.stateTimer <= 0 then
            boss.feathersPhase = "landing"
            boss.state = "telegraph"
            boss.stateTimer = spec.landingTelegraph
            boss.landingX = Clamp(boss.landingX, RoomConfig.minX, RoomConfig.maxX)
            boss.landingY = Clamp(boss.landingY, RoomConfig.minY, RoomConfig.maxY)
        end
        return
    end
    if boss.state == "active" then
        local spec = BossConfig.attacks[boss.attack]
        boss.attackTimer = boss.attackTimer + dt
        if boss.attack == "charge" then
            boss.vx, boss.vy = boss.dashX * spec.dashSpeed, boss.dashY * spec.dashSpeed
            boss.x = Clamp(boss.x + boss.vx * dt, RoomConfig.minX, RoomConfig.maxX)
            boss.y = Clamp(boss.y + boss.vy * dt, RoomConfig.minY, RoomConfig.maxY)
        end
        if boss.stateTimer <= 0 then ResetAttack(boss) end
        return
    end
    if boss.state == "recovery" and boss.stateTimer <= 0 then
        boss.state = "idle"
        boss.stateTimer = BossConfig.attackIntervalMin
            + math.random() * (BossConfig.attackIntervalMax - BossConfig.attackIntervalMin)
    end
end

function Boss.CollectPlayerHits(boss, player)
    local hits = {}
    if boss.dead or boss.state == "phase_transition" or boss.state == "purifying" then return hits end
    if IsAttackHitting(boss, player) then
        local token = boss.attack
        if boss.attackHitToken ~= token then
            boss.attackHitToken = token
            local spec = BossConfig.attacks[boss.attack]
            table.insert(hits, {
                source = "boss", token = token, amount = spec.damage,
                invulnerability = spec.invulnerability or PlayerConfig.invulnerabilityDuration,
            })
        end
    end

    local thorn = boss.thorn
    if boss.mechanism == "thorns" and thorn ~= nil and thorn.state == "active" and thorn.hitCycle ~= thorn.cycle then
        -- Thorn root [T] lashes horizontally toward one random side:
        -- left  <======= [T] =======> right
        local spec = BossConfig.mechanisms.thorns
        local dx, dy = player.x - thorn.x, player.y - thorn.y
        local onChosenSide = dx * thorn.direction >= -(player.radius or 0)
        if onChosenSide and math.abs(dx) <= spec.reach + player.radius
            and math.abs(dy) <= spec.halfWidth + player.radius then
            thorn.hitCycle = thorn.cycle
            table.insert(hits, {
                source = "thorns", token = "thorn_" .. tostring(thorn.cycle), amount = spec.damage,
                invulnerability = PlayerConfig.invulnerabilityDuration,
            })
        end
    end
    return hits
end

local function CanParryCurrentAttack(boss, player)
    -- Boss [B] attack reaches player [P], but the guard must still point back
    -- toward the attacker: [B] <==== guard cone [P]. A guard facing away fails.
    if boss.attack == "feathers" and boss.feathersPhase == "landing" then
        local target = { x = boss.landingX, y = boss.landingY }
        return IsAttackHitting(boss, player)
            and IsInPlayerParry(player, target.x, target.y, 0)
    end
    return IsAttackHitting(boss, player)
        and IsInPlayerParry(player, boss.x, boss.y, boss.radius)
end

local function FogCore(boss, player)
    local distance = BossConfig.mechanisms.fog.coreDistance
    return Clamp(player.x + boss.fogSide * distance, RoomConfig.minX, RoomConfig.maxX),
        Clamp(player.y, RoomConfig.minY, RoomConfig.maxY)
end

local function MetalPosition(boss)
    local facingX = FacingVector(boss)
    return boss.x - facingX * BossConfig.mechanisms.metal.backOffset, boss.y - boss.radius * 0.45
end

function Boss.GetMechanismTarget(boss, player)
    if boss.mechanism == "fog" then
        local x, y = FogCore(boss, player)
        return x, y
    elseif boss.mechanism == "thorns" and boss.thorn ~= nil then
        return boss.thorn.x, boss.thorn.y
    elseif boss.mechanism == "metal" then
        return MetalPosition(boss)
    end
    return nil, nil
end

local function AdvanceMechanism(boss, player)
    if boss.mechanism == "fog" then
        boss.fogSide = -boss.fogSide
        if boss.mechanismProgress >= BossConfig.mechanisms.fog.required then
            boss.mechanismProgress = 0
            BeginMechanismTransition(boss, "thorns")
            PickThornPosition(boss, player)
            boss.mechanismChanged = true
        end
    elseif boss.mechanism == "thorns" and boss.mechanismProgress >= BossConfig.mechanisms.thorns.required then
        boss.mechanismProgress = 0
        boss.thorn = nil
        BeginMechanismTransition(boss, "metal")
        boss.mechanismChanged = true
    elseif boss.mechanism == "metal" and boss.mechanismProgress >= BossConfig.mechanisms.metal.required then
        boss.metalProgress = boss.mechanismProgress
        boss.state = "purifying"
        boss.stateTimer = BossConfig.purificationDuration
        boss.attack = nil
        boss.mechanism = "complete"
        boss.purificationProgress = 0
        boss.mechanismChanged = true
    end
end

function Boss.TryParry(boss, player, damage)
    if boss.dead or boss.state == "phase_transition" or boss.state == "purifying" then return nil end
    if player.parrySerial ~= nil and boss.lastParrySerial == player.parrySerial then return nil end

    if CanParryCurrentAttack(boss, player) then
        local result = { kind = "attack", attack = boss.attack, damage = 0, grantsGauge = boss.phase == 1 }
        if boss.phase == 1 then
            local thresholdHp = boss.maxHp * BossConfig.phaseThreshold
            local applied = math.min(damage or 0, math.max(0, boss.hp - thresholdHp))
            boss.hp = boss.hp - applied
            result.damage = applied
            if boss.hp <= thresholdHp + 0.0001 then EnterPhaseTwo(boss, player) else ResetAttack(boss, BossConfig.recoveryDuration + 0.3) end
        elseif boss.attack == "feathers" then
            boss.attackHitToken = "feathers_parried"
        else
            ResetAttack(boss, BossConfig.recoveryDuration + 0.3)
        end
        if player.parrySerial ~= nil then boss.lastParrySerial = player.parrySerial end
        return result
    end

    if boss.phase ~= 2 or boss.mechanismTransition > 0 then return nil end
    local targetX, targetY = Boss.GetMechanismTarget(boss, player)
    if targetX == nil or not IsInPlayerParry(player, targetX, targetY, 0.015) then return nil end

    if boss.mechanism == "thorns" then
        local thorn = boss.thorn
        if thorn == nil or thorn.state ~= "active" then return nil end
        local spec = BossConfig.mechanisms.thorns
        local dx, dy = player.x - thorn.x, player.y - thorn.y
        if dx * thorn.direction < -player.radius or math.abs(dx) > spec.reach + player.radius
            or math.abs(dy) > spec.halfWidth + player.radius then return nil end
        thorn.hitCycle = thorn.cycle
        thorn.state = "waiting"
        thorn.timer = math.max(0, spec.interval - spec.telegraph - spec.active)
    elseif boss.mechanism == "metal" then
        if boss.state ~= "idle" and boss.state ~= "recovery" then return nil end
        local facingX = FacingVector(boss)
        local playerBehind = (player.x - boss.x) * facingX < 0
        if not playerBehind then return nil end
        boss.state = "recovery"
        boss.stateTimer = math.max(boss.stateTimer, BossConfig.mechanisms.metal.stagger)
    end

    local previousMechanism = boss.mechanism
    boss.mechanismProgress = boss.mechanismProgress + 1
    if boss.mechanism == "metal" then boss.metalProgress = boss.mechanismProgress end
    local result = {
        kind = "mechanism", mechanism = boss.mechanism, progress = boss.mechanismProgress,
        grantsGauge = false, x = targetX, y = targetY,
    }
    AdvanceMechanism(boss, player)
    result.completed = boss.mechanism ~= previousMechanism
    if player.parrySerial ~= nil then boss.lastParrySerial = player.parrySerial end
    return result
end

function Boss.GetHud(boss)
    if boss == nil or boss.dead then return nil end
    local labels = { fog = "驱散黑雾", thorns = "反弹荆棘", metal = "拔出黑铁", complete = "净化中" }
    local required = 0
    if boss.mechanism ~= nil and BossConfig.mechanisms[boss.mechanism] ~= nil then
        required = BossConfig.mechanisms[boss.mechanism].required
    end
    return {
        name = BossConfig.name,
        phase = boss.phase,
        healthRatio = boss.hp / boss.maxHp,
        targetName = boss.state == "phase_transition" and "诅咒显形"
            or boss.state == "purifying" and "净化中" or labels[boss.mechanism],
        current = boss.state == "purifying" and boss.purificationProgress or boss.mechanismProgress,
        target = boss.state == "purifying" and 1 or required,
    }
end

function Boss.IsAttackHitting(boss, player)
    return IsAttackHitting(boss, player)
end

return Boss
