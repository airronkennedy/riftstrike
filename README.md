# RIFTSTRIKE (Godot 4)

Turn-based 6vN rift brawl: Airron's six-hero squad against a 6v3 goblin raid, 6v2 elites, or a 6v1 boss.
This is the Godot version of the canvas web game at https://airronkennedy.com/riftstrike/, rebuilt to play the same way:
tap heroes in attack order, Execute, combos on shared targets, specials, Rift Surge, and the enemy turn.

- **Play the phone preview:** https://airronkennedy.com/riftstrike-godot/
- **Engine:** Godot **4.7.2** (standard build, not .NET). Renderer: Compatibility (WebGL 2 / OpenGL).

## Open it in Godot
1. Install Godot 4.7.x (standard) from https://godotengine.org/download.
2. Clone this repo: `git clone https://github.com/airronkennedy/riftstrike.git`
3. Open Godot, click **Import**, pick `project.godot` in the cloned folder, then **Import & Edit**.
4. Press **F5** to play. Resize the window tall to see the portrait layout.

All the game code is in `scripts/game.gd` (combat, turns, drawing, UI) and `scripts/sfx.gd` (synth sound effects).
Sprites are in `assets/`.

## Controls
- Tap / click heroes to queue them (cyan outline + order number). Tap again to remove.
- **ALL** queues every living hero, **CLEAR** empties the queue, **EXECUTE** runs the queue one hero at a time.
- Keyboard: `1`-`6` toggle heroes, `A` all, `C` clear, `Space`/`Enter` execute (or start/retry), `P`/`Esc` pause, `M` mute, `S` 1x/2x speed.
- Web URL options: `?focus=1` (everyone targets the first living enemy), `?enemies=1|2|3`, `?auto=1`, `?boss=goblin` (Tiny Swords boss instead of the Necromancer).

## Update the phone preview
The preview is a Web export of this project hosted on the `airronkennedy.github.io` Pages repo under `riftstrike-godot/`.
1. In Godot: **Project → Export → Web** (preset already set up: no threads, so it runs on iPhone Safari and GitHub Pages). Export to a folder.
   Command line: `godot --headless --export-release "Web" ../riftstrike-godot-dist/web/index.html`
2. Copy the exported files (`index.html`, `index.js`, `index.wasm`, `index.pck`, the worklet `.js` files and icons) into `riftstrike-godot/` in the `airronkennedy.github.io` repo, commit, and push. Pages updates in a minute or two.

## Later: Windows .exe and iOS
Add a **Windows Desktop** or **iOS** preset in Project → Export (Godot downloads the export templates). iOS needs a Mac with Xcode and an Apple Developer account to sign and upload.

## Credits
- Art: [Tiny Swords by Pixel Frog](https://pixelfrog-assets.itch.io/tiny-swords) (CC0). Only the sprites the game uses are included.
- 6v1 boss: [Necromancer by CreativeKind](https://creativekind.itch.io/necromancer-free) (free pack, credit CreativeKind).
- Font: Lilita One by Juan Montoreano (SIL Open Font License, see `fonts/OFL-LilitaOne.txt`).
- Sounds are synthesized in code; no audio files.
