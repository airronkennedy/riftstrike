class_name ComboTurn
extends RefCounted
## Runs one team turn: every unit attacks in order, multi-hit, timed by Combo data + jitter; resolves Sparks.
## Units are moved here (dash in, windup, jabs, run home); the game draws them. See docs/COMBO.md.

var running := false
var team := "blue"
var clock := 0.0
var strikes: Array = []
var projs: Array = []          # visual-only Proj objects (arrows / bolts), drawn by game.draw_projectile
var hist := {}                 # target id -> Array of [time, unit] landed hits
var hits := 0
var sparks := 0
var dmg := 0
var end_t := 0.0
var last_spark_pop := {}       # target id -> clock of the last SPARK! pop
var last_hitstop := -1e9
var rng := RandomNumberGenerator.new()

func start(g, side: String, order: Array, delays: Dictionary, focus) -> void:
	team = side; clock = 0.0; strikes = []; projs = []; hist = {}; hits = 0; sparks = 0; dmg = 0; last_spark_pop = {}; chain = {}; spark_txt = {}
	rng.randomize()
	var slot := 0
	for u in order:
		if u.dead: continue
		var s := _plan(g, u, slot, float(delays.get(u.name, 0.0)), focus)
		if not s.is_empty():
			strikes.append(s); slot += 1
	end_t = 0.0
	for s in strikes: end_t = maxf(end_t, float(s.end))
	running = not strikes.is_empty()

func _pick_target(g, u, focus):
	var foes: Array = g.alive(g.enemy_of(u))
	if foes.is_empty(): return null
	if u.team == "blue":
		if focus != null and not focus.dead and focus.team != u.team: return focus
		return g.bf_auto_target()
	return foes[rng.randi() % foes.size()]

func _plan(g, u, slot: int, delay: float, focus) -> Dictionary:
	var t = _pick_target(g, u, focus)
	if t == null: return {}
	var ab_id := ""
	var ab: Dictionary = {}
	if u.team == "blue" and u.gauge >= g.AB_MP and g.CHAR.has(u.name):
		ab_id = g.seq_pick(u)
		if ab_id != "": ab = g.ABILITY_DEFS[ab_id]
	var foe_bb: bool = u.team == "red" and u.gauge >= 100.0
	var f: Dictionary
	if u.team == "blue": f = Combo.frames(str(u.cls), ab)
	else:
		f = (Combo.FOE_FRAMES.ranged if str(u.K.ranged) != "" else Combo.FOE_FRAMES.melee).duplicate()
		if u.tier == "elite": f.hits = int(f.hits) + 1
		if foe_bb: f = _foe_bb(f)
	var kind: String = str(ab.get("kind", "attack"))
	var support: bool = ab_id != "" and not (kind == "damage_single" or kind == "damage_all_enemies")
	if support:
		f = f.duplicate(); f.style = "cast" if str(f.style) == "melee" else str(f.style); f.hits = 0; f.travel = 0.0
		if kind == "heal_single": t = u if bool(ab.params.get("self", false)) else g.lowest_ally(u)
		else: t = u
	var home := Vector2(u.hx, u.hy)
	var side: float = 1.0 if u.hx > t.x else -1.0
	var ap := Vector2(t.x + side * (float(u.K.range) + 34.0), t.y + 2.0) if str(f.style) == "melee" and not support else home + Vector2(-side * 34.0, 0)
	var t0: float = float(slot) * Combo.SLOT_STAGGER + delay
	var r := Combo.roll_hits(f, t0, home.distance_to(ap), rng)
	var times: Array = r.times
	var last: float = times[times.size() - 1] if not times.is_empty() else t0 + r.dash + r.wind
	var ret: float = (r.dash * 0.85) if str(f.style) == "melee" else 150.0
	var s := {"u": u, "f": f, "t0": t0, "dash": r.dash, "wind": r.wind, "travel": r.travel, "times": times, "next": 0, "shot": 0,
		"target": t, "all": kind == "damage_all_enemies", "ab": ab_id, "support": support, "foe_bb": foe_bb,
		"home": home, "ap": ap, "last": last, "ret": ret, "end": last + Combo.RECOVER + ret, "started": false, "first_hit": true}
	return s

func _foe_bb(f: Dictionary) -> Dictionary:
	var b := f.duplicate()
	b.hits = int(f.hits) * 2 + 1; b.windup = float(f.windup) * 1.3; b.interval = float(f.interval) * 0.8; b.mult = 2.2; b.bb = true
	return b

# ---------------------------------------------------------------- per frame
func update(g, dt: float) -> void:
	if not running: return
	clock += dt
	for s in strikes: _move(g, s)
	_fly(dt)
	# resolve hits in time order
	var due: Array = []
	for s in strikes:
		var times: Array = s.times
		while int(s.next) < times.size() and float(times[int(s.next)]) <= clock:
			due.append([float(times[int(s.next)]), s, int(s.next)])
			s.next = int(s.next) + 1
		if s.support and not s.get("done_fx", false) and clock >= float(s.t0) + float(s.dash) + float(s.wind):
			s.done_fx = true
			if not s.u.dead: g.ability_impact(s.u, str(s.ab), s.target)
	due.sort_custom(func(a, b): return a[0] < b[0])
	for d in due: _land(g, d[1], d[0], d[2])
	if clock >= end_t and projs.is_empty():
		running = false
		for s in strikes:
			var u = s.u
			if not u.dead:
				u.x = u.hx; u.y = u.hy; u.facing = g.home_facing(u); u.trail = []; u.bsq = 1.0

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _move(g, s: Dictionary) -> void:
	var u = s.u
	if u.dead: return
	var lt: float = clock - float(s.t0)
	if lt < 0.0: return
	var f: Dictionary = s.f
	var melee: bool = str(f.style) == "melee" and not s.support
	if not s.started:
		s.started = true
		_announce(g, s)
	var dash: float = s.dash
	var hit0: float = (float(s.times[0]) - float(s.t0)) if not s.times.is_empty() else dash + float(s.wind)
	var last: float = float(s.last) - float(s.t0)
	var home: Vector2 = s.home
	var ap: Vector2 = s.ap
	var tgt = s.target
	u.bsq = 1.0
	if lt < dash:
		var k := _ease(lt / maxf(1.0, dash))
		var p := home.lerp(ap, k)
		u.x = p.x; u.y = p.y - (sin(k * PI) * 18.0 if melee else 0.0)
		u.anim = "run"; u.bsq = 0.9 if melee else 1.0
		if melee: _trail(u)
	elif lt < hit0:
		# anticipation: pull back and squash, then spring
		var w: float = (lt - dash) / maxf(1.0, hit0 - dash)
		var back: float = sin(w * PI) * (10.0 if melee else 5.0)
		var dirx: float = signf(ap.x - home.x) if absf(ap.x - home.x) > 1.0 else float(-g.home_facing(u))
		u.x = ap.x - dirx * back; u.y = ap.y
		u.bsq = 1.0 - 0.1 * sin(w * PI)
		if s.ab != "" or s.foe_bb:
			if int(clock / 60.0) % 2 == 0: u.flash = maxf(u.flash, 40.0)
	elif lt < last + Combo.RECOVER:
		var since := 1e9
		for tt in s.times:
			var d: float = clock - float(tt)
			if d >= 0.0: since = minf(since, d)
		var jab := maxf(0.0, 1.0 - since / 90.0)
		var dirx2: float = signf(ap.x - home.x) if absf(ap.x - home.x) > 1.0 else float(-g.home_facing(u))
		u.x = ap.x + dirx2 * jab * (16.0 if melee else 6.0); u.y = ap.y
		u.bsq = 1.0 + 0.12 * jab
	else:
		var k2 := _ease((lt - last - Combo.RECOVER) / maxf(1.0, float(s.ret)))
		var p2 := ap.lerp(home, k2)
		u.x = p2.x; u.y = p2.y - (sin(k2 * PI) * 12.0 if melee else 0.0)
		if k2 < 1.0:
			u.anim = "run"
			if melee: _trail(u)
		else:
			u.trail = []
	if tgt != null and not tgt.dead and lt < last + Combo.RECOVER and tgt != u:
		u.facing = 1 if tgt.x >= u.x else -1
	elif lt >= last + Combo.RECOVER:
		u.facing = 1 if home.x >= u.x else -1
		if absf(home.x - u.x) < 2.0: u.facing = g.home_facing(u)
	# ranged / cast shots leave so they arrive on the hit time
	if not melee and not s.support:
		while int(s.shot) < s.times.size() and clock >= float(s.times[int(s.shot)]) - float(s.travel):
			_shoot(g, s, int(s.shot)); s.shot = int(s.shot) + 1

func _trail(u) -> void:
	u.trail.push_front(Vector2(u.x, u.y))
	if u.trail.size() > 5: u.trail.resize(5)

func _announce(g, s: Dictionary) -> void:
	var u = s.u
	if s.ab != "":
		var ab: Dictionary = g.ABILITY_DEFS[s.ab]
		var col: Color = g.ab_color(s.ab)
		u.gauge = 0.0
		g.fx.append({"type": "aura", "unit": u, "t": 0.0, "life": 900.0, "color": col})
		g.fx.append({"type": "ring", "x": u.x, "y": u.y - 10, "t": 0.0, "life": 520.0, "color": col})
		g.cast_banner = {"text": "BRAVE BURST · " + str(ab.name), "sub": u.name + " · " + g.ab_effect_line(s.ab), "t": 0.0, "life": 1500.0, "color": col}
		g.screen_flash = {"color": col, "t": 0.0, "life": 220.0}
		g.sfx.special()
	elif s.foe_bb:
		u.gauge = 0.0
		g.add_text(u.x, u.y - u.K.head * g.uS(u) - 30, str(u.K.get("special", "Special")) + "!", "#ffb27a", 18, 1000, true)
		g.fx.append({"type": "ring", "x": u.x, "y": u.y - 20, "t": 0.0, "life": 380.0, "color": Color("#ff9a4a")})
		g.sfx.special()

func _shoot(g, s: Dictionary, i: int) -> void:
	var u = s.u
	var t = s.target
	if t == null or t.dead: t = _retarget(g, s)
	if t == null: return
	var p = g.Proj.new()
	var cast: bool = str(s.f.style) == "cast"
	p.kind = "bolt" if cast else "arrow"
	p.special = s.ab != "" or s.foe_bb
	if cast:
		p.sx = t.x + rng.randf_range(-40, 40); p.sy = t.y - 300.0
	else:
		p.sx = u.x + u.facing * 22.0; p.sy = u.y - 36.0 + rng.randf_range(-6, 6)
	p.x = p.sx; p.y = p.sy; p.tx = t.x; p.ty = t.y - 30.0
	p.dur = maxf(60.0, float(s.travel)); p.t = 0.0
	p.ang = atan2(p.ty - p.sy, p.tx - p.sx)
	projs.append(p)
	if i % 2 == 0: g.sfx.shoot()

func _fly(dt: float) -> void:
	var dt_keep := []
	for p in projs:
		p.t += dt
		var k := minf(1.0, p.t / p.dur)
		p.x = p.sx + (p.tx - p.sx) * k; p.y = p.sy + (p.ty - p.sy) * k
		if k < 1.0: dt_keep.append(p)
	projs = dt_keep

func _retarget(g, s: Dictionary):
	var u = s.u
	var nt = g.bf_auto_target() if u.team == "blue" else null
	if nt == null:
		var foes: Array = g.alive(g.enemy_of(u))
		if foes.is_empty(): return null
		nt = foes[rng.randi() % foes.size()]
	s.target = nt
	return nt

## Is another unit's hit on t within the spark window of time tm (landed or still to come)?
func _sparks(t, tm: float, who) -> bool:
	for h in hist.get(t.id, []):
		if h[1] != who and absf(tm - float(h[0])) <= Combo.SPARK_WINDOW: return true
	for s in strikes:
		if s.u == who or s.u.dead or s.support: continue
		if not (s.all or s.target == t): continue
		var times: Array = s.times
		for i in range(int(s.next), times.size()):
			var d: float = float(times[i]) - tm
			if d > Combo.SPARK_WINDOW: break
			if d >= -Combo.SPARK_WINDOW: return true
	return false

func _land(g, s: Dictionary, tm: float, i: int) -> void:
	var u = s.u
	if u.dead: return
	var targets: Array = []
	if s.all:
		targets = g.alive(g.enemy_of(u))
	else:
		var t = s.target
		if t == null or t.dead: t = _retarget(g, s)
		if t != null: targets = [t]
	if targets.is_empty(): return
	var f: Dictionary = s.f
	var n: int = maxi(1, int(f.hits))
	if s.first_hit and s.ab != "":
		var p: Dictionary = g.ABILITY_DEFS[s.ab].params
		if p.has("debuff"):
			for t2 in targets: g.apply_mod_list(t2, p.debuff, int(p.get("dturns", 2)), true)
		if p.has("self_buff"): g.apply_mod_list(u, p.self_buff, int(p.get("sturns", 2)), true)
		if p.has("party_buff"):
			for m in g.alive(u.team): g.apply_mod_list(m, p.party_buff, int(p.get("pturns", 2)), true)
	s.first_hit = false
	for t in targets:
		if t.dead: continue
		var sp := _sparks(t, tm, u)
		var crit: bool = rng.randf() < clampf(float(u.crit) / 100.0, 0.0, 0.6)
		var raw: float = float(u.atk) * float(f.mult) / float(n) * g.surge_mult() * (1.5 if crit else 1.0)
		var after: float = raw * g.def_mit(float(t.def))
		var cut: float = maxf(after - float(t.armor) / float(n), after * g.ARMOR_FLOOR)
		var d: int = maxi(1, int(roundf(cut * (Combo.SPARK_MULT if sp else 1.0))))
		_apply(g, u, t, d, sp, crit, s, i == n - 1)

## One running damage total per target this turn: re-pops on every hit (Brave Frontier's chained number).
var chain := {}
var spark_txt := {}
func _chain(g, t, d: int, top: float, sp: bool) -> void:
	var c: Dictionary = chain.get(t.id, {})
	var sum: int = int(c.get("sum", 0)) + d
	var tx: Dictionary = c.get("txt", {})
	if tx.is_empty() or g.texts.find(tx) < 0:
		tx = {"x": t.x, "y": top - 6.0, "s": "", "color": Color("#ffd36a"), "size": 20.0, "t": 0.0, "life": 1100.0, "pop": true, "still": true}
		g.texts.append(tx)
	tx.s = str(sum)
	tx.t = 0.0
	tx.size = minf(30.0, 18.0 + sqrt(float(sum)) * 0.35)
	tx.color = Color("#d8ff7a") if sp else Color("#ffd36a")
	chain[t.id] = {"sum": sum, "txt": tx}

func _apply(g, u, t, d: int, sp: bool, crit: bool, s: Dictionary, last: bool) -> void:
	t.hp = maxi(0, t.hp - d)
	u.dmg += d
	if g.combat_trace != null:
		g.combat_trace.append({"turn": g.G.turn, "src": u.name, "dst": t.name, "dmg": d, "combo": sp, "spark": sp, "ab": s.ab != "", "crit": crit, "splash": false, "special": s.foe_bb})
	if not hist.has(t.id): hist[t.id] = []
	hist[t.id].append([clock, u])
	if team == "blue":
		hits += 1; dmg += d
		if sp: sparks += 1
	g.gain_mp(u, Combo.BB_PER_HIT + (Combo.BB_PER_SPARK if sp else 0.0))
	g.gain_mp(t, Combo.BB_PER_TAKEN)
	t.flash = maxf(t.flash, 55.0 if sp else 35.0)
	t.shake = maxf(t.shake, 160.0 if sp else 110.0)
	t.kx = (1.0 if t.x >= u.x else -1.0) * (10.0 if sp else 5.0)
	var hy: float = t.y - t.K.head * g.uS(t) * 0.55
	var top: float = t.y - t.K.head * g.uS(t) - 18.0
	# per-hit number: small, zig-zagging out from the hit point and rising (chained numbers)
	var zig: float = (1.0 if (int(s.next) % 2) == 0 else -1.0) * rng.randf_range(22.0, 50.0)
	var col := "#d8ff7a" if sp else ("#ff9a4a" if crit else "#fff4e0")
	g.add_text(t.x + zig, hy + rng.randf_range(-18.0, 8.0), str(d) + ("!" if crit else ""), col, 14 if sp else (14 if crit else 11), 440, crit)
	_chain(g, t, d, top, sp)
	if str(s.f.style) == "melee" and not s.support:
		g.fx.append({"type": "slash", "x": t.x + rng.randf_range(-10, 10), "y": hy + rng.randf_range(-14, 14), "t": 0.0, "life": 200.0, "dir": u.facing if int(s.next) % 2 == 0 else -u.facing})
	g.fx.append({"type": "spark", "x": t.x - t.kx * 2, "y": hy, "t": 0.0, "life": 220.0 if sp else 150.0, "big": sp or crit, "rot": rng.randf() * 6})
	if sp:
		var lp: float = float(last_spark_pop.get(t.id, -1e9))
		if clock - lp > 150.0:
			last_spark_pop[t.id] = clock
			# one SPARK! callout per target that re-pops (no stacked duplicates)
			var st: Dictionary = spark_txt.get(t.id, {})
			if st.is_empty() or g.texts.find(st) < 0:
				st = {"x": t.x, "y": top - 40.0, "s": "SPARK!", "color": Color("#b8ff6a"), "size": 24.0, "t": 0.0, "life": 700.0, "pop": true, "still": true}
				g.texts.append(st)
				spark_txt[t.id] = st
			st.t = 0.0
			st.x = t.x + rng.randf_range(-6, 6)
			g.fx.append({"type": "ring", "x": t.x, "y": hy + 10, "t": 0.0, "life": 300.0, "color": Color("#c8ff7a")})
		g.fx.append({"type": "burst", "x": t.x, "y": hy, "t": 0.0, "life": 380.0, "seed": rng.randi(), "color": Color("#d8ff8a")})
		g.shake(4.5, 120)
		g.cam_punch = maxf(g.cam_punch, 1.0)
		if clock - last_hitstop > 110.0:
			last_hitstop = clock; g.hitstop = maxf(g.hitstop, 28.0)
		# rising chime: pitch climbs with the turn's spark count
		g.sfx.tone(880.0 + minf(float(sparks), 30.0) * 28.0 + rng.randf_range(0, 40), 0.045, "triangle", 0.028, 1.5)
	else:
		g.sfx.hit()
	if crit and not sp: g.shake(3.0, 90)
	if t.hp <= 0:
		t.dead = true; t.death_t = 0.0; t.act = null; t.burn = null; u.kos += 1
		g.add_text(t.x, t.y - t.K.head * g.uS(t) - 44, "KO!", "#ff5a5a", 22, 900, true)
		g.hitstop = maxf(g.hitstop, 80.0)
		g.sfx.ko(); g.shake(6, 180); g.cam_punch = maxf(g.cam_punch, 1.4)
