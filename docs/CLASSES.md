# Airron's Quest: class change, signatures and auto-cast tactics

Three systems that sit next to each other:
1. **The Star-Reader** (Adeyo, in the Ember Inn) changes a keeper's class or subclass, in the style of Dragon Quest
   IX's Alltrades Abbey. Every class and every subclass keeps its own level and EXP for each keeper.
2. **Signature abilities**: one per keeper, tied to the character, not the class, so looks alone don't decide a build.
3. **Tactics** (Build > Tactics): a Gambit-style auto-cast list set up out of battle, so the party just does it.

## 1. The Star-Reader (class change at the inn)
**Where.** Emberhold's inn is now a room you walk into (`scripts/classes/inn_map.gd`, map id `inn`, "The Ember Inn").
The innkeeper's counter still rests the party (the old inn panel). Adeyo, "The Star-Reader", sits on the rug at the
back. She uses the Airron's Fall art `assets/af/heroes/adeyo.png`.

**When.** She arrives after the first recruit (`got_grieve`): "The stars don't read solos." Before that she only has
a teaser line (`adeyo_early`). Winning Grieve's fight adds the side quest toast *The Star-Reader* (`adeyo_on`), and
Liris has a chatter line pointing to the back room. The first talk (`adeyo_intro`) explains the rules and sets
`met_adeyo`. After that, `adeyo_idle` offers a reading, news about the locked classes (`adeyo_news`), or goodbye.

**Voice.** She's dry, warm and a little theatrical. She treats the sky as a coworker with opinions ("The sky has
opinions about you. Pick a calling, and I'll ask it nicely."). Her lines live in `diviner_ui.gd` `LINES` (one per
step) and in `story_dialog.gd` (`adeyo_*`).

**Flow** (`scripts/classes/diviner_ui.gd`, a CanvasLayer over `main.tscn`, opened through
`QuestFlow.pending_screen = "diviner"`):
1. **Keepers**: one card per keeper with the portrait, class + level, subclass + level and their signature
   ("+" when the current class empowers it).
2. **Callings**: a Class / Subclass toggle, then all 10 classes. Each row shows the keeper's level in that class
   ("Current", "Lv N · resumes", "New · starts Lv N" or "Not yet written" with the unlock hint), the role, a flavor
   line, the two class abilities with their unlock levels, a note when the pick swaps class and subclass, and
   "Empowers X's signature" when it matches the keeper's signature twist.
3. **Confirm**: what will happen (level kept or started, a swap, the signature, the Attack Order) and
   "Begin the divination".
4. **Ritual**: about 2 s. Rings and orbiting runes close in on the portrait, then light pillars, a chime arpeggio
   and a white flash.
5. **Reveal**: "THE STARS HAVE SPOKEN" with the new class, the level (new or resumed), the abilities, the notes, and
   then "Another reading" or "Done". Done saves and walks you back out into the inn.

**Controls.** The screen works by touch or mouse (every control is a button), with a gamepad or keyboard (focus
starts on the first button; `ui_cancel` steps back, and from the first step it leaves), and in portrait. The layout
scales with `min(viewport) / 560` and stacks into one column when the height is greater than the width
(checked at 430x930).

### Levels per class and per subclass
- `CLASS_XP[keeper][class]` and `SUB_XP[keeper][class]` were already separate books. Switching back to a class or
  subclass **resumes** its level and EXP.
- **A brand-new class or subclass starts at half the keeper's best level in that book, rounded up** (minimum Lv1):
  "the stars remember half". For example, a Lv8 Warrior who tries Monk for the first time starts as a Lv4 Monk. This keeps
  experimenting from feeling like a reset, while an old class you've trained stays ahead. (`Diviner.start_level`)
- Picking the keeper's current subclass as the class (or the other way round) **swaps** them. Both books keep their levels.
- The subclass still earns `QuestRPG.SUB_SHARE` (50%) of the battle EXP.
- Build's Class and Subclass tabs still work as before. Open question for Airron: should class changes be limited
  to the inn?

### Unlocks
| Class | Open when |
|---|---|
| Warrior, Guardian, Knight, Rogue, Monk, Ranger, Mage, Cleric | from the start (once Adeyo is met) |
| Warlock | after Kindling Night (`s_kindling`): "the Matron's ash teaches it" |
| Bard | after The Quiet Bell (`sq_bell_done`) **or** returning to Emberhold with the Wardens (`s_return`) |

Outside the story (no story started, tests, quick play), every class is open. Classes are defined in
`Diviner.ADVANCED` (flags are OR'd) and `Diviner.FLAVOR`.

### Attack Order after a change
A class change moves a keeper's speed (frames) and therefore the spark timing.
- With an **untouched Attack Order** (auto plan), nothing needs saving, because the suggested order already adapts
  to the classes.
- With a **hand-set Attack Order**, the order is kept and the delays are re-tuned slot by slot, the same way
  "Suggest order" does it (`Diviner.retune`). The reveal shows the spark rate before → after.

## 2. Signature abilities
Every keeper has one signature, tied to who they are. It doesn't belong to the class, so any class can use it.
Each signature also has **one light twist** that makes it stronger ("Name+"). The twist rewards a fitting class or a
good combo, but doesn't force one.

| Keeper | Signature | Effect (base → empowered) | Default rule | Twist (empowered when…) |
|---|---|---|---|---|
| Bramwell | **Barrow Watch**: the Knight of the Barrow Watch finally gets to stand guard over something that matters | 2.4x hit, party DEF +10 → 3.0x, DEF +16, Armor +6 | on a boss or elite | class Knight or Guardian |
| Grieve | **Second Burial**: the Twice-Buried puts a foe in the ground | 3.0x hit, foe DEF −8 → 3.8x, DEF −12 | a foe < 30% HP | finisher: he acts from the last live Attack Order slot (2+ keepers alive) |
| Halvard | **Anvil Oath**: the last Rust Baron swears on his anvil | 1.25x to all foes, self DEF +14 → 1.6x, DEF +20, Armor +8 | 2+ foes left | class Guardian or Warrior |
| Corvin | **Called Shot**: the Low Orbit duelist calls his hit | 2.5x hit, self Crit +8 → 3.4x, Crit +14 | on a boss or elite | combo: the last party turn sparked 3+ |
| Ilsabet | **Tidal Decree**: the Drowned Queen's royal command | heal party 17%, party ATK +6 → 24%, ATK +10 | an ally < 75% HP | class Cleric or Bard |

- Signatures wake at **Lv3** (`Signatures.SIG_LEVEL`), spend the full Brave gauge like any ability, and fire **at
  most once per battle**.
- They show in the Star-Reader screens, on the Party screen ("Sig: Name+"), in Build's summary ("SIGNATURE" or
  "SIG+") and in Tactics (a gold row).
- Data: `scripts/classes/signatures.gd` `ROWS`. `register()` adds `id` and `id_x` (the empowered form) to
  `ABILITY_DEFS` with `src: "sig"` and `owner`. Heroes not in `ROWS` fall back to their Airron's Fall weapon
  signature (`SIG_AB`).

## 3. Tactics: auto-cast set up out of battle
Build > **Tactics** (the old "Sequence" tab). Each keeper has up to 6 rules, checked top to bottom whenever their
Brave gauge is full. The first rule whose ability is unlocked and switched on, and whose condition passes, fires.
If no rule passes, the keeper makes a normal attack and keeps the gauge. Combat stays AUTO.

Each row is: **ability** (tap to cycle through the signature, the keeper's loadout and *Save Brave Burst*), **AUTO / OFF**,
**if** and a **condition** (tap to cycle), plus up / down / X. On narrow screens each rule takes two lines.

| Condition id | Label |
|---|---|
| `always` | always |
| `turn_1` | at battle start |
| `boss` | on a boss or elite |
| `no_boss` | no boss or elite here |
| `ally_hurt` / `ally_low` / `ally_40` | an ally < 75% / 50% / 40% HP |
| `self_low` | self < 50% HP |
| `foes_2` / `foes_3` | 2+ / 3+ foes left |
| `foe_low` | a foe < 30% HP |
| `combo_3` | last turn sparked 3+ |

- **Save Brave Burst** (`hold`): while its condition passes, the keeper attacks normally and keeps the full gauge.
  For example, `hold if no boss or elite here` saves bursts for the boss.
- **OFF**: the ability stays in the list but never auto-casts (`AB_OFF`).
- **Defaults**: the signature rule comes first with its own condition, then the class abilities with their default
  conditions. The signature row can be switched OFF but not removed. "Reset to default" restores everything and
  turns everything back on.
- **Save format** (`user://kingdom.cfg`): `rpg/ab_seq` (as before), section `ab_off` (one key per keeper) and
  `rs/sig_seen`. An older save gets the signature rule added at the top **once** (`Tactics.migrate`). If you remove
  it later, it stays removed.
- **Extending it**: add a condition with a label in `Tactics.CONDITIONS`, its place in `COND_ORDER` and a branch in
  `Tactics.check` (plus `handles`). New special actions work like `HOLD`, handled in `Tactics.pick`.

## Balance
See docs/BALANCE.md, "Signatures and tactics". Overall AUTO wins went from about 90% to about 93% (inside the 85-95%
band), and the time to Lv10 went from about 3.9 h to about 3.75 h. The boss numbers stay inside their targets.

## Files and hooks
- New: `scripts/classes/diviner.gd` (rules, unlocks, levels, retune), `diviner_ui.gd` (screens and ritual),
  `signatures.gd`, `tactics.gd`, `inn_map.gd`. Tests: `tools/test_classes.gd`. Screenshots: `tools/shot_classes.gd`.
- `scripts/game.gd`: `Signatures.register` in `build_rpg`; `default_seq`, `seq_of`, `seq_condition_ok` and `seq_pick`
  delegate to Tactics; `AB_OFF` / `SIG_SEEN` saved and loaded; `open_diviner()` plus the `pending_screen ==
  "diviner"` branch in `_ready`; an `_input` guard while the diviner is open; the "Sig:" line on the Party screen.
- `scripts/build_ui.gd`: Tactics tab and signature cards. `kingdom_maps.gd`: the inn spot warps into `inn`.
  `kingdom.gd`: `indoor` maps count as interiors.
- Story: the `adeyo` cast and inn NPC, `adeyo_*` dialogs, the `divine` action, `a|b` conditions, the `{party}` text
  placeholder.

Screenshots: `xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot_classes.gd -- --beat=<inn|intro|heroes|list|sub|confirm|ritual|reveal|tactics|build|party> --out=/tmp/x.png`
(use `--resolution 430x930` for portrait).
