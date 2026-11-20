extends RefCounted
## Airron's Quest RPG layer (data only; tweak freely). The math is explained in docs/BALANCE.md.
##
## Every keeper equips ONE class and ONE subclass, both picked from the same CLASS_ORDER list (they must differ).
##   class    -> its stat package + its 2 CLASS abilities  (row lists in CLASSES[c].abilities)
##   subclass -> SUB_STAT_SHARE of that class's stat package + its 2 SUBCLASS abilities (CLASSES[c].sub_abilities)
## So a keeper always brings 4 abilities (2 + 2) and any class pairs with any other: 10 classes = 90 combos.
## Each class and each subclass has its own level (1..LEVEL_CAP) per keeper, earned from battle EXP.
##
## Ability row: [id, name, blurb, kind, params, unlock level, default sequence condition]
##   kinds: damage_single, damage_all_enemies, buff_self, buff_party, heal_single, heal_party
##   params: mult, pct, self, buffs/turns, debuff/dturns, self_buff/sturns, party_buff/pturns (see game.gd)
##   unlock level: class level for class abilities, subclass level for subclass abilities.

const LOADOUT_SLOTS := 4
const MAX_RULES := 6
const SUB_STAT_SHARE := 0.35

const CLASS_ORDER := ["Warrior", "Guardian", "Knight", "Rogue", "Monk", "Ranger", "Mage", "Warlock", "Cleric", "Bard"]
const CLASSES := {
	"Warrior": {"kind": "warrior", "blurb": "Front-line melee. Big single hits and cleaves.", "role": "Melee DPS", "focus": "atk",
		"hp": 30, "atk": 22, "def": 8, "armor": 10, "crit": 4, "mana": 2, "speed": 6,
		"abilities": [
			["w_cleave", "Cleave", "A wide swing that hits every foe.", "damage_all_enemies", {"mult": 1.6}, 1, "foes_2"],
			["w_heavy_blow", "Heavy Blow", "One crushing hit on a single foe.", "damage_single", {"mult": 3.2}, 3, "always"]],
		"sub_abilities": [
			["w_war_cry", "War Cry", "Roars the party on: ATK up.", "buff_party", {"buffs": [["atk", 16]], "turns": 2}, 1, "turn_1"],
			["w_sunder", "Sunder", "Breaks one foe's armor.", "damage_single", {"mult": 2.0, "debuff": [["armor", -10]], "dturns": 2}, 3, "boss"]]},
	"Guardian": {"kind": "pawn", "blurb": "The wall. Soaks hits and shields the party.", "role": "Tank", "focus": "hp",
		"hp": 80, "atk": 2, "def": 22, "armor": 16, "crit": 0, "mana": 4, "speed": 0,
		"abilities": [
			["g_shield_wall", "Shield Wall", "Party Defense and Armor up.", "buff_party", {"buffs": [["def", 26], ["armor", 10]], "turns": 2}, 1, "always"],
			["g_rally", "Rally", "Heals the whole party a little.", "heal_party", {"pct": 0.2}, 3, "ally_low"]],
		"sub_abilities": [
			["g_bulwark", "Bulwark", "Self Defense way up.", "buff_self", {"buffs": [["def", 36], ["armor", 12]], "turns": 2}, 1, "self_low"],
			["g_shield_bash", "Shield Bash", "Bashes one foe and slows it.", "damage_single", {"mult": 2.0, "debuff": [["speed", -12]], "dturns": 2}, 3, "always"]]},
	"Knight": {"kind": "warrior", "blurb": "Armored lancer. Hits hard and steadies the line.", "role": "Bruiser", "focus": "def",
		"hp": 50, "atk": 12, "def": 16, "armor": 14, "crit": 2, "mana": 4, "speed": 2,
		"abilities": [
			["k_lance_charge", "Lance Charge", "A charging hit on one foe.", "damage_single", {"mult": 3.2}, 1, "always"],
			["k_valor", "Valor", "Party Defense and ATK up.", "buff_party", {"buffs": [["def", 18], ["atk", 10]], "turns": 2}, 3, "turn_1"]],
		"sub_abilities": [
			["k_parry", "Parry", "Self Defense and Armor up.", "buff_self", {"buffs": [["def", 30], ["armor", 14]], "turns": 2}, 1, "self_low"],
			["k_shield_rush", "Shield Rush", "Rams the whole enemy line.", "damage_all_enemies", {"mult": 1.3}, 3, "foes_3"]]},
	"Rogue": {"kind": "warrior", "blurb": "Fast, crit-heavy, finishes weak foes.", "role": "Melee DPS", "focus": "crit",
		"hp": 10, "atk": 18, "def": 2, "armor": 4, "crit": 18, "mana": 2, "speed": 18,
		"abilities": [
			["r_backstab", "Backstab", "A vicious hit on one foe.", "damage_single", {"mult": 3.4}, 1, "always"],
			["r_eviscerate", "Eviscerate", "Finisher on one weakened foe.", "damage_single", {"mult": 4.6}, 3, "foe_low"]],
		"sub_abilities": [
			["r_poison_blade", "Poison Blade", "Cuts one foe and weakens its attack.", "damage_single", {"mult": 2.0, "debuff": [["atk", -12]], "dturns": 2}, 1, "always"],
			["r_fan_of_knives", "Fan of Knives", "Knives at every foe.", "damage_all_enemies", {"mult": 1.2}, 3, "foes_3"]]},
	"Monk": {"kind": "warrior", "blurb": "Quick fists and inner calm. Fast turns, self-sustain.", "role": "Skirmisher", "focus": "speed",
		"hp": 20, "atk": 16, "def": 6, "armor": 6, "crit": 10, "mana": 4, "speed": 16,
		"abilities": [
			["mo_flurry", "Flurry", "A storm of blows on one foe.", "damage_single", {"mult": 3.2}, 1, "always"],
			["mo_inner_focus", "Inner Focus", "Self Speed and Crit up.", "buff_self", {"buffs": [["speed", 20], ["crit", 16]], "turns": 2}, 3, "turn_1"]],
		"sub_abilities": [
			["mo_palm_strike", "Palm Strike", "Opens one foe's guard (Defense down).", "damage_single", {"mult": 2.2, "debuff": [["def", -12]], "dturns": 2}, 1, "always"],
			["mo_chi_mend", "Chi Mend", "Heals self.", "heal_single", {"pct": 0.3, "self": true}, 3, "self_low"]]},
	"Ranger": {"kind": "archer", "blurb": "Ranged shots, marks and volleys.", "role": "Ranged DPS", "focus": "crit",
		"hp": 12, "atk": 18, "def": 2, "armor": 3, "crit": 12, "mana": 3, "speed": 12,
		"abilities": [
			["ra_aimed_shot", "Aimed Shot", "A careful shot at one foe.", "damage_single", {"mult": 3.0}, 1, "always"],
			["ra_volley", "Volley", "Arrows rain on every foe.", "damage_all_enemies", {"mult": 1.6}, 3, "foes_2"]],
		"sub_abilities": [
			["ra_hunters_mark", "Hunter's Mark", "Marks one foe: its Defense drops.", "damage_single", {"mult": 1.6, "debuff": [["def", -18]], "dturns": 3}, 1, "boss"],
			["ra_herbal_kit", "Herbal Kit", "Patches up the weakest ally.", "heal_single", {"pct": 0.28}, 3, "ally_low"]]},
	"Mage": {"kind": "archer", "blurb": "Spells that hit every foe. Fragile.", "role": "Caster", "focus": "atk",
		"hp": 0, "atk": 26, "def": 0, "armor": 0, "crit": 8, "mana": 14, "speed": 6,
		"abilities": [
			["m_fireball", "Fireball", "Fire bursts over every foe.", "damage_all_enemies", {"mult": 1.8}, 1, "foes_2"],
			["m_frost_bolt", "Frost Bolt", "Hits one foe and slows it.", "damage_single", {"mult": 2.8, "debuff": [["speed", -14]], "dturns": 2}, 3, "always"]],
		"sub_abilities": [
			["m_arcane_shield", "Arcane Shield", "Self Defense and Armor up.", "buff_self", {"buffs": [["def", 28], ["armor", 10]], "turns": 2}, 1, "self_low"],
			["m_arcane_bolt", "Arcane Bolt", "A bolt of raw force on one foe.", "damage_single", {"mult": 2.4}, 3, "always"]]},
	"Warlock": {"kind": "archer", "blurb": "Curses and rot. Weakens foes, then burns them down.", "role": "Caster", "focus": "atk",
		"hp": 6, "atk": 24, "def": 0, "armor": 2, "crit": 6, "mana": 12, "speed": 6,
		"abilities": [
			["wl_hex_bolt", "Hex Bolt", "Hits one foe and weakens its attack.", "damage_single", {"mult": 3.0, "debuff": [["atk", -12]], "dturns": 2}, 1, "always"],
			["wl_soul_rot", "Soul Rot", "Rot spreads over every foe.", "damage_all_enemies", {"mult": 1.7}, 3, "foes_2"]],
		"sub_abilities": [
			["wl_curse", "Curse", "Curses one foe: big Defense down.", "damage_single", {"mult": 1.6, "debuff": [["def", -20]], "dturns": 3}, 1, "boss"],
			["wl_dark_pact", "Dark Pact", "Self ATK way up.", "buff_self", {"buffs": [["atk", 26]], "turns": 2}, 3, "turn_1"]]},
	"Cleric": {"kind": "paladin", "blurb": "Heals and blessings. Keeps the party up.", "role": "Healer", "focus": "mana",
		"hp": 36, "atk": 6, "def": 12, "armor": 10, "crit": 0, "mana": 12, "speed": 4,
		"abilities": [
			["c_heal", "Heal", "Big heal on the weakest ally.", "heal_single", {"pct": 0.45}, 1, "ally_hurt"],
			["c_prayer", "Prayer", "Heals the whole party.", "heal_party", {"pct": 0.25}, 3, "ally_low"]],
		"sub_abilities": [
			["c_smite", "Smite", "Holy damage on one foe.", "damage_single", {"mult": 2.2}, 1, "always"],
			["c_blessing", "Blessing", "Party Defense up.", "buff_party", {"buffs": [["def", 20]], "turns": 2}, 3, "turn_1"]]},
	"Bard": {"kind": "archer", "blurb": "Songs that lift the party and rattle foes.", "role": "Support", "focus": "mana",
		"hp": 14, "atk": 10, "def": 6, "armor": 4, "crit": 6, "mana": 12, "speed": 10,
		"abilities": [
			["b_ballad", "Battle Ballad", "Party ATK and Speed up.", "buff_party", {"buffs": [["atk", 18], ["speed", 8]], "turns": 2}, 1, "turn_1"],
			["b_dirge", "Dirge", "A low note that hurts and slows every foe.", "damage_all_enemies", {"mult": 1.2, "debuff": [["speed", -10]], "dturns": 2}, 3, "foes_2"]],
		"sub_abilities": [
			["b_song_of_rest", "Song of Rest", "Heals the whole party a little.", "heal_party", {"pct": 0.18}, 1, "ally_hurt"],
			["b_dissonance", "Dissonance", "A jarring chord on one foe.", "damage_single", {"mult": 2.4}, 3, "always"]]},
}

## Sequence conditions: id -> label shown in the Build screen.
const COND_ORDER := ["always", "ally_hurt", "ally_low", "self_low", "foes_2", "foes_3", "foe_low", "boss", "turn_1"]
const CONDITIONS := {
	"always": "always",
	"ally_hurt": "an ally < 75% HP",
	"ally_low": "an ally < 50% HP",
	"self_low": "self < 50% HP",
	"foes_2": "2+ foes left",
	"foes_3": "3+ foes left",
	"foe_low": "a foe < 30% HP",
	"boss": "fighting a boss or elite",
	"turn_1": "first turn",
}

## Starting class + subclass for each keeper, from their Airron's Fall archetype.
const FROM_KIT_CLASS := {"Knight": "Warrior", "Warrior": "Rogue", "Guardian": "Guardian", "Warden": "Guardian",
	"Marksman": "Ranger", "Ranger": "Mage", "Paladin": "Cleric"}
const DEFAULT_SUB := {"Warrior": "Knight", "Guardian": "Cleric", "Knight": "Warrior", "Rogue": "Monk", "Monk": "Rogue",
	"Ranger": "Bard", "Mage": "Warlock", "Warlock": "Mage", "Cleric": "Guardian", "Bard": "Ranger"}

# ---------------------------------------------------------------- EXP and levels (see docs/BALANCE.md)
const LEVEL_CAP := 10
## EXP needed to go from level L to L+1 (index 0 = Lv1->2). Sum = 10,520 EXP for Lv10 (~180 on-level battles).
const XP_TO_NEXT := [285, 420, 570, 750, 1045, 1280, 1660, 2090, 2420]
## EXP per defeated foe by tier, scaled by foe level: base * (0.75 + 0.25 * level).
const TIER_XP := {"regular": 11, "elite": 33, "miniboss": 50, "boss": 80}
const SUB_SHARE := 0.5      # the equipped subclass earns half of the class EXP
const LOSS_SHARE := 0.25    # a lost or fled fight still pays a quarter for foes already beaten
const BENCH_SHARE := 0.0    # keepers not in the party earn nothing
## Grinding guard: per level the keeper's class is above the foe level, -15% EXP (floor 40%); below, +10% (cap 130%).
const OVER_PENALTY := 0.15
const UNDER_BONUS := 0.10
## Stat growth per class level above 1 (plus the class focus stat again at FOCUS_EXTRA).
const GROWTH := {"hp": 12.0, "atk": 1.5, "def": 1.2, "armor": 0.45, "crit": 0.45, "mana": 0.3, "speed": 0.45}
const FOCUS_EXTRA := {"hp": 12.0, "atk": 1.8, "def": 1.5, "armor": 0.75, "crit": 1.0, "mana": 0.9, "speed": 1.2}

static func level_for_xp(total: int) -> int:
	var lv := 1
	var need := 0
	for step in XP_TO_NEXT:
		need += int(step)
		if total >= need: lv += 1
		else: break
	return mini(lv, LEVEL_CAP)

static func xp_floor(level: int) -> int:
	var t := 0
	for i in mini(level - 1, XP_TO_NEXT.size()): t += int(XP_TO_NEXT[i])
	return t

static func foe_xp(tier: String, level: int) -> float:
	return float(TIER_XP.get(tier, 10)) * (0.75 + 0.25 * float(level))

static func level_factor(keeper_lv: int, foe_lv: int) -> float:
	var d := keeper_lv - foe_lv
	if d > 0: return maxf(0.4, 1.0 - OVER_PENALTY * d)
	return minf(1.3, 1.0 + UNDER_BONUS * -d)


# ---------------------------------------------------------------- auto-levelled foes (docs/BALANCE.md)
## Every wild fight is levelled to the party: foe level = round(average equipped class level of the party)
## + a random -1 / 0 / +1, clamped to 1..LEVEL_CAP. Regions only choose the foe pool, the art and the elite chance.
## A foe stat is:   stat = base × FOE_BASE[stat] × FOE_TIER[tier][stat] × (1 + FOE_GROWTH[stat] × (level - 1))
## where base is the foe kind's own stat line (game.gd char_stats for the red team).
const FOE_LEVEL_SPREAD := 1
const FOE_BASE := {"hp": 1.8, "atk": 1.6, "def": 1.0, "speed": 1.0, "mana": 1.0}
const FOE_TIER := {
	"regular": {"hp": 1.0, "atk": 1.0, "def": 1.0, "speed": 1.0, "mana": 1.0},
	"elite": {"hp": 1.5, "atk": 1.15, "def": 1.1, "speed": 1.08, "mana": 1.25},
	# Story fights (encounter.tiers, game.gd new_battle). With one regular escort at the party's level, the default
	# party wins ~80% of mini-boss fights and ~65-70% of final-boss fights on AUTO (docs/BALANCE.md).
	"miniboss": {"hp": 1.7, "atk": 1.1, "def": 1.2, "speed": 1.05, "mana": 1.4},
	"boss": {"hp": 2.2, "atk": 1.2, "def": 1.3, "speed": 1.1, "mana": 1.5},
}
## Drawn size per tier (elites and bosses read bigger on the field).
const FOE_SIZE := {"regular": 1.0, "elite": 1.15, "miniboss": 1.3, "boss": 1.5}
const FOE_GROWTH := {"hp": 0.07, "atk": 0.035, "def": 0.05, "speed": 0.02, "mana": 0.03}


static func foe_level(party_level: float, spread: int = FOE_LEVEL_SPREAD) -> int:
	return clampi(int(roundf(party_level)) + randi_range(-spread, spread), 1, LEVEL_CAP)


static func foe_scale(stat: String, tier: String, level: int) -> float:
	var t: Dictionary = FOE_TIER.get(tier, FOE_TIER.regular)
	return float(FOE_BASE.get(stat, 1.0)) * float(t.get(stat, 1.0)) * (1.0 + float(FOE_GROWTH.get(stat, 0.0)) * float(maxi(1, level) - 1))

## Time model for the 4-hour target (tools/sim_balance.gd): one battle loop = the fight itself + LOOP_OVERHEAD_S
## (walking until the danger meter fills, iris transitions, the results screen) + SELECT_S per party turn (the
## target-select window; tapping a foe or AUTO skips it, so this is the slow, hands-off case).
const LOOP_OVERHEAD_S := 25.0
const SELECT_S := 2.6

## Party HP between wild fights (QuestFlow.finish_battle): a win catches the party's breath and recovers
## WIN_RECOVER of the missing HP (never below WIN_FLOOR); a loss leaves 1 HP (rest at the inn).
## Without this, HP carried at ~60% into the next fight and the chained win rate fell under 50% (docs/BALANCE.md).
const WIN_RECOVER := 0.8
const WIN_FLOOR := 0.35

static func hp_after_battle(won: bool, frac_left: float) -> float:
	var f := clampf(frac_left, 0.0, 1.0)
	if not won: return 0.0
	return maxf(WIN_FLOOR, f + (1.0 - f) * WIN_RECOVER)

## Rift surge in regular fights: +SURGE_STEP damage per turn after turn 3, both sides (game.gd surge_mult).
const SURGE_STEP := 0.35
## Boss enrage (replaces the surge in boss fights, docs/BOSSES.md): from turn `turn` (a "about to ENRAGE" warning
## one turn earlier), the boss side deals +step per turn, capped at max. The party never ramps in a boss fight.
## static var so tools/sim_bosses.gd can sweep it (--enrage=turn,step,max).
static var BOSS_ENRAGE := {"turn": 18, "step": 0.25, "max": 3.0}

static func boss_enrage_mult(turn: int, start: int) -> float:
	if turn < start: return 1.0
	return minf(float(BOSS_ENRAGE.max), 1.0 + float(BOSS_ENRAGE.step) * float(turn - start + 1))
