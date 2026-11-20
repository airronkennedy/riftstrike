class_name BossFight
extends RefCounted
## One boss battle on the normal side-view auto battle (team turns, combos, battle camera). docs/BOSSES.md.
## game.gd keeps one of these in `boss` while a boss fight runs and calls the hooks below; everything else
## (timing, sparks, the Attack Order, the camera) is the shared combat code.
##
## Fight flow: intro cut-in (portrait, name, title, opening line) -> party / boss team turns. The boss attacks with
## its phase's hit frames, `acts` times a turn, and every `sig_every` turns (and on entering a phase) uses a
## signature attack with a telegraph: the camera holds on it, warning rings mark the targets, the name drops in.
## HP thresholds change phase (new frames, tighter spark window, more acts, a line). Non-spark hits are dulled by the
## ward; sparks fill the Break gauge (a Broken boss takes +10% and its next turn is one weak act). The killing blow slows time and holds the
## camera on the boss before the victory push-in.

const INTRO_MS := 3400.0
const PHASE_MS := 1500.0
const FINISH_MS := 1500.0
const FINISH_SLOW := 0.22
const END_EXTRA := 2600.0
const BROKEN_MULT := 1.1 # damage taken while Broken
const STAGGER_MULT := 0.75 # the Broken boss's one weak act

var id := ""
var d: Dictionary = {}
var unit = null # the boss Unit
var phase := 0
var phase_t := 1e9
var intro_t := 0.0
var intro_on := false
var break_g := 0.0
var broken := false
var stagger_t := 1e9
var boss_turns := 0
var sig_due := false
var tele: Dictionary = {} # {"sig", "name", "warn", "t", "life", "targets", "all"}
var sig_banner: Dictionary = {}
var finish_t := -1.0
var finisher = null
var line: Dictionary = {} # {"text", "t", "life"}
var ward_pop := {}
var t_all := 0.0
var won_shown := false
var stats := {"sparks_on_boss": 0, "hits_on_boss": 0, "breaks": 0, "phases": 0, "sigs": 0}

func _init(boss_id: String) -> void:
	id = boss_id
	d = BossDefs.get_def(boss_id)

func phase_def() -> Dictionary:
	var ph: Array = d.get("phases", [])
	return ph[clampi(phase, 0, ph.size() - 1)] if not ph.is_empty() else {}

func is_final() -> bool:
	return str(d.get("tier", "boss")) == "boss"

func color() -> Color:
	return Color(str(d.get("color", "#ff8a3d")))

# ---------------------------------------------------------------- setup (after new_battle)
func setup(g) -> void:
	var reds: Array = g.G.units.filter(func(u): return u.team == "red")
	if reds.is_empty(): return
	unit = reds[0]
	for u in reds:
		if str(u.tier) == str(d.tier): unit = u; break
	unit.maxhp = maxi(1, int(roundf(float(unit.maxhp) * BossDefs.tune(id, "hp")))); unit.hp = unit.maxhp; unit.shown_hp = unit.maxhp
	unit.atk = maxi(1, int(roundf(float(unit.atk) * BossDefs.tune(id, "atk"))))
	unit.def = maxi(1, int(roundf(float(unit.def) * BossDefs.tune(id, "def"))))
	unit.scale *= float(d.get("scale", 1.0))
	unit.name = str(d.name)
	unit.gauge = 0.0
	# the boss holds the middle of its side; escorts flank it
	var c := Vector2.ZERO
	for u in reds: c += Vector2(u.hx, u.hy)
	c /= float(reds.size())
	var others: Array = reds.filter(func(u): return u != unit)
	var front: float = 1.0 if c.x < g.LW * 0.5 else -1.0 # toward the party
	unit.hx = c.x - front * 10.0; unit.hy = c.y + 6.0
	for i in others.size():
		var o = others[i]
		o.hx = c.x + front * 70.0; o.hy = c.y + (-92.0 if i % 2 == 0 else 92.0)
	for u in reds:
		u.x = u.hx; u.y = u.hy; u.home0 = Vector2.INF
	if g.AREAS.has(str(d.area)): g.battle_area = str(d.area)

func begin(g) -> void:
	g.G.mode = "intro"
	intro_on = true; intro_t = 0.0
	say(str(BossDefs.lines(id).get("intro", "")), INTRO_MS + 600.0)
	g.banner = null
	g.sfx.tone(110, 0.5, "sawtooth", 0.05, 0.6)
	g.shake(5.0, 260)

func skip_intro() -> void:
	if intro_on: intro_t = maxf(intro_t, INTRO_MS - 260.0)

func intro_done() -> bool:
	return not intro_on

func say(text: String, life: float = 3200.0) -> void:
	if text == "": return
	line = {"text": text, "t": 0.0, "life": life}

# ---------------------------------------------------------------- per frame (game.step); returns the scaled dt
func tick(g, dt: float) -> float:
	t_all += dt
	if intro_on:
		intro_t += dt
		if intro_t >= INTRO_MS: intro_on = false
	phase_t += dt
	stagger_t += dt
	if not tele.is_empty():
		tele.t = float(tele.t) + dt
		if float(tele.t) > float(tele.life) + 400.0: tele = {}
	if not sig_banner.is_empty():
		sig_banner.t = float(sig_banner.t) + dt
		if float(sig_banner.t) > float(sig_banner.life): sig_banner = {}
	if not line.is_empty():
		line.t = float(line.t) + dt
		if float(line.t) > float(line.life): line = {}
	for k in ward_pop.keys():
		ward_pop[k] = float(ward_pop[k]) - dt
	if finish_t >= 0.0:
		finish_t += dt
		if finish_t < FINISH_MS * 0.6: return dt * FINISH_SLOW
	if g.phase == "ending" and not won_shown:
		won_shown = true
		var ln: Dictionary = BossDefs.lines(id)
		say(str(ln.get("victory", "")) if g.G.result == "win" else str(ln.get("defeat", "")), END_EXTRA + 1200.0)
	return dt

func end_extra() -> float:
	return END_EXTRA

# ---------------------------------------------------------------- turn planning (combo_turn hooks)
func owns(u) -> bool:
	return u != null and u == unit

## Called at the start of the boss side's team turn with the order; returns the order to use.
func enemy_order(g, order: Array) -> Array:
	if unit == null or unit.dead: return order
	var out: Array = order.filter(func(u): return u != unit)
	staggered = false
	if broken:
		# Broken: this turn the boss only manages one weak, plain act (no signature)
		broken = false; staggered = true
		g.add_text(unit.x, unit.y - float(unit.K.head) * g.uS(unit) - 40.0, "STAGGERED", "#9fd8ff", 20, 1100, true)
		out.push_front(unit)
		return out
	boss_turns += 1
	var every: int = maxi(1, int(phase_def().get("sig_every", 3)))
	if boss_turns % every == 0: sig_due = true
	out.push_front(unit)
	return out

var staggered := false

func acts(g) -> int:
	return 1 if staggered else maxi(1, int(phase_def().get("acts", 1)))

## The boss's strike for this act: frames, target and telegraph. act = 0 for the first strike of the turn.
func plan(g, act: int) -> Dictionary:
	var pd: Dictionary = phase_def()
	var party: Array = g.alive("blue")
	if party.is_empty(): return {}
	if act == 0 and sig_due and not staggered:
		sig_due = false
		var sigs: Array = pd.get("sig", [])
		if not sigs.is_empty():
			var sid: String = str(sigs[(boss_turns / maxi(1, int(pd.get("sig_every", 3)))) % sigs.size()])
			var sd: Dictionary = BossDefs.SIGNATURES.get(sid, {})
			if not sd.is_empty():
				var tgt = party[randi() % party.size()]
				var targets: Array = party.duplicate()
				if str(sd.target) == "back":
					var ord: Array = g.bf_order("blue")
					tgt = ord[ord.size() - 1] if not ord.is_empty() else tgt
				if str(sd.target) != "all": targets = [tgt]
				var tl: float = float(sd.telegraph)
				tele = {"sig": sid, "name": str(sd.name), "warn": str(sd.get("warn", "")), "t": 0.0, "life": tl, "targets": targets, "all": str(sd.target) == "all"}
				sig_banner = {"name": str(sd.name), "warn": str(sd.get("warn", "")), "t": 0.0, "life": tl + 500.0}
				stats.sigs = int(stats.sigs) + 1
				g.sfx.tone(196, 0.35, "sawtooth", 0.05, 0.7)
				g.banner = null # the signature strip replaces "ENEMY TURN"
				return {"f": (sd.frames as Dictionary).duplicate(), "target": tgt, "all": str(sd.target) == "all", "tele": tl, "sig": sid}
	var f: Dictionary = (pd.get("frames", Combo.FOE_FRAMES.melee) as Dictionary).duplicate()
	if staggered: f.mult = float(f.mult) * STAGGER_MULT
	return {"f": f, "target": party[randi() % party.size()], "all": false, "tele": 0.0, "sig": ""}

func spark_window(t) -> float:
	if t == unit: return float(phase_def().get("spark_window", Combo.SPARK_WINDOW))
	return Combo.SPARK_WINDOW

# ---------------------------------------------------------------- damage hooks
## Damage the boss takes: dulled by the ward unless the hit sparked; more while Broken.
func damage_in(g, u, t, dmg: int, sp: bool) -> int:
	if t != unit: return dmg
	var m := 1.0 if sp else float(d.get("ward", 1.0))
	if broken: m *= BROKEN_MULT
	stats.hits_on_boss = int(stats.hits_on_boss) + 1
	if sp:
		stats.sparks_on_boss = int(stats.sparks_on_boss) + 1
		_fill_break(g)
	elif float(ward_pop.get("w", 0.0)) <= 0.0:
		ward_pop["w"] = 420.0
		g.add_text(t.x - 30.0, t.y - float(t.K.head) * g.uS(t) * 0.35, "WARD", "#a9b4c4", 12, 520, false)
	return maxi(1, int(roundf(float(dmg) * m)))

func _fill_break(g) -> void:
	if broken: return
	break_g += 1.0
	var need: float = float(d.get("break_need", 12))
	if break_g >= need:
		break_g = 0.0
		broken = true
		stats.breaks = int(stats.breaks) + 1
		stagger_t = 0.0
		g.add_text(unit.x, unit.y - float(unit.K.head) * g.uS(unit) - 56.0, "BREAK!", "#7fd8ff", 30, 1300, true)
		g.fx.append({"type": "ring", "x": unit.x, "y": unit.y - 30.0, "t": 0.0, "life": 520.0, "color": Color("#9fe0ff")})
		g.screen_flash = {"color": Color("#9fe0ff"), "t": 0.0, "life": 200.0}
		g.shake(6.0, 200); g.hitstop = maxf(g.hitstop, 70.0)
		g.sfx.tone(1320, 0.12, "triangle", 0.05, 0.5)

## After any hit lands on t (combo_turn._apply): phase thresholds and the finishing blow.
func after_hit(g, u, t) -> void:
	if t != unit: return
	if t.hp <= 0:
		if finish_t < 0.0:
			finish_t = 0.0; finisher = u
			tele = {}; sig_banner = {}; line = {}; phase_t = 1e9
			g.screen_flash = {"color": Color.WHITE, "t": 0.0, "life": 380.0}
			g.shake(9.0, 420); g.hitstop = maxf(g.hitstop, 140.0)
			g.cam_punch = maxf(g.cam_punch, 1.5)
			for i in 3:
				g.fx.append({"type": "ring", "x": t.x, "y": t.y - 40.0, "t": -float(i) * 120.0, "life": 700.0, "color": color().lightened(0.3)})
			g.fx.append({"type": "burst", "x": t.x, "y": t.y - 50.0, "t": 0.0, "life": 700.0, "seed": randi(), "color": color().lightened(0.4)})
			g.sfx.ko(); g.sfx.special()
			# the escort breaks and flees when its master falls
			for o in g.G.units:
				if o.team == "red" and not o.dead and o != unit:
					o.hp = 0; o.dead = true; o.death_t = 0.0; o.act = null
		return
	var frac: float = float(t.hp) / maxf(1.0, float(t.maxhp))
	var idx: int = BossDefs.phase_index(id, frac)
	if idx > phase and finish_t < 0.0: enter_phase(g, idx)

func enter_phase(g, idx: int) -> void:
	phase = idx; phase_t = 0.0
	stats.phases = int(stats.phases) + 1
	sig_due = true # a new phase opens with its signature
	var ph: Array = BossDefs.lines(id).get("phase", [])
	if idx - 1 < ph.size() and idx >= 1: say(str(ph[idx - 1]), 3000.0)
	g.screen_flash = {"color": color(), "t": 0.0, "life": 420.0}
	g.shake(7.0, 320); g.hitstop = maxf(g.hitstop, 90.0)
	unit.flash = maxf(unit.flash, 200.0)
	g.fx.append({"type": "ring", "x": unit.x, "y": unit.y - 20.0, "t": 0.0, "life": 650.0, "color": color()})
	g.fx.append({"type": "burst", "x": unit.x, "y": unit.y - 60.0, "t": 0.0, "life": 600.0, "seed": randi(), "color": color().lightened(0.2)})
	g.sfx.tone(98, 0.6, "sawtooth", 0.06, 1.8)

# ---------------------------------------------------------------- camera
func cam_focus(g) -> Dictionary:
	if unit == null: return {}
	var bp := Vector2(unit.x, unit.y - float(unit.K.head) * g.uS(unit) * 0.5)
	if intro_on:
		var k: float = clampf(intro_t / 900.0, 0.0, 1.0)
		return {"pos": bp, "w": 0.95, "z": 1.25 + 0.35 * k}
	if finish_t >= 0.0 and finish_t < FINISH_MS:
		return {"pos": bp, "w": 0.95, "z": 1.7}
	if phase_t < PHASE_MS * 0.8 and not unit.dead:
		return {"pos": bp, "w": 0.85, "z": 1.45}
	if not tele.is_empty() and float(tele.t) < float(tele.life):
		var k2: float = float(tele.t) / maxf(1.0, float(tele.life))
		var tp := bp
		if not tele.all and not (tele.targets as Array).is_empty():
			var tu = tele.targets[0]
			tp = Vector2(tu.x, tu.y - float(tu.K.head) * g.uS(tu) * 0.5)
		return {"pos": bp.lerp(tp, 0.55 * k2), "w": 0.8, "z": 1.35}
	return {}

# ---------------------------------------------------------------- drawing: world space (inside the camera)
func draw_world(g) -> void:
	if unit == null: return
	var pulse: float = 0.5 + 0.5 * sin(t_all / 120.0)
	# enrage aura in later phases
	if phase > 0 and not unit.dead:
		var c := color()
		for i in 3:
			g.fill_ellipse(unit.x, unit.y - 2.0, (60.0 + 10.0 * i + 6.0 * pulse) * unit.scale, (16.0 + 3.0 * i) * unit.scale, Color(c.r, c.g, c.b, 0.07 * float(phase)))
	# telegraph: pulsing danger rings under the targets, a line from the boss
	if not tele.is_empty() and float(tele.t) < float(tele.life) + 200.0:
		var k: float = clampf(float(tele.t) / maxf(1.0, float(tele.life)), 0.0, 1.0)
		var red := Color(1.0, 0.25, 0.18)
		for tu in tele.targets:
			if tu.dead: continue
			var r: float = 46.0 - 14.0 * k
			g.fill_ellipse(tu.x, tu.y - 2.0, r * 1.3, r * 0.42, Color(red.r, red.g, red.b, 0.12 + 0.18 * k))
			g.stroke_ellipse(tu.x, tu.y - 2.0, r * 1.3 + 4.0 * pulse, r * 0.42 + 1.5 * pulse, Color(1.0, 0.45, 0.3, 0.5 + 0.4 * k), 2.2)
			var hy: float = tu.y - float(tu.K.head) * g.uS(tu) - 30.0 - 4.0 * pulse
			g.text("!", tu.x, hy, 26.0, Color(1.0, 0.55, 0.3), "center", 4.0, Color(0.15, 0.02, 0.0, 0.95))
			if not tele.all:
				g.draw_dashed_line(Vector2(unit.x, unit.y - 40.0), Vector2(tu.x, tu.y - 30.0), Color(1.0, 0.4, 0.25, 0.35 + 0.4 * k), 2.0, 10.0)
		# charge glow on the boss
		for i in 4:
			g.fill_ellipse(unit.x, unit.y - float(unit.K.head) * g.uS(unit) * 0.5, (30.0 + 20.0 * k) * (1.0 - i * 0.2), (30.0 + 20.0 * k) * (1.0 - i * 0.2), Color(1.0, 0.5, 0.25, 0.05 + 0.05 * k))
	# Broken: little orbiting stars over the boss's head
	if broken and not unit.dead:
		var hy2: float = unit.y - float(unit.K.head) * g.uS(unit) - 12.0
		for i in 3:
			var a: float = t_all / 260.0 + TAU * float(i) / 3.0
			g.draw_circle(Vector2(unit.x + cos(a) * 22.0, hy2 + sin(a) * 6.0), 3.5, Color("#bfeaff"))

# ---------------------------------------------------------------- drawing: HUD (screen space)
func hud_h(g) -> float:
	return 58.0 * hud_k(g)

func hud_k(g) -> float:
	return clampf(minf(g.VHc, g.VWc * 1.25) / 560.0, 0.82, 1.25)

func draw_hud(g) -> void:
	if unit == null: return
	var k: float = hud_k(g)
	if intro_on:
		_draw_intro(g, k)
		return
	_draw_bar(g, k)
	if not sig_banner.is_empty(): _draw_sig(g, k)
	if phase_t < PHASE_MS: _draw_phase(g, k)
	if finish_t >= 0.0 and finish_t < FINISH_MS + 600.0: _draw_finish(g, k)
	if not line.is_empty(): _draw_line(g, k)

func _draw_bar(g, k: float) -> void:
	var port: bool = g.VHc > g.VWc
	var w: float = g.VWc - 16.0 if port else minf(620.0 * k, g.VWc * 0.56)
	var x: float = (g.VWc - w) / 2.0
	var y: float = g.SAFE_T + 6.0 * k
	var c := color()
	var r := Rect2(x, y, w, 50.0 * k)
	g.rbox(r, 12, Color(0.05, 0.04, 0.035, 0.88), Color.WHITE, 1.2, 4)
	# portrait diamond on the left
	var pc := Vector2(x + 26.0 * k, y + 25.0 * k)
	g.HUD.portrait(g, unit, pc, 20.0 * k, c.lightened(0.2), 2.0)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	var tag: String = "FINAL BOSS" if is_final() else "MINI-BOSS"
	g.text(str(d.name).to_upper(), x + 54.0 * k, y + 13.0 * k, g.fit_size(str(d.name).to_upper(), 14.0 * k, w * 0.55, 9.0), AfTheme.GOLD, "left")
	g._font_override = old
	g.text(tag + "  ·  " + str(phase_def().get("name", "")), r.end.x - 12.0 * k, y + 13.0 * k, 10.0 * k, c.lightened(0.3), "right")
	# big HP bar with phase ticks
	var br := Rect2(x + 54.0 * k, y + 25.0 * k, w - 66.0 * k, 11.0 * k)
	var hp: float = clampf(float(unit.hp) / maxf(1.0, float(unit.maxhp)), 0.0, 1.0)
	var shown: float = clampf(float(unit.shown_hp) / maxf(1.0, float(unit.maxhp)), 0.0, 1.0)
	g.draw_rect(br.grow(1.5), Color(0, 0, 0, 0.8))
	g.draw_rect(Rect2(br.position, Vector2(br.size.x * shown, br.size.y)), Color(1.0, 0.92, 0.75, 0.55))
	var hc := AfTheme.CORAL.lerp(c, 0.35)
	g.draw_rect(Rect2(br.position, Vector2(br.size.x * hp, br.size.y)), hc)
	g.draw_rect(Rect2(br.position, Vector2(br.size.x * hp, br.size.y * 0.4)), Color(1, 1, 1, 0.2))
	for ph in d.get("phases", []):
		var at: float = float(ph.at)
		if at >= 0.999: continue
		var tx: float = br.position.x + br.size.x * at
		g.draw_rect(Rect2(tx - 1.0, br.position.y - 3.0, 2.0, br.size.y + 6.0), AfTheme.GOLD)
	g.text("%d / %d" % [maxi(0, unit.hp), unit.maxhp], br.end.x - 4.0 * k, br.get_center().y, 9.0 * k, AfTheme.INK, "right", 3.0)
	# Break gauge (sparks fill it)
	var need: float = float(d.get("break_need", 12))
	var gb := Rect2(x + 54.0 * k, y + 40.0 * k, (w - 66.0 * k) * 0.5, 4.0 * k)
	g.draw_rect(gb.grow(1), Color(0, 0, 0, 0.75))
	var bv: float = 1.0 if broken else clampf(break_g / need, 0.0, 1.0)
	g.draw_rect(Rect2(gb.position, Vector2(gb.size.x * bv, gb.size.y)), Color("#7fd8ff"))
	g.text("BROKEN: next turn staggered" if broken else "BREAK  ·  sparks pierce the ward", gb.end.x + 8.0 * k, gb.get_center().y, 8.5 * k, Color("#9fd8ff") if broken else AfTheme.MUTED, "left")

func _draw_intro(g, k: float) -> void:
	var VW: float = g.VWc
	var VH: float = g.VHc
	var t: float = intro_t
	var inn: float = BattleHUDEase.out(clampf(t / 380.0, 0.0, 1.0))
	var outk: float = clampf((t - (INTRO_MS - 320.0)) / 320.0, 0.0, 1.0)
	var a: float = 1.0 - outk
	var c := color()
	g.save(); g._alpha = a
	g.draw_rect(Rect2(0, 0, VW, VH), Color(0, 0, 0, 0.35 * inn))
	var bar: float = VH * 0.12 * inn
	g.draw_rect(Rect2(0, 0, VW, bar), Color(0.01, 0.008, 0.006, 0.96))
	g.draw_rect(Rect2(0, VH - bar, VW, bar), Color(0.01, 0.008, 0.006, 0.96))
	# name plate slides in from the right across a colored band
	var port: bool = VH > VW
	var cy: float = VH * (0.62 if port else 0.66)
	var slide: float = BattleHUDEase.out(clampf((t - 200.0) / 450.0, 0.0, 1.0))
	var band_h: float = 92.0 * k
	g.draw_polygon(PackedVector2Array([Vector2(VW * (1.0 - slide), cy - band_h / 2.0), Vector2(VW, cy - band_h / 2.0), Vector2(VW, cy + band_h / 2.0), Vector2(VW * (1.0 - slide) - 40.0 * k, cy + band_h / 2.0)]),
		PackedColorArray([Color(0.05, 0.035, 0.03, 0.0), Color(0.05, 0.035, 0.03, 0.92), Color(0.05, 0.035, 0.03, 0.92), Color(0.05, 0.035, 0.03, 0.0)]))
	g.draw_rect(Rect2(VW * (1.0 - slide), cy - band_h / 2.0, VW * slide, 1.5), Color(c.r, c.g, c.b, 0.9))
	g.draw_rect(Rect2(VW * (1.0 - slide) - 40.0 * k, cy + band_h / 2.0 - 1.5, VW * slide + 40.0 * k, 1.5), Color(c.r, c.g, c.b, 0.9))
	var px: float = lerpf(VW + 80.0 * k, VW * (0.2 if port else 0.32), slide)
	g.HUD.portrait(g, unit, Vector2(px, cy), 44.0 * k, c.lightened(0.25), 2.5)
	var tx: float = px + 58.0 * k
	var old: Font = g._font_override
	var tag: String = "FINAL BOSS" if is_final() else "MINI-BOSS"
	g.text(tag, tx, cy - 30.0 * k, 11.0 * k, c.lightened(0.35), "left", 3.0, Color(0, 0, 0, 0.9))
	g._font_override = g.FONT_TITLE
	var nm: String = str(d.name).to_upper()
	g.text(nm, tx, cy - 6.0 * k, g.fit_size(nm, 30.0 * k, VW - tx - 12.0 * k, 14.0), AfTheme.GOLD, "left", 5.0, Color(0, 0, 0, 0.95))
	g._font_override = old
	g.text(str(d.title), tx, cy + 22.0 * k, g.fit_size(str(d.title), 14.0 * k, VW - tx - 12.0 * k, 9.0), AfTheme.INK, "left", 3.0, Color(0, 0, 0, 0.9))
	# opening line, typed out
	var ln: String = str(BossDefs.lines(id).get("intro", ""))
	if ln != "" and t > 700.0:
		var n: int = clampi(int((t - 700.0) / 22.0), 0, ln.length())
		_wrap_text(g, "\u201c" + ln.substr(0, n) + ("\u201d" if n >= ln.length() else ""), VW / 2.0, (cy + band_h / 2.0 + 34.0 * k) if port else (VH - bar - 34.0 * k), minf(VW - 40.0 * k, 640.0 * k), 13.0 * k, AfTheme.INK)
	g.text("tap to skip", VW - 14.0 * k, VH - bar / 2.0, 9.0 * k, AfTheme.MUTED, "right")
	g.restore()
	g.add_btn("boss_skip", Rect2(0, 0, VW, VH), func(): skip_intro())

func _draw_sig(g, k: float) -> void:
	var bt: float = float(sig_banner.t)
	var life: float = float(sig_banner.life)
	var inn: float = BattleHUDEase.out(clampf(bt / 180.0, 0.0, 1.0))
	var outk: float = clampf((bt - (life - 250.0)) / 250.0, 0.0, 1.0)
	var VW: float = g.VWc
	var y: float = g.SAFE_T + hud_h(g) + 34.0 * k
	var h: float = 54.0 * k * inn * (1.0 - outk)
	if h < 1.0: return
	var red := Color(1.0, 0.32, 0.22)
	g.draw_rect(Rect2(0, y - h / 2.0, VW, h), Color(0.12, 0.02, 0.015, 0.84))
	g.draw_rect(Rect2(0, y - h / 2.0, VW, 1.5), red)
	g.draw_rect(Rect2(0, y + h / 2.0 - 1.5, VW, 1.5), red)
	g.save(); g._alpha *= 1.0 - outk
	var sc: float = 1.0 + 0.25 * (1.0 - inn)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	g.text("\u26a0 " + str(sig_banner.name).to_upper(), VW / 2.0, y - 7.0 * k, 22.0 * k * sc, Color(1.0, 0.72, 0.55), "center", 4.0, Color(0, 0, 0, 0.95))
	g._font_override = old
	g.text(str(sig_banner.warn), VW / 2.0, y + 15.0 * k, 11.0 * k, AfTheme.INK, "center", 3.0, Color(0, 0, 0, 0.9))
	g.restore()

func _draw_phase(g, k: float) -> void:
	if phase == 0: return
	var VW: float = g.VWc
	var VH: float = g.VHc
	var a: float = clampf(phase_t / 160.0, 0.0, 1.0) * (1.0 - clampf((phase_t - (PHASE_MS - 300.0)) / 300.0, 0.0, 1.0))
	var c := color()
	g.save(); g._alpha = a
	var cy: float = VH * 0.42
	var w: float = minf(VW - 24.0, 460.0 * k)
	g.draw_polygon(g.af_chamfer(Rect2((VW - w) / 2.0, cy - 34.0 * k, w, 68.0 * k), 12.0 * k), PackedColorArray([Color(0.05, 0.035, 0.03, 0.9), Color(0.05, 0.035, 0.03, 0.9), Color(0.05, 0.035, 0.03, 0.9), Color(0.05, 0.035, 0.03, 0.9), Color(0.05, 0.035, 0.03, 0.9), Color(0.05, 0.035, 0.03, 0.9)]))
	g.draw_polyline(BattleHUDEase.closed(g.af_chamfer(Rect2((VW - w) / 2.0, cy - 34.0 * k, w, 68.0 * k), 12.0 * k)), c, 1.6, true)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	var sc: float = 1.0 + 0.3 * (1.0 - clampf(phase_t / 220.0, 0.0, 1.0))
	g.text("PHASE %d" % (phase + 1), VW / 2.0, cy - 12.0 * k, 24.0 * k * sc, c.lightened(0.35), "center", 4.0, Color(0, 0, 0, 0.95))
	g._font_override = old
	g.text(str(phase_def().get("name", "")).to_upper() + "  ·  new attack pattern", VW / 2.0, cy + 16.0 * k, 11.0 * k, AfTheme.INK, "center", 3.0)
	g.restore()

func _draw_finish(g, k: float) -> void:
	var VW: float = g.VWc
	var VH: float = g.VHc
	var ft: float = finish_t
	var a: float = clampf(ft / 120.0, 0.0, 1.0) * (1.0 - clampf((ft - FINISH_MS) / 600.0, 0.0, 1.0))
	g.save(); g._alpha = a
	# letterbox + radial darkening for the slow-motion beat
	var bar: float = VH * 0.08
	g.draw_rect(Rect2(0, 0, VW, bar), Color(0, 0, 0, 0.9))
	g.draw_rect(Rect2(0, VH - bar, VW, bar), Color(0, 0, 0, 0.9))
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	var sc: float = 1.0 + 0.4 * (1.0 - BattleHUDEase.out(clampf(ft / 260.0, 0.0, 1.0)))
	g.text("FINISHING BLOW", VW / 2.0, VH * 0.3, 34.0 * k * sc, AfTheme.GOLD, "center", 6.0, Color(0.1, 0.03, 0.0, 0.95))
	g._font_override = old
	if finisher != null:
		g.text(str(finisher.name).to_upper() + " ENDS " + str(d.name).to_upper(), VW / 2.0, VH * 0.3 + 30.0 * k, g.fit_size(str(finisher.name).to_upper() + " ENDS " + str(d.name).to_upper(), 13.0 * k, VW - 30.0, 8.0), AfTheme.INK, "center", 3.0)
	g.restore()

func _draw_line(g, k: float) -> void:
	if g.phase == "battle" and g.G.mode == "intro": return
	var lt: float = float(line.t)
	var life: float = float(line.life)
	var a: float = clampf(lt / 200.0, 0.0, 1.0) * (1.0 - clampf((lt - (life - 300.0)) / 300.0, 0.0, 1.0))
	var VW: float = g.VWc
	var port: bool = g.VHc > VW
	var w: float = VW - 20.0 if port else minf(560.0 * k, VW * 0.6)
	# low on the screen, just above the party cards (portrait: above the speed / AUTO bar)
	var y: float = g.VHc - g.SAFE_B - (238.0 if port else 140.0) * k
	g.save(); g._alpha = a
	var r := Rect2((VW - w) / 2.0, y, w, 52.0 * k)
	g.rbox(r, 12, Color(0.05, 0.04, 0.035, 0.86), Color.WHITE, 1.0, 4)
	g.HUD.portrait(g, unit, Vector2(r.position.x + 24.0 * k, r.get_center().y), 17.0 * k, color(), 1.6)
	var s: String = str(line.text)
	var n: int = clampi(int(lt / 20.0), 0, s.length())
	_wrap_text(g, s.substr(0, n), r.get_center().x + 18.0 * k, r.get_center().y, w - 70.0 * k, 11.5 * k, AfTheme.INK)
	g.restore()

## Centered text wrapped to max_w, vertically centered on y.
func _wrap_text(g, s: String, x: float, y: float, max_w: float, size: float, col: Color) -> void:
	var words: PackedStringArray = s.split(" ")
	var lines: Array = []
	var cur := ""
	for w in words:
		var tryl: String = w if cur == "" else cur + " " + w
		if g.text_w(tryl, size) > max_w and cur != "":
			lines.append(cur); cur = w
		else:
			cur = tryl
	if cur != "": lines.append(cur)
	var lh: float = size * 1.35
	var y0: float = y - (lines.size() - 1) * lh / 2.0
	for i in lines.size():
		g.text(str(lines[i]), x, y0 + i * lh, size, col, "center", 3.0, Color(0, 0, 0, 0.85))
