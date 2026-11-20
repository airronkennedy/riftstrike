# Airron's Quest (Godot 4) — work in progress

An RPG auto battler built on Airron's Fall's art and UI. Five keepers fight raids, elites and bosses on their own,
following the plan you set in **Build**:
- **Class**: change each keeper's class (Warrior, Guardian, Rogue, Ranger, Mage, Cleric). Class sets stats and the ability pool.
- **Loadout**: slot up to 4 abilities from the keeper's signature move, class pool and subclass pool.
- **Sequence**: an ordered list of rules (`ability if condition`). When MP is full, AUTO fires the first rule that passes.
All of it is data in `scripts/quest_rpg.gd` (classes, pools, conditions, default plans) and `scripts/af_roster.gd`
(all 42 keepers, `unlocked: true/false`, and the foe/elite/boss table).

- **Play the web build:** https://airronkennedy.com/quest/
- **Engine:** Godot **4.7.2** (standard build). Renderer: Compatibility.
- Tests: `godot --headless --path . --script res://tools/test_combat.gd` (also `test_auto_mp.gd`, `fuzz_combat.gd`).
  Screenshots: `godot --path . --resolution 960x540 --script res://tools/shot_quest.gd -- --out=/tmp/aq`.

## Open it in Godot
1. Install Godot 4.7.x (standard) from https://godotengine.org/download.
2. Clone this repo: `git clone https://github.com/airronkennedy/riftstrike.git` (repo name kept for now)
3. Open Godot, click **Import**, pick `project.godot` in the cloned folder, then **Import & Edit**.
4. Press **F5** to play. Resize the window tall to see the portrait layout.

All the game code is in `scripts/game.gd` (combat, turns, drawing, UI) and `scripts/sfx.gd` (synth sound effects).
Sprites are in `assets/`.

## Controls
- Tap / click heroes to queue them (cyan outline + order number). Tap again to remove.
- **ALL** queues every living hero, **CLEAR** empties the queue, **EXECUTE** runs the queue one hero at a time.
- Keyboard: `1`-`6` toggle heroes, `A` all, `C` clear, `Space`/`Enter` execute (or start/retry), `P`/`Esc` pause, `M` mute, `S` 1x/2x speed.
- Web URL options: `?focus=1` (everyone targets the first living enemy), `?enemies=1|2|3`, `?auto=1`, `?boss=matron|cardinal|regent|sovereign` (pick the boss).

## Update the phone preview
The preview is a Web export of this project hosted on the `airronkennedy.github.io` Pages repo under `quest/`.
1. In Godot: **Project → Export → Web** (preset already set up: no threads, so it runs on iPhone Safari and GitHub Pages). Export to a folder.
   Command line: `godot --headless --export-release "Web" ../airrons-quest-dist/web/index.html`
2. Copy the exported files (`index.html`, `index.js`, `index.wasm`, `index.pck`, the worklet `.js` files and icons) into `quest/` in the `airronkennedy.github.io` repo, commit, and push. Pages updates in a minute or two.

## Overworld (layout 3)
The Riftmarch is one 448x208 tile map (`data/world_map.txt`) with all 23 areas walkable: Act I at the top left
(hand-tuned, layout 2), the Ember Highlands to the east, Frostveil and its passes to the south east, the Crownlands and
the Rift to the south west. `python3 tools/build_world_acts.py` rebuilds Acts II-V (it never touches Act I),
`python3 tools/check_world.py` checks connectivity and links, and `godot --headless --path . --script res://tools/test_world_full.gd`
checks spawns, props, gates and encounter tables. Web preview helpers: `?warp=frostveil` starts in an area,
`?gates=off` opens every story gate, `?enc=0` turns encounters off.

## Emberhold kingdom (town, castle, Cinderreach overworld)
A separate scene, `scenes/kingdom.tscn`; open it with `?kingdom=1`. It has a town with a shop, an inn, a castle and a house, a small island overworld with six landmarks, and a danger meter that calls
`Encounters.start_random_battle(region_id)` (`scripts/encounters.gd`). See `docs/KINGDOM.md`.

## Later: Windows .exe and iOS
Add a **Windows Desktop** or **iOS** preset in Project → Export (Godot downloads the export templates). iOS needs a Mac with Xcode and an Apple Developer account to sign and upload.

## Assets
Everything is Airron's Fall art (Airron Kennedy's own game). See `docs/ASSET_LICENSES.md`.
Rebuild the art from an Airron's Fall checkout: `python3 tools/build_af_assets.py /path/to/arena-survival-game`.

## Main flow (title -> kingdom -> battle)
Title **New Game / Continue** opens the Emberhold kingdom (`scenes/kingdom.tscn`). When the overworld danger meter fills,
`Encounters.random_battle_requested(region)` is picked up by the `QuestFlow` autoload (`scripts/quest_flow.gd`), which runs
that region's side-view battle (foes and Airron's Fall backdrop per region in `REGION_BATTLES`), writes the party's remaining
HP to `user://kingdom.cfg`, calls `Encounters.finish_random_battle(won)` and returns to the same spot.
Test: `godot --headless --path . --script res://tools/test_quest_flow.gd`.
