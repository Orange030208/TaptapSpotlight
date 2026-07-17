# SFX placeholder pack

These files are intentionally named after gameplay cues. Replace any `.ogg`
with another file using the same name to keep the Lua integration unchanged.

Recommended replacement format:

- Ogg Vorbis, mono or stereo
- 44.1 kHz or 48 kHz
- Short one-shot clips with no leading silence
- Peak below 0 dBFS to avoid clipping after overlapping sounds

## Cue map

| File | Gameplay cue | Original Kenney file |
| --- | --- | --- |
| `run_start.ogg` | Start or restart a run | Interface Sounds `confirmation_003.ogg` |
| `battle_start.ogg` | Enemies become active | Interface Sounds `select_003.ogg` |
| `parry_start.ogg` | Parry window begins | Sci-Fi Sounds `forceField_002.ogg` |
| `parry_success.ogg` | Normal melee/projectile parry | Sci-Fi Sounds `impactMetal_004.ogg` |
| `perfect_parry.ogg` | Perfect-timing parry | Impact Sounds `impactBell_heavy_002.ogg` |
| `projectile_fire.ogg` | Enemy projectile fired | Sci-Fi Sounds `laserSmall_000.ogg` |
| `projectile_reflect.ogg` | Projectile reflected | Sci-Fi Sounds `laserRetro_002.ogg` |
| `projectile_hit.ogg` | Reflected projectile hits enemy | Impact Sounds `impactGeneric_light_002.ogg` |
| `player_hurt.ogg` | Player loses health | Impact Sounds `impactPunch_heavy_002.ogg` |
| `enemy_defeat.ogg` | Regular enemy defeated | Impact Sounds `impactSoft_heavy_003.ogg` |
| `boss_defeat.ogg` | Boss defeated | Sci-Fi Sounds `explosionCrunch_001.ogg` |
| `chest_open.ogg` | Chest opens | Interface Sounds `open_004.ogg` |
| `upgrade_select.ogg` | Upgrade selected | Interface Sounds `confirmation_002.ogg` |
| `gauge_full.ogg` | A parry gauge reaches its threshold | Interface Sounds `confirmation_001.ogg` |
| `buff_gain.ogg` | Temporary buff starts | Interface Sounds `maximize_006.ogg` |
| `buff_end.ogg` | Temporary buff expires | Interface Sounds `minimize_004.ogg` |
| `room_clear.ogg` | Non-boss room cleared | Interface Sounds `confirmation_004.ogg` |
| `room_transition.ogg` | Player enters a door | Sci-Fi Sounds `doorOpen_001.ogg` |
| `game_over.ogg` | Run ends in defeat | Interface Sounds `error_005.ogg` |
| `victory.ogg` | Boss room completed | Impact Sounds `impactBell_heavy_001.ogg` |

## Source and license

All placeholder clips were downloaded from Kenney's official site and are
released under Creative Commons Zero (CC0 1.0):

- Interface Sounds: https://kenney.nl/assets/interface-sounds
- Impact Sounds: https://kenney.nl/assets/impact-sounds
- Sci-Fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/

Attribution is not required. Credit is still welcome: `Kenney (kenney.nl)`.
