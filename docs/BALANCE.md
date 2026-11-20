# Airron's Quest — classes, EXP and levels

All numbers live in `scripts/quest_rpg.gd` (classes, EXP table, growth, foe auto-levelling, boss tiers, HP between
fights) and `scripts/quest_flow.gd` (region foe pools and elite chance). `tools/test_progression.gd` checks the math and
the win-rate band; `tools/sim_balance.gd` prints the full balance table and the hours-to-Lv10 estimate.

## Classes and subclasses
- 10 classes: Warrior, Guardian, Knight, Rogue, Monk, Ranger, Mage, Warlock, Cleric, Bard.
- Each class has **2 class abilities** and **2 subclass abilities**.
- A keeper equips **one class** (its full stat package + its 2 class abilities) and **one subclass** picked from the
  same list (35% of that class's stats + its 2 subclass abilities). Class and subclass must differ: 10 x 9 = 90 combos.
- The keeper always brings 4 abilities. The 1st of each pair unlocks at Lv1, the 2nd at Lv3 (class level for class
  abilities, subclass level for subclass abilities).
- The Sequence (AUTO plan) starts from each ability's own default rule and is reset when the class or subclass changes.

## Levels
- Every keeper has a separate level (1-10) for **each class** and a separate level for **each subclass**.
- A keeper's shown level is the level of the class they have equipped. Switching to a new class starts it at Lv1.
- Growth per class level above 1: HP +12, ATK +1.5, DEF +1.2, Armor +0.45, Crit +0.45, Mana +0.3, Speed +0.45, and the
  class's focus stat again (e.g. Warrior ATK +1.8, Guardian HP +12, Monk Speed +1.2).

EXP to reach the next level:

| Lv | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 | total |
|---|---|---|---|---|---|---|---|---|---|---|
| EXP | 285 | 420 | 570 | 750 | 1045 | 1280 | 1660 | 2090 | 2420 | **10,520** |

## EXP per battle
- Each beaten foe pays `TIER_XP x (0.75 + 0.25 x foe level)` with TIER_XP = regular 11, elite 33, miniboss 50, boss 80.
- A win pays for every foe; a loss pays 25% for the foes already beaten; fleeing pays nothing.
- Every keeper in the party gets that total for their **class**; their **subclass** gets half (so a subclass reaches
  Lv10 in roughly twice the time, or as fast if you swap it in as a class). The bench gets nothing.
- Level gap: -15% per level the keeper is above the foes (floor 40%), +10% per level below (cap 130%).

## Auto-levelled foes
Wild fights are levelled to the party (`QuestRPG.foe_level`): **foe level = round(average class level of the party)
± 1**, clamped to 1-10. Regions no longer have level bands; they pick the backdrop, the foe pool (kinds) and the elite
chance, so the walk out of town still changes what you fight:

| Region | Foe pool | Elite chance |
|---|---|---|
| Meadow | ashlings, gnats, moths | 0% |
| King's Road | lancers, ashlings, brutes | 0% |
| Forest | motes, gnats, brutes, moths, chanters | 8% |
| Shore | motes, ashlings, moths | 15% |
| Highlands | lancers, brutes, pilgrims, chanters | 25% |

Each foe stat (`QuestRPG.foe_scale`, applied in `game.gd new_battle` when `encounter.auto`):

    stat = kind's base stat x FOE_BASE[stat] x FOE_TIER[tier][stat] x (1 + FOE_GROWTH[stat] x (level - 1))

| | HP | ATK | DEF | Speed | Mana |
|---|---|---|---|---|---|
| FOE_BASE | 1.8 | 1.6 | 1.0 | 1.0 | 1.0 |
| FOE_GROWTH per level | +7% | +3.5% | +5% | +2% | +3% |
| Tier: regular | x1 | x1 | x1 | x1 | x1 |
| Tier: elite | x1.5 | x1.15 | x1.1 | x1.08 | x1.25 |
| Tier: miniboss | x1.7 | x1.1 | x1.2 | x1.05 | x1.4 |
| Tier: boss | x2.2 | x1.2 | x1.3 | x1.1 | x1.5 |

Elites replace one regular foe and are drawn 15% bigger (miniboss 30%, boss 50%; `FOE_SIZE`).

Wild (region) fights also get `QuestRPG.WILD_FOE` = hp x1.25, atk x1.0 through `encounter.foe_mult`
(`QuestFlow.encounter_for`, multiplied with the story's small-party `foe_mult`). It came in when the untouched Attack
Order became the suggested one (`game.gd auto_plan`, docs/BOSSES.md): that order sparks about 45% of hits instead of
7%, which took AUTO wild fights to 99% and 3.1 h. Story and boss fights do not use it.

### Story fights (hooks for the quest / bosses)
An encounter dictionary (from `QuestFlow.encounter_for(region, level)` or built by hand) can carry:
- `tiers`: per-foe tier, e.g. `["miniboss", "regular"]` or `["boss", "regular"]` (any `QuestRPG.FOE_TIER` key).
- `foe_ids`: per-foe `AfRoster.FOES` id for the art and name (e.g. `["matron", ""]`); empty keeps the region pick.
- `kinds`: one archetype per foe (`torch` melee, `barrel` brute, `tnt` caster); `level`: fixed level instead of party ± 1.
- EXP uses `TIER_XP` for the tier, so a mini-boss pays 50 and a boss 80 before the level factor.

Simulated at the party's own level, AUTO, default party (`sim_balance.gd --tiers=... --levels=3,6,9`):

| Fight | Lv3 | Lv6 | Lv9 |
|---|---|---|---|
| Mini-boss + 1 regular (forest) | 78% | 90% | 80% |
| Final boss + 1 regular (highlands) | 70% | 70% | 63% |

A boss alone is easy (it is one unit against five keepers); a boss with two highlands escorts is very hard (~35%).
Tune with the tier rows above, not by changing the wild-fight numbers.

## Party HP between fights
The kingdom carries the party's HP from fight to fight. A win now recovers 80% of the missing HP (never below 35%;
`QuestRPG.WIN_RECOVER` / `WIN_FLOOR`); a loss leaves 1 HP (rest at the inn). Without this, the next fight started at
~60% HP and the back-to-back win rate fell under 50%.

## The targets: 85-95% AUTO wins, about 4 hours to Lv10
`tools/sim_balance.gd -- --n=60` plays the new-game party (Bramwell, Grieve, Halvard, Corvin, Ilsabet; default classes,
kits, sequences and Attack Order; fresh user data) through AUTO fights at each party level, foes at party level ± 1,
in the region a party of that level walks into. Target select is skipped (AUTO), auto target "Finish Off".

| Party Lv | Region | Win rate | Party HP left | Fight length | EXP per keeper | Fights to next level |
|---|---|---|---|---|---|---|
| 1 | Meadow | 98% | 68% | 31 s | 29 | 9.8 |
| 2 | Road | 98% | 64% | 36 s | 34 | 12.5 |
| 3 | Road | 93% | 66% | 34 s | 35 | 16.5 |
| 4 | Forest | 98% | 73% | 33 s | 45 | 16.6 |
| 5 | Forest | 90% | 59% | 37 s | 52 | 20 |
| 6 | Shore | 88% | 63% | 32 s | 61 | 21 |
| 7 | Shore | 93% | 65% | 34 s | 66 | 25 |
| 8 | Highlands | 98% | 63% | 38 s | 78 | 27 |
| 9 | Highlands | 85% | 58% | 40 s | 83 | 29 |
| 10 | Highlands | 90% | 59% | 39 s | 86 | - |
| **All** | | **92.8% / 91.5%** (two 400-fight runs, seeds 1 and 2, untouched Attack Order = auto plan) | | | | |

Before the auto-plan default and `WILD_FOE` (PR #12, squad order with no delays): 90.2-93.8%, 3.9-4.1 h.

Played back to back like the kingdom (`--chain`: HP carries over, a loss means the inn): **86.2%**.
Elite fights are the risky ones (60-90% by level), by design: they pay 3x EXP.

Time to Lv10: one battle loop = the fight + 25 s (walking until the danger meter fills, transitions, results;
`QuestRPG.LOOP_OVERHEAD_S`) + 2.6 s per party turn when you let the target-select window run out (`SELECT_S`).
That is about **200 fights and 3.85-3.91 hours** of fights and walking (4.3 h back to back with losses), before town,
shop, castle and Build time. Tapping a foe or turning AUTO on skips the 2.6 s window, so active players are faster.

### Re-checking after a change
- `godot --headless --path . -s res://tools/test_progression.gd` (24 fights per level) asserts the 85-95% band
  (83.5-96.5% to allow for sampling noise).
- `godot --headless --path . -s res://tools/sim_balance.gd -- --n=60 [--chain] [--mode=threat] [--tiers=boss,regular]`
  prints the full table and the hours estimate. Combo changes (spark rate, damage) move these numbers: re-run it.
- Every test and the sim start from fresh user data (`tools/test_save.gd`), so results do not depend on the last
  play session or test run on the machine.

### Auto target setting
What the party hits when you do not tap a foe in target select (Emberhold menu > "Auto target";
`scripts/target_select.gd`). Win rate over the same sweep (n=40 per level, one seed): Finish Off 93.8%,
Backline First 92.8%, Biggest Threat 88.2%, Elites First 88.0%. All four stay in the band; Finish Off is the default.
