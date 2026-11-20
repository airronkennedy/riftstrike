# Airron's Quest — classes, EXP and levels

All numbers live in `scripts/quest_rpg.gd` (classes, EXP table, growth) and `scripts/quest_flow.gd` (region levels,
elite chance, foe scaling). `tools/test_progression.gd` checks the math and prints a balance sweep.

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
- Each beaten foe pays `TIER_XP x (0.75 + 0.25 x foe level)` with TIER_XP = regular 10, elite 30, boss 80.
- A win pays for every foe; a loss pays 25% for the foes already beaten; fleeing pays nothing.
- Every keeper in the party gets that total for their **class**; their **subclass** gets half (so a subclass reaches
  Lv10 in roughly twice the time, or as fast if you swap it in as a class). The bench gets nothing.
- Level gap: -15% per level the keeper is above the foes (floor 40%), +10% per level below (cap 130%), so grinding the
  meadow at Lv8 is slow and pushing into higher regions is rewarded.

## Regions (random battles)
| Region | Foe level | Elite chance | Notes |
|---|---|---|---|
| Meadow | 1-3 | 0% | first steps |
| King's Road | 2-4 | 0% | |
| Forest | 3-6 | 8% | |
| Shore | 5-8 | 15% | |
| Highlands | 7-10 | 25% | |

An elite replaces one regular foe: x2 HP, x1.3 ATK, bigger, worth 3x EXP. Foe stats scale with level:
HP x(0.95 + 0.10 per level above 1), ATK x(0.95 + 0.07), DEF x(0.95 + 0.045), keeping pace with class growth.

## The 4-hour target
Simulated AUTO fights at 1x speed, party at level L against foes at level L (`test_progression.gd -- --n=10`):

| Party Lv | Region | Win rate | Battle length | EXP per keeper | Battles to next level |
|---|---|---|---|---|---|
| 1 | Meadow | 100% | 39 s | 27 | 11 |
| 3 | Road | 100% | 46 s | 33 | 17 |
| 5 | Forest | 100% | 49 s | 50 | 21 |
| 7 | Shore | 100% | 35 s | 58 | 29 |
| 9 | Highlands | 100% | 62 s | 84 | 29 |

Summed over all nine level-ups that is about **190 on-level battles** to take one class from Lv1 to Lv10.
A battle loop is about 65-75 s at 1x (danger meter fills after ~4-16 s of walking, a ~45 s fight, transitions and the
results screen), so ~190 battles is about 3.5 hours, plus town, shop, castle and Build time: **about 4 hours**.
Players on 2x/3x battle speed get there faster; the curve, not the speed, is what we tune.

Open questions: on-level fights are still won 100% of the time on AUTO (difficulty can rise later without touching
the EXP curve); bosses are not in random encounters yet (TIER_XP boss is ready for them).
