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
  and fill the Break gauge. When Broken, the boss takes +10% and its next turn is a single weak act (no signature).
  Later phases tighten the spark window.
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
`foe_ids`; EXP 50 and 80). `BossDefs.TUNE[id]` is an extra hp/atk/def multiplier for the boss mechanics.
`tools/sim_bosses.gd` fights each boss at its story level using the story's own encounter (`Story.encounter_for`), with a
random order, the default party order and the suggested order (`Combo.best_plan`):

```
godot --headless --path . -s res://tools/sim_bosses.gd -- --n=40 --modes=random,default,smart [--boss=id] [--levels=9,10]
```

Results on 2026-11-20 (full HP at the start of each fight):

| Boss | Lv | Random order | Suggested order |
|---|---|---|---|
| Matron | 7 / 8 | 28% / 23% | 75% / 78% |
| Tithe Collector | 8 / 9 | 38% / 30% | 90% / 95% |
| Knellbearer | 9 / 10 | 33% / 20% | 80% / 80% |
| Unlit Regnant | 9 / 10 | 23% / 30% | 98% / 80% |
| Ash Sovereign | 10 | 8% | 72% |

In the story, the Sovereign follows the Regnant with the HP the party has left (and -25% if Taren is pulled out), so
the real phase 2 is harder than the table. Losing is retryable (the lose dialog heals the party). A bad Attack Order
does much worse than "a little lower": ward, Break and the rift surge (+35% damage per turn after turn 3, balance
worker) all reward sparks. Narrowing that gap means softening the surge, which the balance worker owns.

## Tests and captures
- `tools/test_dungeon.gd`: boss data, the story beats in the dungeon, story boss presentation, wins/sparks per order,
  and `Bosses.boss_defeated`.
- `tools/shot_boss.gd -- --boss=<id> --out=<dir>`: intro, signature, phase change, finishing blow and victory frames.
