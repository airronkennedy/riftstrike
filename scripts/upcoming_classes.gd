extends RefCounted
# Class kits for the three classes arriving with the new character models.
# Same row format as AB_CLASS_ROWS in game.gd: [id, name, blurb, kind, params].
# Row position sets the unlock level (CLASS_UNLOCKS: 1, 11, 21, 31, 41, 51, 61, 71, 81, 99).
# Shown in the Compendium now. Not playable yet: when the art lands, copy a kit into
# AB_CLASS_ROWS[hero] and set CHAR[hero].cls (see the note on CLASS_DEFS).

const ORDER := ["Spell Breaker", "Paladin", "Warlock"]

const KITS := {
	"Spell Breaker": {"hero": "Airron", "rows": [
		["null_strike", "Null Strike", "A blade wrapped in null light that dulls the target's ATK.", "damage_single", {"mult": 2.4, "debuff": [["atk", -10]], "dturns": 2}],
		["ward_shatter", "Ward Shatter", "Shatters one foe's ward and cracks its Armor.", "damage_single", {"mult": 2.6, "debuff": [["armor", -8]], "dturns": 2}],
		["runic_guard", "Runic Guard", "Carves breaking runes into his armor: Defense and Armor up.", "buff_self", {"buffs": [["def", 18], ["armor", 8]], "turns": 2}],
		["spellsplitter", "Spellsplitter", "A null arc that splits the air across every enemy.", "damage_all_enemies", {"mult": 1.6}],
		["silence_seal", "Silence Seal", "Seals one foe's power: a big hit and a heavy ATK drop.", "damage_single", {"mult": 3.4, "debuff": [["atk", -18]], "dturns": 2}],
		["antimagic_field", "Anti-Magic Field", "A null field covers the squad: party Defense and Armor up.", "buff_party", {"buffs": [["def", 15], ["armor", 6]], "turns": 2}],
		["sunder_wards", "Sunder Wards", "Tears through every enemy's wards, lowering their Armor.", "damage_all_enemies", {"mult": 2.2, "debuff": [["armor", -8]], "dturns": 2}],
		["mana_rend", "Mana Rend", "Rips the power out of one foe and turns it into his own ATK.", "damage_single", {"mult": 4.4, "self_buff": [["atk", 15]], "sturns": 2}],
		["breaking_storm", "Breaking Storm", "A storm of null blades batters all foes and dulls their ATK.", "damage_all_enemies", {"mult": 2.8, "debuff": [["atk", -12]], "dturns": 2}],
		["spellbreak", "Spellbreak", "Capstone. Breaks every guard at once: a huge hit that strips Defense and Armor.", "damage_all_enemies", {"mult": 3.4, "debuff": [["def", -15], ["armor", -8]], "dturns": 2}],
	]},
	"Paladin": {"hero": "Christian", "rows": [
		["holy_strike", "Holy Strike", "A consecrated swing that lands in a flash of holy light.", "damage_single", {"mult": 2.4}],
		["lay_on_hands", "Lay on Hands", "Lays a healing hand on one ally, mending a large amount of damage.", "heal_single", {"pct": 0.40}],
		["aegis_of_light", "Aegis of Light", "Raises a shield of light: Defense and Armor up.", "buff_self", {"buffs": [["def", 20], ["armor", 8]], "turns": 2}],
		["consecrate", "Consecrate", "Blesses the ground and burns every enemy on it.", "damage_all_enemies", {"mult": 1.6}],
		["devotion_aura", "Devotion Aura", "Faith steadies the whole line: party Defense up.", "buff_party", {"buffs": [["def", 15]], "turns": 2}],
		["judgment", "Judgment", "Judges one foe: a heavy hit that lowers its ATK.", "damage_single", {"mult": 4.0, "debuff": [["atk", -15]], "dturns": 2}],
		["healing_light", "Healing Light", "Light washes over the squad, healing everyone.", "heal_party", {"pct": 0.25}],
		["crusader_charge", "Crusader Charge", "Charges the enemy line and rallies the party (ATK up).", "damage_all_enemies", {"mult": 2.4, "party_buff": [["atk", 10]], "pturns": 2}],
		["divine_shield", "Divine Shield", "Shields the whole party: big Defense and Armor for three turns.", "buff_party", {"buffs": [["def", 25], ["armor", 10]], "turns": 3}],
		["radiant_dawn", "Radiant Dawn", "Capstone. A holy dawn floods the party with a large heal and makes it hard to break.", "heal_party", {"pct": 0.50, "party_buff": [["def", 15], ["armor", 8]], "pturns": 3}],
	]},
	"Warlock": {"hero": "Wiesen", "rows": [
		["shadow_bolt", "Shadow Bolt", "Hurls a bolt of living shadow that bites into one foe.", "damage_single", {"mult": 2.6}],
		["curse_of_weakness", "Curse of Weakness", "Curses one foe: a hit and ATK down.", "damage_single", {"mult": 2.0, "debuff": [["atk", -15]], "dturns": 2}],
		["dark_pact", "Dark Pact", "Makes a dark pact: ATK and Crit up.", "buff_self", {"buffs": [["atk", 18], ["crit", 10]], "turns": 2}],
		["hex_cloud", "Hex Cloud", "A drifting cloud of hexes washes over every enemy.", "damage_all_enemies", {"mult": 1.6}],
		["soul_siphon", "Soul Siphon", "Siphons the enemy's will: all foes lose ATK and the party gains it.", "damage_all_enemies", {"mult": 1.4, "debuff": [["atk", -10]], "dturns": 2, "party_buff": [["atk", 10]], "pturns": 2}],
		["mark_of_doom", "Mark of Doom", "Marks one foe for doom: a heavy hit and big Defense down.", "damage_single", {"mult": 4.0, "debuff": [["def", -20]], "dturns": 2}],
		["wave_of_agony", "Wave of Agony", "A wave of agony hits all foes and slows them.", "damage_all_enemies", {"mult": 2.2, "debuff": [["speed", -12]], "dturns": 2}],
		["eldritch_focus", "Eldritch Focus", "Opens to the void: huge ATK and Crit.", "buff_self", {"buffs": [["atk", 30], ["crit", 15]], "turns": 2}],
		["chaos_rift", "Chaos Rift", "Tears a chaos rift under every enemy and cracks their Armor.", "damage_all_enemies", {"mult": 2.8, "debuff": [["armor", -8]], "dturns": 2}],
		["void_eclipse", "Void Eclipse", "Capstone. The void swallows one foe: enormous damage that breaks its guard.", "damage_single", {"mult": 6.6, "debuff": [["def", -25]], "dturns": 2}],
	]},
}
