# The Sunken Bastion (dungeon)

`scenes/dungeon.tscn` + `scripts/dungeon/`. Act IV of `docs/STORY.md`: three floors under the ruin east of Emberhold,
ending at the Unlit Throne. Top-down 2.5D in the Airron's Fall look: AF area grounds, kingdom props, the AF ember chest
and flame atlas, torch light (PointLight2D over a CanvasModulate), drifting embers, and AF-themed UI (location card with
HP, gold and the danger meter, Use button, hints, toasts, floor banner, dialog, menu).

## Getting in and out
- In story play, the Sunken Bastion spot on the overworld plays the story's `bastion_enter` dialog, which calls
  `Story.enter_dungeon()`. Now that `scenes/dungeon.tscn` exists, that loads this scene instead of the story's fallback.
- The `EXIT` stairs on floor 1 and "Leave the Bastion" in the menu call `DungeonGate.leave()` → `Story.exit_dungeon()`.
- `DungeonGate.is_open()`: the story's `s_kindling` (mini-boss won) or `s_bastion`. It is always open when there is no Story.
- Preview: `?dungeon=1` (web) or `-- --dungeon=1`; `--dfloor=N` starts on floor N.

## Floors and beats
| Floor | Name | Beats |
|---|---|---|
| 1 | The Drowned Gate | Black water and a bridge, 2 chests, a lever that opens the portcullis, the **Tithe Collector** (guardian) in front of it, and a side door the **Reliquary Key** (`c2_keep`) opens to skip the guardian (story `f1_skip`) |
| 2 | The Reliquary Halls | The **Knellbearer** (guardian) bars the corridor. If you bound the drowned court (`c4_bind`), `f2_bind` clears it with no fight. A Bell Key chest and the locked door before the stairs, plus a gold chest |
| 3 | The Unlit Throne | An ember shrine save point (heals, saves), no random battles in the throne hall, and the black-glass doors: `Story.start_dialog("final_confront")` runs the Regnant, choice 5a, the Sovereign and the ending. If the party lost to the Sovereign, the doors replay `sovereign_intro` |

The **danger meter** fills as you walk and calls `Encounters.start_random_battle("bastion_N")`, with
`QuestFlow.return_scene` set to this scene. `DungeonGate.BATTLES` holds the foe pools and backdrops; levels follow the
party like every wild fight.

## Story contract (docs/STORY.md "Dungeon contract")
- Reads `c2_keep`, `c4_bind`, `bastion_f1`, `bastion_f2`, `boss1_won`, `boss2_won` through `DungeonGate.flag()`
  (`Story.get_flag`). Story sets the guardian and boss flags itself after its fights.
- Saves floor, position, opened doors, chests and keys to `user://dungeon.cfg` before every story fight, so the fight
  comes back to the same spot. The story's win/lose dialog then plays here.
- Pauses movement and the danger meter while `Story.ui_open()`. `Story.hud_wanted` stays off: the dungeon draws its own
  location card.
- Without a Story autoload (tools), the same beats use local flags in `user://dungeon.cfg` and `Bosses.start_boss`.

## Controls
WASD or arrows, tap or click to walk (A* pathing), drag to steer. E, Space, Enter or the Use button to interact; Esc for the menu.

## Tests and captures
- `tools/test_dungeon.gd`: map reachability (gate, door, key, guardian, side door), chests, the lever, the key and door,
  the shrine, the danger meter → Encounters, the story beats with stubbed fights, and the bosses.
- `tools/shot_dungeon.gd -- --out=<dir>`: floor 1, chest, lever before and after, floor 2 locked door, floor 3 save
  point, and the throne doors.
