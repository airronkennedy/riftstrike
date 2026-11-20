# Emberhold kingdom, castle and the Cinderreach overworld

This is a self-contained scene, `scenes/kingdom.tscn`. It doesn't touch `scripts/game.gd`, the battle code or `scripts/quest_rpg.gd`.

## Open it
- **Web preview:** add `?kingdom=1` to the URL. `?kingdom=1&calm=1` also turns on reduced motion, and `&kmap=overworld` (or `castle` / `house`) starts on another map.
- **Desktop:** `godot --path . -- --kingdom=1`, or open `scenes/kingdom.tscn` in the editor and press F6.
- **From the title menu (not wired yet):** `get_tree().change_scene_to_file("res://scenes/kingdom.tscn")`. The kingdom's own menu has a **Back to title** button.

## Controls
- **Phone / tablet (real multitouch, `scripts/kingdom/kingdom_touch.gd`):** touch anywhere on the field and an Airron's Fall floating joystick appears under your finger (118 px base, knob clamped to 31%, 10% dead zone, analog speed, fades out on release). Keep holding it and press **Use** with another finger. Use is a round button (bottom right) that pops in and pulses only when something is in reach, with an icon for Enter / Shop / Rest / Talk / Look / Pray. A floating prompt card over the target names it. A quick tap on a person, door or sign walks there and uses it. Tapping the minimap opens the map screen. Mouse emulation is off on the field and only turned on while a menu, shop or dialog is open.
- **Keyboard and mouse:** WASD or arrow keys to move, or click to move. E, Space or Enter uses the nearest thing, M opens the map screen and Esc opens the menu.
- **Gamepad:** left stick (analog) or d-pad to move, A to use or advance dialog, B to close or open the menu, Start for the menu, Back/Select for the map. Menus open with the first button focused.
- **Safe areas / iOS Safari:** the web head include (`export_presets.cfg`) sets `viewport-fit=cover`, turns off zoom, pinch, double-tap zoom, long-press callouts and scrolling, and exposes `env(safe-area-inset-*)` as CSS vars that the HUD reads, so nothing sits under the notch or home indicator.
- **Graphics:** High / Phone (light) / Low in the menu. Phone uses a 5-tap blur, 70% tilt-shift and about half the bloom and rays. It is the default on touch devices and small screens (`?gfx=high|phone|low` overrides it).

## Places
- **Emberhold town** (`KingdomMaps.TOWN`):
  - General Store: buys and sells the main game's `ITEM_DEFS` and writes to the shared `[inv] bag` in `user://airrons_quest.cfg`.
  - Castle Gate: leads into the castle.
  - Town exit: the south road, to the overworld.
  - The Ember Inn: 10 gold. Restores party HP and saves.
  - Bramwell's House: a placeholder interior.
  - Six buildings for dressing, a central fire, and two townsfolk who talk.
- **Castle Emberhold:** a throne room with pillars, braziers, the throne and the king; the Great Hall; the Hall of Keepers (keeper statues); and the Gallery of Banners. Each hall's name fades in as you enter it.
- **Cinderreach** (overworld, generated in `KingdomMaps.overworld_rows()`): a small island ringed by sea. Marked spots: Emberhold, Sunken Bastion (ruin), Gloamwood Heart (forest), Coalvein Cave (cave entrance), Votive Shrine and Cliff Overlook. For now each spot shows flavor text. Praying at the shrine empties the danger meter.

## Random encounters (overworld only)
- The danger meter (top-left card) fills by distance walked: `meter += px / (64 * REGIONS[region].tiles)`. Tiles walked to fill it, per region: forest 15, highlands 19, meadow 26, shore 34, King's Road 60.
- It never fills in town, the castle or the house.
- When it fills, it resets to 0, the game saves (map and position), and `Encounters.start_random_battle(region_id)` is called.
- **The hook:** `scripts/encounters.gd`, autoloaded as `Encounters`. `start_random_battle(region_id)` emits `random_battle_requested(region_id)`. `region_id` is `meadow` / `forest` / `highlands` / `shore` / `road`.
- **Connecting it:**
  ```gdscript
  Encounters.random_battle_requested.connect(func(region_id): start_battle_for(region_id))
  # when the fight ends:
  Encounters.finish_random_battle(won)
  ```
  With a listener connected, the overworld freezes until `finish_random_battle()`. With none, it shows a toast and carries on.
  If the battle swaps scenes, change back to `res://scenes/kingdom.tscn` afterwards. It reloads `user://kingdom.cfg` and resumes at the same spot.
- `Encounters.enabled = false` turns random battles off.

## Look (Airron's Fall UI and finish)
- **Look update:** the shader ground, post pass (tilt-shift, bloom, god rays, grading), wind sway, parallax occluders and ambient life are described in `docs/art-direction-kingdom.md`.
- **Shared theme:** `scripts/ui/af_theme.gd` (`AfTheme.get_theme()`) holds the Airron's Fall palette, the Cinzel / Rajdhani / Cormorant fonts and the carved `ui_panel_9` frame. It is also saved as `themes/airrons_fall.tres`; regenerate it with `godot --headless --path . --script res://tools/build_af_theme.gd`.
  - Type variations: `HeaderLabel`, `MutedLabel`, `FlavorLabel`, `PrimaryButton`, `FramedPanel`, `ToastPanel`, `DangerBar`.
  - Helpers: `AfTheme.pop_in` / `pop_out` (tweened panels) and `add_press_juice` (button press scale).
- **Camera:** smoothed Camera2D with a gentle look-ahead.
- **Light:** a CanvasModulate tint per map, a warm torch PointLight2D on the hero, flickering brazier and fire lights, and a vignette in the post pass (`shaders/kingdom_post.gdshader`).
- **Other effects:**
  - soft contact shadows under every character and prop
  - ambient CPUParticles2D per map: embers in town, dust indoors, motes outdoors
  - a minimap
  - area names that fade in
  - an iris transition between maps (`shaders/iris.gdshader`)
- **Reduced motion** (menu toggle, `?calm=1`; saved): no particles, no camera smoothing or look-ahead, no flicker or bobbing, a plain fade instead of the iris, and fade-only panels.

## Art
- **New kingdom art** in `assets/kingdom/`:
  - 53 sprites cut from four Grok-generated sheets: trees, landmarks, buildings, clutter and castle pieces
  - 10 procedural ground textures
  - every file is listed in `docs/ASSET_LICENSES.md`
- **Airron's Fall art still used:** heroes, the flame and chest, the UI frame and fonts.
- **Raw sheets** are in `art-src/kingdom/raw/` (Godot-ignored, not shipped). Rebuild with:
  ```
  python3 tools/art/kingdom_cut.py
  python3 tools/art/kingdom_tiles.py
  /path/to/venv/bin/python tools/art/c2pa_attach.py RAW SPRITE
  ```
- **Rendering techniques** are covered in `docs/art-direction-kingdom.md`.

## Tests
- `godot --headless --path . --script res://tools/test_kingdom.gd` checks:
  - every map is rectangular
  - each start, spot, NPC and exit is reachable with the real collision
  - no battles in town
  - the overworld fires the hook with a valid region and resets the meter
  - shop buy and sell
  - the inn heals, charges and saves
- Screenshot: `xvfb-run godot --path . --resolution 390x844 --script res://tools/shot_kingdom.gd -- --map=overworld --x=22 --y=17 --touch=1 --out=/tmp/k.png`
