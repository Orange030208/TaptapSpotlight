# 暗黑地牢音效包

本目录包含 22 个已经接入玩法事件的成品音效。文件名是稳定的事件接口，替换时必须保留
同名 `.ogg` 文件，Lua 中的音量、随机音高和触发时机无需修改。

本批素材的方向是近距离金属碰撞、石质空间反射、压低的重击与克制的魔法残响；不使用
8-bit、界面哔声或科幻激光作为核心音色。既有音效由 CC0 实录素材分层、均衡、短混响
和响度控制后导出；`crystal_dash_start.ogg` 与 `boss_entrance.ogg` 为 AI 生成的专用玩法音效。

## 技术规格

- Ogg Vorbis，44.1 kHz 或 48 kHz，立体声
- 起音控制在 5 ms 内，适合招架与命中反馈
- 成品峰值低于 0 dBFS，为游戏中的并发音效预留余量
- 大部分 cue 时长为 1-2 秒，尾部用于表现地牢空间，不应循环播放

## 事件映射

| 文件 | 玩法事件 | 核心构成 |
| --- | --- | --- |
| `run_start.ogg` | 开始或重新开始一局 | 刀刃挥动、拔刀与金属锁扣 |
| `battle_start.ogg` | 普通敌人开始行动 | 实录刀刃相击与厚重金属板撞击 |
| `boss_entrance.ogg` | 首次进入未清理的 Boss 房，开场结束且 Boss 正式开始行动 | 巨石低频冲击、古老怪物低吼、铁链甲片共振与诅咒魔力轰鸣 |
| `parry_start.ogg` | 招架窗口开启 | 拔刀摩擦与低调魔法预兆 |
| `parry_success.ogg` | 普通近战或投射物招架成功 | 实录武器格挡、刀剑碰撞与金属瞬态 |
| `perfect_parry.ogg` | 完美时机招架成功 | 钉锤与北欧剑重击、强化刀剑格挡与金属余振 |
| `projectile_fire.ogg` | 敌人发射投射物 | 暗奇幻法术起音与空气挥动 |
| `projectile_reflect.ogg` | 投射物被反射 | 反向法术吸附、长柄武器撞刃与金属回响 |
| `projectile_hit.ogg` | 反射投射物命中敌人 | 钉锤撞刃与低频实体命中 |
| `player_hurt.ogg` | 玩家失去生命 | 低频受击与轻甲碰撞 |
| `enemy_defeat.ogg` | 普通敌人被击败 | 实录重兵器命中与收束的低频冲击 |
| `boss_defeat.ogg` | Boss 被击败 | 降调重兵器撞击、厚门闭合与长尾空间反射 |
| `chest_open.ogg` | 开启宝箱 | 金属锁扣、木门开启与硬币散落 |
| `upgrade_select.ogg` | 选择强化 | 暗奇幻魔法确认、金属泛音与锁扣 |
| `crystal_dash_start.ogg` | 获得“棱镜冲刺”后，完美格挡触发窗口内开始冲刺 | 短促空气冲击、水晶玻璃闪鸣、轻微金属共振与石质地牢短混响 |
| `gauge_full.ogg` | 招架量表达到阈值 | 金属泛音与沉稳钟鸣余振 |
| `buff_gain.ogg` | 获得临时增益 | 法术上扬与金属泛音 |
| `buff_end.ogg` | 临时增益结束 | 反向法术残响与衰减的木质摩擦 |
| `room_clear.ogg` | 非 Boss 房间清理完成 | 法术收束、金属泛音与克制钟鸣 |
| `room_transition.ogg` | 通过门进入下一房间 | 厚门开启、木质摩擦与金属锁扣 |
| `game_over.ogg` | 本局失败 | 降调门闭合与反向法术下坠 |
| `victory.ogg` | Boss 房间通关 | 门扉开启、法术余韵、硬币与金属泛音 |

## 来源与许可

所有原始图层均可随项目公开分发，并以 CC0 1.0 或等价的无保留权利声明发布：

- [Medieval sound effects - Weapon impacts](https://opengameart.org/content/medieval-sound-effects-weapon-impacts)，Ben Jaszczak 与 Brian Nelson，CC0。用于实录刀刃、长柄兵器与钉锤撞击。
- [20 Sword Sound Effects (Attacks and Clashes)](https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes)，StarNinjas，CC0。用于短刀剑挥动和格挡层。
- [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack)，artisticdude，CC0。用于法术、门、硬币、轻甲与金属泛音层。
- [RPG Audio](https://kenney.nl/assets/rpg-audio) 与 [Impact Sounds](https://kenney.nl/assets/impact-sounds)，Kenney，CC0 1.0。仅作为锁扣、布料、低频冲击和补充金属层。
- [CC0 1.0 协议](https://creativecommons.org/publicdomain/zero/1.0/)。不要求署名；本清单保留来源，便于后续审计和替换。

## 后续替换约定

如需替换某一个 cue，请继续使用 44.1 kHz 或 48 kHz 的 Ogg Vorbis；保持起音紧凑，且峰值
低于 0 dBFS。不要更改上述文件名，避免破坏 `AudioManager.lua` 中的事件映射。
