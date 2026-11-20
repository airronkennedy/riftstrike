# Combo system: hit frames, Sparks and Attack Order

Airron's Quest is always an auto battler. Each party turn, everyone attacks in a set **Attack Order**. Every attack
lands several hits. A hit's timing comes from its ability data plus a little random jitter. Hits from two
**different** keepers that land on the same foe close together **Spark**. It is modelled on Brave Frontier's Spark
mechanic. In Brave Frontier, hits on the same frame spark for 150% damage, and players learn each unit's hit frames
and when to tap them.

Code:
- `scripts/combo.gd`: timing data, tuning constants, the spark math, and the Build preview/suggest helpers.
- `scripts/combo_turn.gd`: runs a team turn. It moves units, schedules and resolves hits, resolves sparks, and drives the feedback.
- `scripts/game.gd`: `bf_select`, `bf_launch`, `bf_enemy_turn`, `bf_controller` (turn flow) and `attack_order` / `set_hero_delay`.
- `scripts/build_ui.gd`: `_draw_order` (Build › Attack Order).
- `scripts/battle_hud.gd`: target-select prompt, combo counter, and turn summary.

## Turn flow
1. **Target select** (`SELECT_MS` = 2.6 s). Tap an enemy to focus the whole party; the attack starts right away.
   Otherwise, tap GO or wait. With no focus, the party agrees on the foe closest to dying, so their hits can spark.
   Desktop: arrows pick the target, Enter attacks. The AUTO button (auto-continue) skips this step.
2. **Party strike**. Keepers start `SLOT_STAGGER` (540 ms) apart in Attack Order, plus any delay set per keeper in
   Build (0–500 ms in 50 ms steps). A keeper with a full **BB gauge** fires a Brave Burst from its Build Sequence
   plan.
3. **Summary**: COMBO n HITS · sparks (rate) · damage.
4. **Enemy turn**: the same system. Enemies attack in a shuffled order and can spark each other on the same hero.

## Timing data (per class, normal attack) — `Combo.FRAMES`
| Class | style | windup ms | hits | interval ms | travel ms | Build tag |
|---|---|---|---|---|---|---|
| Warrior | melee | 260 | 4 | 95 | – | Steady |
| Guardian | melee | 340 | 3 | 140 | – | Steady |
| Knight | melee | 300 | 4 | 110 | – | Steady |
| Rogue | melee | 120 | 7 | 55 | – | Fast |
| Monk | melee | 160 | 8 | 60 | – | Fast |
| Ranger | ranged | 240 | 5 | 85 | 260 | Slow |
| Mage | cast | 520 | 4 | 120 | 220 | Slow |
| Warlock | cast | 440 | 5 | 100 | 240 | Slow |
| Cleric | cast | 380 | 3 | 150 | 200 | Slow |
| Bard | ranged | 300 | 6 | 75 | 230 | Slow |

- **Onset** (time to the first hit): melee is dash (distance ÷ 1500 px/s; the real average is about 180 px, so
  about 120 ms) + windup. Ranged and cast are a 120 ms step-in + windup + travel. Speed tag: Fast < 350 ms,
  Steady < 600 ms, Slow otherwise.
- **Span** = interval × (hits − 1).
- **Brave Burst**: hits × 2 + 2, the same windup (so a plan still holds), interval × 0.8, and damage = the ability's `mult`. An ability row can
  override this with `params.hits`. Support BBs (heals and buffs) land their effect at the end of the windup and
  have no hits.
- Foes: melee 2 hits / 130 ms, ranged 2 hits plus travel. Elites get +1 hit. A full foe gauge fires a special:
  2× + 1 hits at 2.2× damage.
- Damage: an attack deals `ATK × mult`, split evenly over its hits. Defense is applied per hit, armor is split per
  hit, and crits (1.5×) roll per hit.

## Jitter (no two turns play out the same)
Rolled per strike: dash ±8%, windup ±15%, travel ±10%, and each gap between hits ±14%. Melee dash distance also
changes with where the foe stands.

## Spark rule
A hit **sparks** when a hit from a different unit on the same target lands within **±60 ms** (`SPARK_WINDOW`). This
counts hits already landed and hits scheduled to land soon, so both hits of a pair spark. An all-enemy attack can
spark on every foe it hits.
- Damage × **1.5** (`SPARK_MULT`).
- BB gauge: +1.6 per hit landed, +2.6 more per sparked hit, +0.9 per hit taken.

The window is tight enough that a random order catches only some overlaps. Hit windows are wide (many hits) and
predictable (data and preview), so a good order lines them up reliably.

## Why order is the skill
Slot *i* starts at *i* × 540 ms. Slow-onset keepers (casters, rangers) put first land their hits around the same time
as fast keepers (rogues, monks) put second or third. Fast keepers first and slow ones last hit in separate bursts,
and nothing sparks.

Measured with `tools/test_combo.gd`:
| | timing math (40 random 5-keeper parties) | real AUTO battles (default party, forest Lv3) |
|---|---|---|
| random order | ~34% of hits spark | ~22% |
| suggested order + delays | ~74% | ~62% |

Real battles spark a little less than the math, because foes die mid-turn and hits split across new targets.

## Build › Attack Order
- One row per keeper in attack order.
  - Each row shows its timing traits: "7 hits · 0.33 s · Fast" (green Fast, gold Steady, rust Slow).
  - Controls: ▲/▼ to move a keeper, and −/+ delay.
  - Tap one row, then another, to swap them.
- Timeline: for each keeper, a dot (start), a thin line (dash / windup), a solid bar (nominal hit window, with
  white ticks for the hits), a faint bar (jitter range), and green bands where two keepers' windows overlap (likely
  sparks).
- **Expected sparks %**: a Monte Carlo of 80 rolled turns, using the same `roll_hits` as battle.
- **Suggest order**: tries every order (party ≤ 5, so 120 options), then tunes each slot's delay. **Reset delays**
  sets all delays back to 0.
- Saved in `user://airrons_quest.cfg`: `[combo] order` and `[combo_delay]`.

## Feel / feedback
- Movement: melee dashes in with afterimages (`Unit.trail`), a hop, and stretch. Anticipation pulls back and
  squashes. Each hit is a forward jab. Then the unit runs home. Ranged and cast units step in. Their arrows and
  bolts are timed to arrive exactly on the hit frame; cast bolts fall from above.
- Every hit:
  - a slash swipe (melee) and impact star;
  - target flash, shake and knockback;
  - a small zig-zag damage number;
  - a running **chained total** above the foe that re-pops on each hit.
- Every spark:
  - green-gold numbers;
  - one **SPARK!** callout per foe that re-pops, so the callouts don't stack;
  - shard particles (`burst` fx) and a ring;
  - screen shake and a 2–3% camera punch (`cam_punch`);
  - 28 ms hit-stop, throttled to one every 110 ms;
  - a chime whose pitch rises with the turn's spark count.
- KO: 80 ms hit-stop, a bigger punch and a KO! popup.
- Brave Burst: a full-width cut-in strip with the ability name sliding across, a screen flash, the caster flashing
  during windup, and an aura.
- HUD: a big **HITS** counter (white → gold at 10 → ember at 20 → green at 30) that pops on every hit, a SPARKS
  count, and an end-of-turn summary plate.
- Sound hooks use the existing AF `sfx` (hit, shoot, special, ko, tone).

## Tuning knobs (`scripts/combo.gd`)
`SPARK_WINDOW`, `SPARK_MULT`, `SLOT_STAGGER`, `DELAY_STEP`, `DELAY_MAX`, `JIT_*`, `DASH_SPEED`, `RECOVER`,
`BB_PER_*`, `BB_*_MULT`, and the `FRAMES` table. After any change, run `tools/test_combo.gd`. It checks the
random-order band (18–38%) and the smart band (58–85%), and that the smart order clearly beats random in real
battles.

## Tools
- `tools/test_combo.gd` (headless): timing math, real battles (random vs suggested order), and turn flow.
- `tools/shot_combo.gd` (needs a display, e.g. `xvfb-run`): target select, focus, and a 30 fps fixed-step frame
  sequence of a whole party turn (`frames/`). It saves the best spark frame and the Build Attack Order tab before
  and after Suggest.

## Battle camera and on-screen personality
Code: `game.gd` `battle_cam_update`, `cam_focus`, `_fit_formation` and `screen_to_world`.
- **Framing:** the camera fits the fighters' home spots into the screen area between the top prompt and the party
  cards. Fighters render at up to 2.3× scale, so they read large and close.
- **Push-in:** during a strike the camera eases toward the attacker, then to the attacker/target midpoint once the
  hits begin. Zoom is ×1.12, or ×1.22 for a Brave Burst. It adds about +5% for 160 ms after each spark, plus the
  spark/KO camera punch. When the turn ends it eases back out (smoothing: 4.5/s position, 3.6/s zoom). On victory
  it pushes in on the party.
- **Phone portrait:**
  - The two sides are pulled together (×0.62 horizontally) and spread vertically (×1.3) so the camera can get close.
  - Party cards become a 3-across grid.
  - The prompt and summary span the width.
  - The Attack Order tab stacks the rows above the timeline.
- **Readability at zoom:** damage text and impact fx (spark, ring, burst, slash, pulse) are counter-scaled by about
  zoom^-0.55 to -0.6. That keeps them crisp instead of screen-filling. The HITS counter sits on a soft dark plate.
- **Personality:**
  - Idle: per-unit breathing and a gentle bob. Wounded units (under 30% HP) breathe slower and sag.
  - Hurt: a 260 ms flinch with squash, a lean back and a red tint.
  - Victory: staggered hops. The party hops on a win; foes hop if the party loses.
  - Brave Burst cut-in: shows the caster's diamond portrait and name.
- Taps on enemies are converted through the camera (`screen_to_world`).
