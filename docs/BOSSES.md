# Boss battles

Boss fights run on the normal side-view auto battle (`scripts/game.gd`), the combo system (`scripts/combo_turn.gd`)
and the battle camera. `scripts/boss/` adds the boss layer on top. Story fights get it automatically.

| Id (= story fight id) | Boss | Tag | Where | Phases | Signatures |
|---|---|---|---|---|---|
| `miniboss_matron` | Matron of Cinders, Mother of the Grey Brood | MINI-BOSS | Emberhold plaza (Kindling Night) | Lullaby, Cross Mother (50%) | Cinder Lullaby (all), Smother (one keeper) |
| `guardian_f1` | Tithe Collector, Guardian of the Drowned Gate | GUARDIAN | Bastion floor 1 | Ledger Open | Final Tally (last in the Attack Order) |
| `guardian_f2` | Knellbearer, Guardian of the Reliquary Halls | GUARDIAN | Bastion floor 2 | First Bell | Death Knell (all) |
| `boss_regnant` | The Unlit Regnant, Patron of the Black Glass Throne | FINAL BOSS I | The Unlit Throne | Cold Court, Snuffed Crown (50%) | Candle Toll (all), Wick Rend (one) |
| `boss_sovereign` | The Ash Sovereign, The Thing Beneath the Throne | FINAL BOSS II | The Unlit Throne | Grey Crown, Nine Kings' Ash (66%), Every Fire Gone Out (33%) | Ash Comet (all), Sovereign's Brand (last in order), Last Light (all) |

Names, roles and voices follow `docs/STORY.md`. The long pre-fight and post-fight scenes are the story's dialogs
(`scripts/story/story_dialog.gd`). The boss layer adds short in-battle lines: an intro, one per phase, and a victory or
defeat line (`BossDefs.LINES`, overridable with `BossDefs.set_lines(id, {...})`).

## What a boss fight adds
- **Intro cut-in**: letterbox, a colored band with portrait, tag, name and title, and the typed intro line. Tap to skip.
- **Big HP bar** at the top: portrait, name, tag, phase name, phase ticks and the Break gauge.
- **Phases** at HP thresholds. Each phase has its own hit frames (timing data like `Combo.FOE_FRAMES`), acts per turn
  and spark window. A "PHASE N" plate and line play on entry.
- **Signature attacks with telegraphs**: a red warning strip with the name and a hint, target rings and "!" over the
  keepers about to be hit, then the attack after `telegraph` ms.
- **Ward and Break (why the Attack Order matters)**: unsparked hits deal only `ward`× damage; sparked hits ignore it
  and fill the Break gauge (`break_need` × `TUNE.break`). When Broken, the boss takes +15% and staggers its next turn
  (x0.85 damage; a signature due that turn waits one turn). It keeps its acts and signature cadence. Later phases
  tighten the spark window.
- **Sparks count for less in boss fights**: `BossDefs.TUNE[id].spark` scales the spark damage bonus and the BB a spark
  gives, on every foe in the fight (1 = Combo's +50%, 0.25 = +12.5%). The Attack Order still matters, but it no longer
  decides the fight.
- **Enrage, not the rift surge**: boss fights have no rift surge (+35% per turn for both sides after turn 3; it stays
  in regular fights). Instead the boss ENRAGES late: from `QuestRPG.BOSS_ENRAGE.turn` (18; the Sovereign's
  `enrage_turn` is 24) its side deals +25% per turn, capped at x3. A banner warns one turn early ("The boss is about to
  ENRAGE!"), and the HUD shows "ENRAGE x1.25" in red. Most fights end before it (14-17 turns with a good order).
- **Finishing blow**: slow motion, flash and rings, "FINISHING BLOW · X ENDS <BOSS>", escorts fall, then the victory line.
- Minibosses and bosses, like elites, get +1 hit per attack in `combo_turn.gd` (the boss itself uses its phase frames).

## Interface
```gdscript
Bosses.start_boss("miniboss_matron")   # Story present: Story.start_battle(id) (flags, dialogs, return to the scene)
                                       # no Story: standalone fight, returns to return_to / the calling scene
Bosses.boss_defeated.connect(func(id): ...)   # every win (relays Story.boss_defeated in story play)
Bosses.boss_failed.connect(func(id): ...)
Bosses.is_defeated(id)                 # user://bosses.cfg
BossDefs.id_for(encounter)             # boss id of an encounter: encounter.boss (String) or encounter.story_id
```
`game.gd` hooks: `start_kingdom_battle` creates a `BossFight` when `BossDefs.id_for(encounter)` is not empty, and
`start_boss_battle(id)` does it for standalone fights. Story fights still return through QuestFlow and Story; only
standalone fights return through `Bosses.finish`.

Preview: `?bossfight=boss_sovereign` (web) or `-- --bossfight=boss_sovereign` (desktop) starts a standalone fight.

## Stats and balance
The balance worker's tiers apply first (`QuestRPG.FOE_TIER` miniboss/boss/elite through `encounter.tiers` and
`foe_ids`; EXP 50 and 80). `BossDefs.TUNE[id]` is then applied to the boss: `hp`, `atk`, `def`, plus `break` (x
`break_need`) and `spark` (spark bonus in the fight, see above):

| Boss | hp | atk | break | spark | other |
|---|---|---|---|---|---|
| Matron | 1.06 | 0.89 | 1.5 | 0.25 | |
| Tithe Collector | 0.58 | 1.35 | 1.5 | 0.2 | Final Tally 4 hits x0.8 (was 5 x1.9) |
| Knellbearer | 0.72 | 0.95 | 1.5 | 0.25 | |
| Unlit Regnant | 0.65 | 0.99 | 1.5 | 0.25 | |
| Ash Sovereign | 0.77 | 0.88 | 1.5 | 0.1 | enrage_turn 24 |

**The untouched Attack Order is the suggested one.** While the Build has no custom order or delays
(`HERO_ORDER`/`HERO_DELAY` empty), `game.gd auto_plan()` runs `Combo.best_plan` for the party's class frames and the
fight uses that order and those delays. Changing the order or a delay freezes the auto plan and edits it.

`tools/sim_bosses.gd` fights each boss at its story level using the story's own encounter (`Story.encounter_for`).
Orders: `random` (shuffled, no delays), `shuffled` (shuffled, keeps the auto delays, what you get by dragging the order
around), `party` (squad order, no delays), `default` (untouched Build = auto plan) and `smart` (`Combo.best_plan`).
`--carry` starts the Sovereign with the HP the story gives it after a Regnant win of the same order
(`QuestRPG.hp_after_battle`, then `Story.phase2_hp`: the Lantern heals to full, -5% if you spare Taren).
`--tune=hp,atk[,break[,spark]]` and `--enrage=turn,step,max` scale or replace the numbers while tuning.
`tools/sim_story.gd` now adds the BossFight layer to boss fights too (it used to fight them as plain encounters).

```
godot --headless --path . -s res://tools/sim_bosses.gd -- --n=40 --modes=random,shuffled,party,default,smart --carry
```

Before (2026-11-20, main before this pass: rift surge in boss fights, old Break, `default` = squad order, n=40):

| Boss | Lv | Random | Squad order (old default) | Suggested |
|---|---|---|---|---|
| Matron | 7 / 8 | 15% / 23% | 3% / 0% | 80% / 75% |
| Tithe Collector | 8 / 9 | 35% / 40% | 25% / 8% | 93% / 90% |
| Knellbearer | 9 / 10 | 23% / 25% | 10% / 23% | 70% / 88% |
| Unlit Regnant | 9 / 10 | 18% / 13% | 0% / 0% | 85% / 68% |
| Ash Sovereign | 10 | 8% | 0% | 90% (full HP) |

After (n=40-100 per cell, several seeds; noise about ±8 points at n=40):

| Boss | Lv | Random | Shuffled | Squad order | Default (untouched) | Suggested |
|---|---|---|---|---|---|---|
| Matron (target 70-80) | 7 | 74-80% | 68-77% | 59-75% | 75-77% | 82-85% |
| Tithe Collector (75-90) | 8 | 50-59% | 53-58% | 38-45% | 75-83% | 69-80% |
| Knellbearer (75-90) | 9 | 65-85% | 73-80% | 69-85% | 75-90% | 80-90% |
| Unlit Regnant (75-85) | 9 | 58-64% | 65-75% | 50-64% | 77-87% | 76-88% |
| Ash Sovereign (60-70) | 10 | 30-38% | 20-38% | ~10% | 65-68% | 73-75% |

Story sim (`sim_story.gd`, default order, the story party, n=40-60): Matron 80-87%, Tithe Collector 78-80%,
Knellbearer 85-90%, Regnant 80-93%, Sovereign alone 63-73%; final chain (Regnant, Lantern heal, Sovereign): phase 2
after a phase-1 win 57-84%, both in one go 47-80%.

A new player who never opens the Attack Order tab gets the suggested order, so they sit at the suggested numbers
(Matron in a try or two). A scrambled order is now 0-25 points lower for the Matron, Knellbearer and Regnant.
Two fights still punish it harder, by design and by noted limit:
- **Tithe Collector** (~25 lower): Final Tally hits the last keeper in the order, so a squishy keeper at the back
  is the lesson of the fight. Softened from 5 x1.9 to 4 x0.8 hits.
- **Ash Sovereign** (~30-40 lower): three phases, ~18-21 turns, and phase spark windows of 52/45 ms. Even with the
  spark bonus at 0.1 a slow order pays for every extra turn. Closing it further would mean flattening the phases.

What drove the old 60-point gap: the rift surge (+35% per turn for both sides) turned every boss fight into a race,
and a Break used to cut the boss to one weak act and skip its signature, so the order that sparked more also took far
less damage. With Break disabled the gap was already down to ~20 points.

## Tests and captures
- `tools/test_dungeon.gd`: boss data, the story beats in the dungeon, story boss presentation, wins/sparks per order,
  and `Bosses.boss_defeated`.
- `tools/shot_boss.gd -- --boss=<id> --out=<dir>`: intro, signature, phase change, finishing blow and victory frames.
