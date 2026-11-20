extends RefCounted
## Airron's Quest RPG layer (data only, tweak freely):
##   CLASSES   - every changeable class: stat package added on top of the keeper's base, sprite kind, blurb.
##   POOLS     - each class's ability pool. Row = [id, name, blurb, kind, params, unlock level].
##               kinds: damage_single, damage_all_enemies, buff_self, buff_party, heal_single, heal_party
##               (params as in game.gd AB_CLASS_ROWS: mult, pct, self, buffs/turns, debuff/dturns, self_buff, party_buff).
##   LOADOUT_SLOTS - abilities a keeper brings into battle (picked from signature + class pool + subclass pool).
##   CONDITIONS - sequence rule checks (see game.gd seq_condition_ok). Add new ids there and here.
##   DEFAULT_SEQ - the starting priority list for each class.
## A keeper's signature ability (their Airron's Fall weapon) is in every class pool.

const LOADOUT_SLOTS := 4
const MAX_RULES := 6

const CLASS_ORDER := ["Warrior", "Guardian", "Rogue", "Ranger", "Mage", "Cleric"]
const CLASSES := {
	"Warrior": {"kind": "warrior", "blurb": "Front-line melee. Big single hits and cleaves.", "role": "Melee DPS",
		"hp": 30, "atk": 22, "def": 8, "armor": 10, "crit": 4, "mana": 2, "speed": 6},
	"Guardian": {"kind": "pawn", "blurb": "The wall. Soaks hits and shields the party.", "role": "Tank",
		"hp": 80, "atk": 2, "def": 22, "armor": 16, "crit": 0, "mana": 4, "speed": 0},
	"Rogue": {"kind": "warrior", "blurb": "Fast, crit-heavy, finishes weak foes.", "role": "Melee DPS",
		"hp": 10, "atk": 18, "def": 2, "armor": 4, "crit": 18, "mana": 2, "speed": 18},
	"Ranger": {"kind": "archer", "blurb": "Ranged shots, marks and volleys.", "role": "Ranged DPS",
		"hp": 12, "atk": 18, "def": 2, "armor": 3, "crit": 12, "mana": 3, "speed": 12},
	"Mage": {"kind": "archer", "blurb": "Spells that hit every foe. Fragile.", "role": "Caster",
		"hp": 0, "atk": 26, "def": 0, "armor": 0, "crit": 8, "mana": 14, "speed": 6},
	"Cleric": {"kind": "paladin", "blurb": "Heals and blessings. Keeps the party up.", "role": "Healer",
		"hp": 36, "atk": 6, "def": 12, "armor": 10, "crit": 0, "mana": 12, "speed": 4},
}

const POOLS := {
	"Warrior": [
		["w_cleave", "Cleave", "A wide swing that hits every foe.", "damage_all_enemies", {"mult": 1.5}, 1],
		["w_heavy_blow", "Heavy Blow", "One crushing hit on a single foe.", "damage_single", {"mult": 3.0}, 1],
		["w_war_cry", "War Cry", "Roars the party on: ATK up.", "buff_party", {"buffs": [["atk", 20]], "turns": 2}, 1],
		["w_sunder", "Sunder", "Breaks one foe's armor.", "damage_single", {"mult": 2.4, "debuff": [["armor", -12]], "dturns": 2}, 3],
		["w_second_wind", "Second Wind", "Catches a breath and heals self.", "heal_single", {"pct": 0.35, "self": true}, 5],
		["w_whirlwind", "Whirlwind", "Spins through the whole line.", "damage_all_enemies", {"mult": 2.6}, 10],
	],
	"Guardian": [
		["g_shield_wall", "Shield Wall", "Party Defense and Armor up.", "buff_party", {"buffs": [["def", 26], ["armor", 10]], "turns": 2}, 1],
		["g_bulwark", "Bulwark", "Self Defense way up.", "buff_self", {"buffs": [["def", 40], ["armor", 14]], "turns": 2}, 1],
		["g_shield_bash", "Shield Bash", "Bashes one foe and slows it.", "damage_single", {"mult": 2.2, "debuff": [["speed", -12]], "dturns": 2}, 1],
		["g_rally", "Rally", "Heals the party a little.", "heal_party", {"pct": 0.18}, 3],
		["g_iron_will", "Iron Will", "Big self heal.", "heal_single", {"pct": 0.45, "self": true}, 5],
		["g_last_stand", "Last Stand", "Huge party Defense for three turns.", "buff_party", {"buffs": [["def", 40], ["armor", 16]], "turns": 3}, 10],
	],
	"Rogue": [
		["r_backstab", "Backstab", "A vicious hit on one foe.", "damage_single", {"mult": 3.4}, 1],
		["r_poison_blade", "Poison Blade", "Cuts one foe and weakens its attack.", "damage_single", {"mult": 2.2, "debuff": [["atk", -14]], "dturns": 2}, 1],
		["r_shadowstep", "Shadowstep", "Self Speed and Crit up.", "buff_self", {"buffs": [["speed", 20], ["crit", 20]], "turns": 2}, 1],
		["r_fan_of_knives", "Fan of Knives", "Knives at every foe.", "damage_all_enemies", {"mult": 1.4}, 3],
		["r_eviscerate", "Eviscerate", "Finisher on one foe.", "damage_single", {"mult": 4.6}, 5],
		["r_smoke_bomb", "Smoke Bomb", "Party Speed up, foes slowed.", "buff_party", {"buffs": [["speed", 14]], "turns": 2}, 10],
	],
	"Ranger": [
		["ra_aimed_shot", "Aimed Shot", "A careful shot at one foe.", "damage_single", {"mult": 3.0}, 1],
		["ra_volley", "Volley", "Arrows rain on every foe.", "damage_all_enemies", {"mult": 1.5}, 1],
		["ra_hunters_mark", "Hunter's Mark", "Marks one foe: its Defense drops.", "damage_single", {"mult": 1.8, "debuff": [["def", -20]], "dturns": 3}, 1],
		["ra_eagle_eye", "Eagle Eye", "Self Crit way up.", "buff_self", {"buffs": [["crit", 30]], "turns": 2}, 3],
		["ra_herbal_kit", "Herbal Kit", "Patches up the weakest ally.", "heal_single", {"pct": 0.30}, 5],
		["ra_arrow_storm", "Arrow Storm", "A storm on the whole line.", "damage_all_enemies", {"mult": 2.6}, 10],
	],
	"Mage": [
		["m_fireball", "Fireball", "Fire bursts over every foe.", "damage_all_enemies", {"mult": 1.8}, 1],
		["m_frost_bolt", "Frost Bolt", "Hits one foe and slows it.", "damage_single", {"mult": 2.8, "debuff": [["speed", -14]], "dturns": 2}, 1],
		["m_arcane_shield", "Arcane Shield", "Self Defense and Armor up.", "buff_self", {"buffs": [["def", 30], ["armor", 12]], "turns": 2}, 1],
		["m_chain_lightning", "Chain Lightning", "Lightning jumps between all foes.", "damage_all_enemies", {"mult": 2.2}, 3],
		["m_arcane_surge", "Arcane Surge", "Party ATK up.", "buff_party", {"buffs": [["atk", 22]], "turns": 2}, 5],
		["m_meteor", "Meteor", "A meteor on one foe.", "damage_single", {"mult": 5.2}, 10],
	],
	"Cleric": [
		["c_heal", "Heal", "Big heal on the weakest ally.", "heal_single", {"pct": 0.45}, 1],
		["c_prayer", "Prayer", "Heals the whole party.", "heal_party", {"pct": 0.25}, 1],
		["c_smite", "Smite", "Holy damage on one foe.", "damage_single", {"mult": 2.6}, 1],
		["c_blessing", "Blessing", "Party Defense up.", "buff_party", {"buffs": [["def", 24]], "turns": 2}, 3],
		["c_holy_nova", "Holy Nova", "Light hurts every foe.", "damage_all_enemies", {"mult": 1.5}, 5],
		["c_sanctuary", "Sanctuary", "Large party heal and Armor up.", "heal_party", {"pct": 0.45, "party_buff": [["armor", 12]], "pturns": 2}, 10],
	],
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
	"boss": "fighting a boss",
	"turn_1": "first turn",
}

const DEFAULT_SEQ := {
	"Warrior": [["w_cleave", "foes_2"], ["w_heavy_blow", "always"]],
	"Guardian": [["g_rally", "ally_low"], ["g_shield_wall", "always"]],
	"Rogue": [["r_eviscerate", "foe_low"], ["r_backstab", "always"]],
	"Ranger": [["ra_volley", "foes_3"], ["ra_aimed_shot", "always"]],
	"Mage": [["m_fireball", "foes_2"], ["m_frost_bolt", "always"]],
	"Cleric": [["c_prayer", "ally_low"], ["c_heal", "ally_hurt"], ["c_smite", "always"]],
}

## Old Airron's Fall archetype classes -> changeable RPG class (starting class for each keeper).
const FROM_KIT_CLASS := {"Knight": "Warrior", "Warrior": "Rogue", "Guardian": "Guardian", "Warden": "Guardian",
	"Marksman": "Ranger", "Ranger": "Mage", "Paladin": "Cleric"}
