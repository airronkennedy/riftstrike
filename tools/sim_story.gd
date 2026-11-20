extends SceneTree
## Story-fight win rates (docs/STORY.md), in the style of tools/sim_balance.gd: AUTO fights at 1x, no gear,
## the default Attack Order (party order), the party you actually have at that point of the story,
## and foes from Story.encounter_for(id, level) exactly as the game builds them.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . -s res://tools/sim_story.gd -- --n=60 [--ids=a,b] [--off=0,1] [--seed=1]
## --mult=SIZE:HP:ATK or --mult=FIGHT_ID:HP:ATK overrides the story data while tuning.
## --off: party level offsets from each fight's recommended level (0 = at rec, 1 = one above).
## The final boss also runs as a chain: phase 1, then phase 2 with the HP that is left (the way the story plays it).
const PARTY := {
	"fight_grieve": ["bramwell", "grieve"],
	"fight_halvard": ["bramwell", "grieve", "halvard"],
	"fight_bell": ["bramwell", "grieve", "halvard"],
	"fight_engine": ["bramwell", "grieve", "halvard", "corvin"],
	"fight_cardinal": ["bramwell", "grieve", "halvard", "corvin", "ilsabet"],
}
const ALL := ["bramwell", "grieve", "halvard", "corvin", "ilsabet"]
const SD = preload("res://scripts/story/story_data.gd")
var g
var st
var Q

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func setup_party(ids: Array, L: int) -> void:
	st._recruited = ids.duplicate()
	st.started = true
	# Same party gate as game.gd build_af_roster (which can only run once): the recruited keepers, in order.
	var names: Array = []
	for id in ids: names.append(str(id).capitalize())
	g.HERO_NAMES = names
	g.SQUAD = names.duplicate()
	g.HERO_ORDER = []
	g.ensure_hero_data()
	g.CLASS_XP = {}; g.SUB_XP = {}
	for h in g.party_names():
		g.set_hero_level(h, L)
		g.SUB_XP[h] = {str(g.CHAR[h].sub): Q.xp_floor(L)}
		g.HERO_MP[h] = 0.0

## One AUTO fight. Returns [won, hp share left].
## MP starts empty like tools/sim_balance.gd, except phase 2 of the final boss, which keeps phase 1's MP.
func fight(id: String, L: int, hp: float, keep_mp: bool = false) -> Array:
	if not keep_mp:
		for h in g.party_names(): g.HERO_MP[h] = 0.0
	var qf = root.get_node("QuestFlow")
	qf.in_kingdom_battle = true
	var e: Dictionary = st.encounter_for(id, L)
	g.encounter = e
	g.boss = null
	g.new_battle()
	var bid := BossDefs.id_for(e) # boss fights get the BossFight layer, as game.gd does on the story path
	if bid != "":
		g.boss = BossFight.new(bid); g.boss.setup(g)
	for u in g.G.units:
		if u.team == "blue": u.hp = maxi(1, int(roundf(float(u.maxhp) * hp))); u.shown_hp = u.hp
	g.phase = "battle"; g.screen = ""; g.AUTO = true
	g.begin_timeline()
	var guard := 0
	while g.phase == "battle" and guard < 40000:
		g.step(17); guard += 1
	var tot := 0.0; var mx := 0.0
	for u in g.G.units:
		if u.team == "blue": tot += maxf(0.0, u.hp); mx += u.maxhp
	while g.phase == "ending" and guard < 60000:
		g.step(17); guard += 1
	return [g.G.result == "win", tot / maxf(1.0, mx)]

## Wild fights the way QuestFlow builds them in the kingdom, for a party of `size` (Story.max_foes caps the foes).
func wild(size: int, L: int, n: int) -> Array:
	var regions := {1: "meadow", 2: "road", 3: "road", 4: "forest", 5: "forest", 6: "shore", 7: "shore", 8: "highlands", 9: "highlands", 10: "highlands"}
	var qf = root.get_node("QuestFlow")
	var w := 0; var hpl := 0.0
	for i in n:
		var mp: Dictionary = g.HERO_MP.duplicate() # wild fights carry MP from fight to fight, as in the kingdom
		setup_party(ALL.slice(0, size), L)
		g.HERO_MP = mp
		qf.in_kingdom_battle = true
		g.encounter = qf.encounter_for(regions[L], Q.foe_level(L))
		g.new_battle()
		g.phase = "battle"; g.screen = ""; g.AUTO = true
		g.begin_timeline()
		var guard := 0
		while g.phase == "battle" and guard < 40000:
			g.step(17); guard += 1
		var tot := 0.0; var mx := 0.0
		for u in g.G.units:
			if u.team == "blue": tot += maxf(0.0, u.hp); mx += u.maxhp
		while g.phase == "ending" and guard < 60000:
			g.step(17); guard += 1
		if g.G.result == "win": w += 1
		hpl += tot / maxf(1.0, mx)
	return [100.0 * w / n, 100.0 * hpl / n]

func _run() -> void:
	# --mult=SIZE:HP:ATK,... overrides StoryData.PARTY_FOE_MULT while tuning
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mult="):
			for m in a.substr(7).split(","):
				var p := m.split(":")
				var key: Variant = int(p[0]) if p[0].is_valid_int() else p[0] # party size, or a fight id
				root.get_node("Story").mult_override[key] = {"hp": float(p[1]), "atk": float(p[2])}
	var n := 60
	var ids: Array = SD.BATTLES.keys()
	var offs: Array = [0, 1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
		elif a.begins_with("--ids="): ids = Array(a.substr(6).split(","))
		elif a.begins_with("--off="):
			offs = []
			for s in a.substr(6).split(","): offs.append(int(s))
	Q = load("res://scripts/quest_rpg.gd")
	st = root.get_node("Story")
	st.battle_stub = true
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	g = current_scene
	g.sfx.muted = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wild="): # e.g. --wild=1:1,1:2,2:2,3:3 (party size:level)
			for pr in a.substr(7).split(","):
				var r := wild(int(pr.get_slice(":", 0)), int(pr.get_slice(":", 1)), n)
				print("wild  party %d  lvl %2d   win %3d%%   hp left %3d%%" % [int(pr.get_slice(":", 0)), int(pr.get_slice(":", 1)), int(r[0]), int(r[1])])
			quit()
			return
	print("fight              party  lvl  foes                                   win%  hp left")
	for id in ids:
		var b: Dictionary = SD.BATTLES[id]
		var party: Array = PARTY.get(id, ALL)
		for off in offs:
			var L: int = clampi(int(b.rec) + int(off), 1, 10)
			setup_party(party, L)
			var w := 0; var hpl := 0.0; var foes := ""
			for i in n:
				setup_party(party, L) # fresh levels every fight (wins give EXP, which would level the party up)
				var r := fight(id, L, 1.0)
				if r[0]: w += 1
				hpl += float(r[1])
				if i == 0:
					var fs: Array = []
					for u in g.G.units: if u.team == "red": fs.append("%s(%s)" % [u.name, str(u.tier).left(4)])
					foes = ", ".join(fs)
					if OS.has_environment("SIM_DEBUG"):
						for u in g.G.units: print("   ", u.team, " ", u.name, " lv", u.get("level") if "level" in u else "?", " hp ", u.maxhp, " atk ", u.atk, " def ", u.get("def") if "def" in u else "?", " tier ", u.tier)
			print("%-18s %5d  %3d  %-38s %4d%%   %4d%%" % [id, party.size(), L, foes.left(38), int(roundf(100.0 * w / n)), int(roundf(100.0 * hpl / n))])
	if ids.has("boss_regnant") and ids.has("boss_sovereign"):
		for off in offs:
			for spare in [false, true]:
				var L1 := clampi(int(SD.BATTLES.boss_regnant.rec) + int(off), 1, 10)
				var L2 := clampi(int(SD.BATTLES.boss_sovereign.rec) + int(off), 1, 10)
				var w1 := 0; var w2 := 0
				if spare: st.flags["c5_spare"] = true
				else: st.flags.erase("c5_spare")
				for i in n:
					setup_party(ALL, L1)
					var r1 := fight("boss_regnant", L1, 1.0)
					if not r1[0]: continue
					w1 += 1
					var hp: float = st.phase2_hp(Q.hp_after_battle(true, float(r1[1])), spare)
					var mp: Dictionary = g.HERO_MP.duplicate()
					setup_party(ALL, L2)
					g.HERO_MP = mp
					var r2 := fight("boss_sovereign", L2, hp, true)
					if r2[0]: w2 += 1
				print("final chain lv %d/%d %s: phase 1 %d%%, phase 2 after a phase-1 win %d%%, both in one go %d%%" % [L1, L2,
					"spare" if spare else "leave", int(roundf(100.0 * w1 / n)), int(roundf(100.0 * w2 / maxf(1.0, w1))), int(roundf(100.0 * w2 / n))])
	root.get_node("QuestFlow").in_kingdom_battle = false
	quit()
