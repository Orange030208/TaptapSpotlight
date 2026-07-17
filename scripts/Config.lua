local GameConfig = require "Data.GameConfig"

-- Compatibility aggregator. Design-owned tables live in scripts/Data/*.lua.
return {
    Title = GameConfig.Title,
    Debug = GameConfig.Debug,
    Room = require "Data.RoomConfig",
    Player = require "Data.PlayerConfig",
    Enemy = require "Data.EnemyConfig",
    Projectile = require "Data.ProjectileConfig",
    Gauge = require "Data.GaugeConfig",
    Chests = require "Data.ChestConfig",
    Upgrades = require "Data.UpgradeConfig",
}
