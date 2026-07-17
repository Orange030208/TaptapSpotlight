# 音效占位素材包

所有文件均按玩法事件命名。后续只需用同名的 `.ogg` 文件替换，即可保留现有 Lua
接入逻辑、音量和触发时机，无需修改代码。

建议使用以下格式替换：

- Ogg Vorbis，单声道或立体声
- 44.1 kHz 或 48 kHz
- 短促的一次性音效，开头不要留静音
- 峰值低于 0 dBFS，避免多个音效重叠时削波失真

## 事件映射

| 文件 | 玩法事件 | 原始 Kenney 文件 |
| --- | --- | --- |
| `run_start.ogg` | 开始或重新开始一局 | Interface Sounds `confirmation_003.ogg` |
| `battle_start.ogg` | 敌人开始行动 | Interface Sounds `select_003.ogg` |
| `parry_start.ogg` | 招架窗口开启 | Sci-Fi Sounds `forceField_002.ogg` |
| `parry_success.ogg` | 普通近战或投射物招架成功 | Sci-Fi Sounds `impactMetal_004.ogg` |
| `perfect_parry.ogg` | 完美时机招架成功 | Impact Sounds `impactBell_heavy_002.ogg` |
| `projectile_fire.ogg` | 敌人发射投射物 | Sci-Fi Sounds `laserSmall_000.ogg` |
| `projectile_reflect.ogg` | 投射物被反射 | Sci-Fi Sounds `laserRetro_002.ogg` |
| `projectile_hit.ogg` | 反射投射物命中敌人 | Impact Sounds `impactGeneric_light_002.ogg` |
| `player_hurt.ogg` | 玩家失去生命 | Impact Sounds `impactPunch_heavy_002.ogg` |
| `enemy_defeat.ogg` | 普通敌人被击败 | Impact Sounds `impactSoft_heavy_003.ogg` |
| `boss_defeat.ogg` | Boss 被击败 | Sci-Fi Sounds `explosionCrunch_001.ogg` |
| `chest_open.ogg` | 开启宝箱 | Interface Sounds `open_004.ogg` |
| `upgrade_select.ogg` | 选择强化 | Interface Sounds `confirmation_002.ogg` |
| `gauge_full.ogg` | 招架量表达到阈值 | Interface Sounds `confirmation_001.ogg` |
| `buff_gain.ogg` | 获得临时增益 | Interface Sounds `maximize_006.ogg` |
| `buff_end.ogg` | 临时增益结束 | Interface Sounds `minimize_004.ogg` |
| `room_clear.ogg` | 非 Boss 房间清理完成 | Interface Sounds `confirmation_004.ogg` |
| `room_transition.ogg` | 通过门进入下一房间 | Sci-Fi Sounds `doorOpen_001.ogg` |
| `game_over.ogg` | 本局失败 | Interface Sounds `error_005.ogg` |
| `victory.ogg` | Boss 房间通关 | Impact Sounds `impactBell_heavy_001.ogg` |

## 来源与许可

所有占位音效均从 Kenney 官方网站下载，并以知识共享 CC0 1.0 协议发布：

- Interface Sounds：https://kenney.nl/assets/interface-sounds
- Impact Sounds：https://kenney.nl/assets/impact-sounds
- Sci-Fi Sounds：https://kenney.nl/assets/sci-fi-sounds
- CC0 1.0：https://creativecommons.org/publicdomain/zero/1.0/

该协议不要求署名；如需致谢，可标注 `Kenney (kenney.nl)`。
