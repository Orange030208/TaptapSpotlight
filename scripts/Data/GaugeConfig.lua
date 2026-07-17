-- Parry progression tuning. Values are intentionally centralized for rapid balance passes.
return {
    normalDamage = 0.5,
    perfectDamageMultiplier = 1.5,
    normalGain = 1,
    perfectGain = 2,

    order = { "melee", "ranged" },
    kinds = {
        melee = {
            label = "冲锋量表",
            threshold = 10,
            color = { 255, 112, 138 },
        },
        ranged = {
            label = "弹幕量表",
            threshold = 10,
            color = { 177, 130, 255 },
        },
    },

    buffs = {
        {
            id = "vital_echo",
            name = "生命回响",
            description = "7 秒内持续恢复生命",
            duration = 7.0,
            healPerSecond = 0.32,
            color = { 110, 244, 170 },
        },
        {
            id = "swift_step",
            name = "迅捷步伐",
            description = "7 秒内移动速度 +35%",
            duration = 7.0,
            moveSpeedMultiplier = 1.35,
            color = { 104, 214, 255 },
        },
        {
            id = "return_force",
            name = "反击增幅",
            description = "7 秒内招架伤害 +50%",
            duration = 7.0,
            parryDamageMultiplier = 1.5,
            color = { 255, 184, 96 },
        },
        {
            id = "resonant_flow",
            name = "共鸣涌流",
            description = "7 秒内量表增长 +100%",
            duration = 7.0,
            gaugeGainMultiplier = 2.0,
            color = { 248, 226, 112 },
        },
    },
}
