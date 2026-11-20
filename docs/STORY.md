# Airron's Quest: The Tenth Kindling (main story)

This is the main story for the Airron's Quest sample. A full playthrough runs about **4 hours**. Airron wrote the
blueprint (the guard with a "!", the king's event, recruiting the party, a mini-boss back in the kingdom, then a
dungeon with the final boss). This document fills in the rest, and the code follows it: `scripts/story/`.

## Premise
Emberhold is an island kingdom on **Cinderreach**. For nine reigns the coals of the **Ember Throne** have kept the
Ash (the grey blight from Airron's Fall: ashlings, husks, moths) beyond the walls. Once every hundred years the realm
holds **the Kindling**, a festival night when sparks from the four **Wardfires** of the isle are carried home to
feed the throne.

This is the tenth Kindling, and something is wrong: all four Wardfires went dark on the same night, and none of
their Wardens came home.

**Ser Bramwell Tunn** (the hero) is the Knight of the Barrow Watch, which is the dullest post in the kingdom: guarding
graves that never get up. He's well loved at the Ember Inn for his toasts, and nobody expects much of him.

## The king's event: the Kindling Hunt
King Orlan turns the crisis into a festival, because a frightened town is worse than a dark one. He proclaims
**the Kindling Hunt**:
- Whoever brings home the four Wardfire sparks before Kindling Night will be named **Hearth-Champion**, will sit
  at the king's right hand, and will light the throne in front of the whole town.
- The town throws itself into it. Pell the Firewright builds fireworks, Joryn sells "fresh-ish" ember buns, and
  Drosk the Coinwright opens a betting book on the champions (the odds on Bramwell are 40 to 1).
- Bramwell's rival is **Ser Caldric Morn**, Knight of the Cinder Gate and the court favourite. He sets off at a
  gallop and spends the whole story one step behind.
- The king gives Bramwell the **Kindling Lantern** to carry the sparks. Each Wardfire is guarded by someone lost,
  and each of them joins the party.

## Structure
| Act | Beat | Where | Story fight |
|---|---|---|---|
| Prologue | Vellin the gate-serjeant (**!**) stops Bramwell at the town gate: the king wants him, now. | Emberhold | |
| I. The Summons | Walk to the castle. King Orlan proclaims the Kindling Hunt, and you choose how to take the job (**Choice 1**). You meet Caldric and the court Lamplighter **Taren Unlit**. Aunt Maera (Bramwell's house) explains the Wardfires and gives you a tonic. | Castle, town | |
| II. The Wardfires | Recruit the four Wardens, in any order. Each one has a small arc, a story fight and a spark. | Cinderreach | 4 or 5 |
| III. Kindling Night | Back at the castle, the king calls the Kindling at the plaza. Taren betrays the court, summons the **Matron of Cinders** in the square (**mini-boss**) and escapes with the Heart-Coal to the Sunken Bastion. | Emberhold plaza | Mini-boss |
| IV. The Sunken Bastion | The seal under the ruin is broken. Go down three floors (Drowned Gate, Reliquary Halls, Unlit Throne). Taren waits at the bottom, bound to **the Unlit Regnant**. Under that sleeps **the Ash Sovereign**. | Dungeon (separate scene) | 2 floor guardians + 2-phase final boss |
| Epilogue | The ending (**Choice 5**) plus one card for each Warden, Taren, Caldric and the town. | Castle / plaza | |

### The four Wardens (recruits)
The hero starts **alone**. Each Warden joins at a different spot on Cinderreach. Wild fights grow with the party
(1 foe while alone, up to 2 with two keepers, 2-3 from three keepers up). A recruit joins at about the hero's level,
so nobody has to grind a newcomer.

1. **Grieve the Twice-Buried** (Revenant), at the **Wardfire of Roots**, Gloamwood Heart (west forest). He was buried
   beneath the old willow twice: once as a reliquary guard who died defending it, and once by Ash-cultists who
   wanted him quiet. The guttering fire has raised him a third time. Fight: Charnel Leaper + gloam moths
   (Gallowbough Orchard). Afterwards the cultists' **reliquary** is left with you (**Choice 2**).
2. **Old Halvard** (Guardian, Last of the Rust Barons), at the **Wardfire of the Forge**, inside Coalvein Cave.
   A crown took his barony and he trusts no king. He refuses to leave his anvil while ash brutes choke the deep
   forge. Fight: Ash Elite + brutes (Coalvein Deeps). How he treats you depends on **Choice 1**.
3. **Corvin Brass** (Automaton Duelist, Duelist of the Low Orbit), at the **Wardfire of the Star**, Cliff Overlook.
   He fell from the sky onto the cliffs. The Star Wardfire isn't a fire at all: it's the fallen star that beats in
   his chest. To relight it you either take a spark from his heart or hunt a Reliquary Engine for its core
   (**Choice 3**).
4. **Queen Ilsabet** (Queen of the Drowned Court), at the **Wardfire of the Tide**, the Drowned Steps on the south
   shore. **The Drowned Cardinal** usurped her sunken court and put out the Tide fire. Fight: the Drowned Cardinal
   (a boss sprite at elite strength). Afterwards the court's souls are yours to decide (**Choice 4**).

Grieve is usually first (closest, lowest level) and Ilsabet last. The tracker suggests that order with a
**recommended level**, but every Warden can be recruited at any time after Act I.

### Mini-boss: Kindling Night
Once all four sparks are in the Lantern, the king calls the Kindling at the plaza in front of the castle gate, and
the town gathers. Taren Unlit, the Lamplighter who has tended the throne for thirty years, takes the four sparks. He
doesn't feed the throne. He tears out its **Heart-Coal** and calls up the **Matron of Cinders** in the square.
- **Mini-boss fight:** the Matron of Cinders plus two ashlings (Vespergate Sanctum backdrop).
- If you kept the reliquary (Choice 2), Selka has decoded it and warned the king. The guards are ready, the Matron
  starts one level lower, and Bramwell calls Taren out before he can strike.
- After the fight Taren is gone, down into the Sunken Bastion. The seal under the ruin is open and the throne is
  going cold. Caldric, humbled, asks to hold the gate.

### The dungeon: the Sunken Bastion (built by the dungeon worker)
Three floors under the ruin east of town, ending in the final boss.
1. **The Drowned Gate.** Guardian: Tithe Collector + Grave Lancers. With the **Reliquary Key** (Choice 2 = keep), a
   side door skips this guardian.
2. **The Reliquary Halls.** Guardian: Knellbearer + Choir Husks. If you **bound the drowned court** (Choice 4), its
   souls drown this guardian for you.
3. **The Unlit Throne.** **Final boss**, two phases:
   - **Phase 1, the Unlit Regnant** (Taren's patron, with 2 husks). Taren falls, the Sovereign wakes, and you decide
     whether to pull Taren out of the dark (**Choice 5a**).
   - **Phase 2, the Ash Sovereign** (the thing the Ember Throne was built to keep asleep). The party keeps the HP it
     had after phase 1.

## Choices and their consequences
Every choice is saved as a story flag. The **Chronicle** tab in the journal lists the choices you made.

| # | When | Options | Consequences |
|---|---|---|---|
| 1 | Act I, the king | **Swear the Oath** (`c1_oath`) / **Name your price** (`c1_price`) | Oath: the King's Writ, Warden Mail from the armory, a king who trusts you on Kindling Night, and Ilsabet's respect in her dialog. Price: 200 gold now, and **Halvard is loyal** ("You took his gold, not his leash. Good."). With the Oath, Halvard joins but stays wary (not loyal). |
| 2 | Gloamwood, after Grieve's fight | **Burn the reliquary** (`c2_burn`) / **Take it to Selka** (`c2_keep`) | Burn: Grieve is finally at peace and **loyal** (gives the *Gravebell* heirloom). Keep: Grieve is hurt (not loyal), but Selka decodes it. The king is warned before Kindling Night (the mini-boss is 1 level lower, with different dialog), and you get the **Reliquary Key**, which skips floor 1's guardian. |
| 3 | Cliff Overlook | **Take a spark from Corvin's heart** (`c3_heart`) / **Hunt a Reliquary Engine** (`c3_hunt`) | Heart: no fight, but Corvin is dimmed (not loyal, sadder lines, darker epilogue). Hunt: an extra elite fight (Reliquary Engine), and Corvin is **loyal** (gives the *Loaded Dice* heirloom). |
| 4 | Drowned Steps, after the Cardinal | **Let the tide take them** (`c4_rest`) / **Bind them to the Tide fire** (`c4_bind`) | Rest: Ilsabet is **loyal** (gives the *Tideglass Shard* heirloom). Bind: the bound souls clear floor 2's guardian in the Bastion, but Ilsabet goes cold (not loyal) and her epilogue changes. |
| 5a | Final boss, between phases | **Pull Taren out** (`c5_spare`) / **Leave him to the dark** (`c5_leave`) | Spare: the party takes the burn (phase 2 starts at 75% of current HP), and Taren lives to become the new Lamplighter. Leave: phase 2 starts at full current HP, and Taren is lost. |
| 5b | Ending | **Return the Heart-Coal to the throne** (`end_throne`) / **Share it with the Wardfires** (`end_hearth`) | Throne: the ending *The Tenth Kindling*. Hearth: the ending *A Hearth of Five*. That one is the best ending only with **3 or more loyal Wardens**; with fewer, the flame gutters (a bittersweet version). |

The loyalty count (0-4) also chooses each Warden's epilogue card. A loyal Warden's **heirloom** is real gear: it goes
into the bag and can be equipped from Build.

## Side quests
- **Pell's Lost Fireworks** (Pell, town): three crates of festival fireworks fell off a cart on Cinderreach (north
  meadow, east shore, south-west strand). Reward: 120 gold, plus fireworks on Kindling Night and in the epilogue.
- **The Quiet Bell** (Sister Wenna, by the chapel): ring the bell at the Votive Shrine and quiet the Knellbearer
  that answers. Reward: a Brook Pendant, and after that Wenna heals the party for free whenever you talk to her.
- **Drosk's Book** (Drosk the Coinwright, plaza): put 50 gold on yourself at 40 to 1 (paid out at 4 to 1 "for the
  house's health"). After Kindling Night he pays you 200 gold.

## Player guidance
- **Markers:** a gold **!** over someone who has a new quest or a story beat, and a gold **?** over the person or place
  your current objective points at. Side-quest markers are pale blue.
- **Objective tracker** (top left, under the location card): the current step, a hint and the recommended level. Tap
  it to open the journal.
- **Direction:** a pulsing beacon on the objective in the world, plus an arrow at the screen edge when it's off-screen,
  with the distance in steps. On the overworld the arrow points at the right exit when the target is on another map.
- **Journal** (the "Quests" button): **Main Story** (acts and steps, done and current), **Side Quests**, **Party &
  Chronicle** (each Warden's loyalty and the choices made).
- **Dialog:** a portrait, a name plate and typewriter text. Tap or press E/Space to skip ahead or advance. Choices are
  big buttons (also keys 1-3).
- **First-time tips** (once each): talking, the journal, danger and random battles, recruiting (with a reminder to set
  the Attack Order in Build).

## Pacing (about 4 hours)
These numbers come from `docs/BALANCE.md` (balance PR #12): about **190 fights take a class from Lv1 to Lv10 in
roughly 4 hours**, so one fight plus the walking around it is about 76 s at 1x. Story fights give more EXP (mini-boss 50,
boss 80), and recruits join with 90% of the hero's best class EXP, so about 170 fights carry the party to Lv9-10 by the
final boss. Recommended levels are the minimum level of each story fight (foe level = party level, clamped to
*rec .. rec+2*). The "Fights" column counts wild and story fights together; "Talk" is dialog and reading time on top.

| Beat | Rec. Lv | Fights (wild + story) | Talk | Time |
|---|---|---|---|---|
| Prologue + Act I (guard, castle, Maera, town) | 1 | 2 | 6 min | 9 min |
| Grieve, Gloamwood Heart | 2 | 19 + 1 (alone, short fights) | 3 min | 28 min |
| Halvard, Coalvein Forge | 3 | 26 + 1 | 3 min | 37 min |
| Corvin, Cliff Overlook | 5 | 29 + 1 (or 2 if Hunt) | 3 min | 41 min |
| Ilsabet, Drowned Steps | 6 | 31 + 1 | 3 min | 44 min |
| Side quests (fireworks, bell, book) | any | 7 + 1 | 3 min | 13 min |
| Act III, Kindling Night + mini-boss | 7 | 11 + 1 | 3 min | 18 min |
| Act IV, Sunken Bastion (floors) + final boss, 2 phases | 8-10 | 35 + 4 | 4 min | 53 min |
| Epilogue | | | 2 min | 2 min |
| **Total** | | **~170** | **30 min** | **~4 h 05 min** |

Players on 2x/3x battle speed finish faster. Wild battles scale with the party: while the hero is alone at most one
foe appears, with two Wardens at most two, then the normal three (`Story.max_foes()`).

## Story flags (save format)
Saved in `user://kingdom.cfg`, section `[story]`: `flags` (comma list), `vars` (a JSON dictionary: counters, gold
bets, loyalty) and `recruited` (comma list of keeper ids). New Game deletes the file, so the story starts over.
- Main steps: `s_prologue`, `s_king`, `s_maera`, `got_grieve`, `got_halvard`, `got_corvin`, `got_ilsabet`,
  `s_return`, `s_kindling` (mini-boss won), `s_bastion` (entered), `bastion_f1`, `bastion_f2`, `boss1_won`,
  `boss2_won`, `s_ending`.
- Choices: `c1_oath|c1_price`, `c2_burn|c2_keep`, `c3_heart|c3_hunt`, `c4_rest|c4_bind`, `c5_spare|c5_leave`,
  `end_throne|end_hearth`.
- Side quests: `sq_fire_on`, `crate_1..3`, `sq_fire_done`; `sq_bell_on`, `sq_bell_done`; `sq_book_bet`, `sq_book_paid`.
- Loyalty: `loyal_grieve`, `loyal_halvard`, `loyal_corvin`, `loyal_ilsabet`.

## API for other scenes (the dungeon and boss work)
`Story` is an autoload (`scripts/story/story.gd`). Its dialog UI is a CanvasLayer that the autoload owns, so it
works in any scene: kingdom, dungeon or battle.

```gdscript
Story.get_flag("bastion_f1") -> bool        # any flag above
Story.set_flag("bastion_f1", true)          # saves immediately, emits flag_changed, refreshes the objective
Story.start_dialog("bastion_f1_enter", func(): print("closed"))   # play a dialog by id (scripts/story/story_dialog.gd)
Story.ui_open() -> bool                     # true while a dialog / journal is up (pause your movement while it is)
Story.start_battle("boss_regnant")          # story fight through QuestFlow + main.tscn, returns to the scene it came from
Story.encounter_for("boss_regnant") -> Dictionary  # the encounter dictionary (foes, tiers, art, level, boss id)
Story.enter_dungeon()                       # Act IV: opens DUNGEON_SCENE (res://scenes/dungeon.tscn)
Story.exit_dungeon()                        # back to the overworld at the Sunken Bastion
Story.objective() -> Dictionary             # {id, title, text, hint, rec, target}
Story.recruited() -> Array                  # ["bramwell", ...]
Story.loyal_count() -> int

signal flag_changed(name: String, value: bool)
signal battle_finished(id: String, won: bool)
signal boss_defeated(id: String)            # "miniboss_matron", "guardian_f1", "guardian_f2", "boss_regnant", "boss_sovereign"
signal objective_changed()
```

**Story fights** (ids for `start_battle`): `fight_grieve`, `fight_halvard`, `fight_engine`, `fight_cardinal`,
`fight_bell`, `miniboss_matron`, `guardian_f1`, `guardian_f2`, `boss_regnant`, `boss_sovereign`. Every encounter
dictionary carries `story_id`, `boss` (true for the mini-boss and bosses), `tiers` (per foe slot: `regular` /
`elite` / `miniboss` / `boss`), `foe_ids` (per slot, the Airron's Fall roster foe that sets the art and name, `""` =
random for the area, e.g. `["matron", ""]`), `area`, `level`, `banner` and `banner_sub`. Mini-boss and boss fights use
one regular escort; per BALANCE that is about an 80% win rate on the mini-boss and 63-70% on a boss at the
recommended level. Losing is fine: the lose dialog heals the party and the fight can be retried. Boss presentation code can key off
`encounter.story_id` / `encounter.boss`.

**Dungeon contract.** These are the flags the dungeon scene should read and set:
- Read `c2_keep` (the Reliquary Key opens the side door, so you can skip `guardian_f1`) and `c4_bind` (the souls clear
  `guardian_f2`: call `Story.set_flag("bastion_f2")` without a fight).
- When a guardian is beaten, `Story` sets `bastion_f1` / `bastion_f2` itself, after `start_battle` comes back won.
- At the throne, call `Story.start_dialog("final_confront")`. It runs phase 1, the 5a choice, phase 2, the ending
  choice and the epilogue on its own, chaining `start_battle("boss_regnant")` and `start_battle("boss_sovereign")`.
  When it's done, `s_ending` is set and the game returns to Emberhold for the epilogue.
- Before calling `Story.start_battle(...)` from the dungeon, save your own dungeon state (floor, position). The fight
  returns to the scene it started from (`scenes/dungeon.tscn`), and the win or lose dialog plays there about 0.7 s after
  the scene loads.
- The story tracker HUD shows in the kingdom only. Set `Story.hud_wanted = true` in the dungeon scene to show it there
  too (leave it off if the dungeon draws its own objective HUD). Dialogs, cards and toasts work in every scene.
- Until `scenes/dungeon.tscn` exists, `enter_dungeon()` plays a built-in fallback: the floor dialogs, the guardian
  fights and the final sequence run straight from the Sunken Bastion spot on the overworld. That way the story can
  be finished end to end and tested today. Once the scene exists, `enter_dungeon()` loads it automatically.
