class_name Combo
extends RefCounted
## Brave Frontier-style team turns for Airron's Quest (docs/COMBO.md).
## On a team turn every unit attacks in its Attack Order. Each attack is multi-hit; every hit lands at a time set by
## its timing data (dash, windup, travel, hit interval) plus a little random jitter, so no two turns play out the same.
## When hits from DIFFERENT units land on the same target within SPARK_WINDOW ms they SPARK: +50% damage, more BB gauge,
## a SPARK! pop, shake, flash and particles. Slow, late-hitting units placed early and fast ones placed after them
## overlap their hit windows; a good order sparks far more than a random one.

# ---------------------------------------------------------------- tuning
const SPARK_WINDOW := 60.0    # ms: hits from two different units this close on one target spark
const SPARK_MULT := 1.5       # spark damage (Brave Frontier's base spark is 150%)
const SLOT_STAGGER := 540.0   # ms between attack-order slots
const DELAY_STEP := 50.0      # Build: per-keeper extra delay step
const DELAY_MAX := 500.0
const JIT_WINDUP := 0.15      # ± share of windup
const JIT_TRAVEL := 0.10      # ± share of travel
const JIT_INTERVAL := 0.14    # ± share of each gap between hits
const JIT_DASH := 0.08
const DASH_SPEED := 1500.0    # px/s melee dash
const NOMINAL_DASH := 180.0   # px, average real melee dash (measured), used by the Build preview
const RANGED_STEP := 120.0    # ms ranged/caster step-in
const RECOVER := 140.0        # ms after the last hit before running home
const BB_PER_HIT := 1.6       # BB gauge per hit landed
const BB_PER_SPARK := 2.6     # extra per sparked hit
const BB_PER_TAKEN := 0.9     # per hit taken
const BB_FULL := 100.0

## Normal attack timing per class. style: melee dashes in; ranged shoots (travel = arrow flight); cast drops spells.
## windup/interval/travel in ms. mult = share of ATK the whole attack deals (split over the hits).
const FRAMES := {
	"Warrior": {"style": "melee", "windup": 260.0, "hits": 4, "interval": 95.0, "travel": 0.0, "mult": 1.25},
	"Guardian": {"style": "melee", "windup": 340.0, "hits": 3, "interval": 140.0, "travel": 0.0, "mult": 1.05},
	"Knight": {"style": "melee", "windup": 300.0, "hits": 4, "interval": 110.0, "travel": 0.0, "mult": 1.15},
	"Rogue": {"style": "melee", "windup": 120.0, "hits": 7, "interval": 55.0, "travel": 0.0, "mult": 1.2},
	"Monk": {"style": "melee", "windup": 160.0, "hits": 8, "interval": 60.0, "travel": 0.0, "mult": 1.2},
	"Ranger": {"style": "ranged", "windup": 240.0, "hits": 5, "interval": 85.0, "travel": 260.0, "mult": 1.15},
	"Mage": {"style": "cast", "windup": 520.0, "hits": 4, "interval": 120.0, "travel": 220.0, "mult": 1.3},
	"Warlock": {"style": "cast", "windup": 440.0, "hits": 5, "interval": 100.0, "travel": 240.0, "mult": 1.25},
	"Cleric": {"style": "cast", "windup": 380.0, "hits": 3, "interval": 150.0, "travel": 200.0, "mult": 1.0},
	"Bard": {"style": "ranged", "windup": 300.0, "hits": 6, "interval": 75.0, "travel": 230.0, "mult": 1.1},
}
const FOE_FRAMES := {
	"melee": {"style": "melee", "windup": 280.0, "hits": 2, "interval": 130.0, "travel": 0.0, "mult": 1.0},
	"ranged": {"style": "ranged", "windup": 300.0, "hits": 2, "interval": 120.0, "travel": 260.0, "mult": 1.0},
}
## Brave Burst (a full BB gauge fires the keeper's ability from its Build plan): more hits, longer windup.
const BB_HITS_MULT := 2.0
const BB_HITS_ADD := 2
const BB_WINDUP_MULT := 1.0
const BB_INTERVAL_MULT := 0.8

# ---------------------------------------------------------------- timing data
static func frames(cls: String, ability: Dictionary = {}) -> Dictionary:
	var f: Dictionary = FRAMES.get(cls, FRAMES.Warrior).duplicate()
	if not ability.is_empty():
		var p: Dictionary = ability.get("params", {})
		f.hits = int(p.get("hits", int(f.hits) * BB_HITS_MULT + BB_HITS_ADD))
		f.windup = float(f.windup) * BB_WINDUP_MULT
		f.interval = float(f.interval) * BB_INTERVAL_MULT
		f.mult = float(p.get("mult", 1.0))
		f.bb = true
	return f

## Readable traits for Build: "7 hits · 0.33 s · Fast".
static func speed_tag(f: Dictionary) -> String:
	var onset := onset_ms(f)
	if onset < 350.0: return "Fast"
	if onset < 600.0: return "Steady"
	return "Slow"

static func onset_ms(f: Dictionary, dash_px: float = NOMINAL_DASH) -> float:
	var dash: float = dash_px / DASH_SPEED * 1000.0 if str(f.style) == "melee" else RANGED_STEP
	return dash + float(f.windup) + float(f.travel)

static func span_ms(f: Dictionary) -> float:
	return float(f.interval) * float(int(f.hits) - 1)

static func traits(f: Dictionary) -> String:
	return "%d hits · %.2fs · %s" % [int(f.hits), span_ms(f) / 1000.0, speed_tag(f)]

## Nominal hit window [first, last] ms from the start of the team turn, and its jitter spread (± ms).
static func window(f: Dictionary, slot: int, delay: float) -> Dictionary:
	var t0 := slot * SLOT_STAGGER + delay
	var first := t0 + onset_ms(f)
	var last := first + span_ms(f)
	var jit := float(f.windup) * JIT_WINDUP + float(f.travel) * JIT_TRAVEL
	return {"first": first, "last": last, "jit": jit, "jit_end": jit + span_ms(f) * JIT_INTERVAL * 0.5}

## One rolled set of hit times (ms from team-turn start). dash_px is the real distance for melee.
static func roll_hits(f: Dictionary, t0: float, dash_px: float, rng: RandomNumberGenerator) -> Dictionary:
	var dash: float
	if str(f.style) == "melee": dash = dash_px / DASH_SPEED * 1000.0 * (1.0 + rng.randf_range(-JIT_DASH, JIT_DASH))
	else: dash = RANGED_STEP
	var wind: float = float(f.windup) * (1.0 + rng.randf_range(-JIT_WINDUP, JIT_WINDUP))
	var trav: float = float(f.travel) * (1.0 + rng.randf_range(-JIT_TRAVEL, JIT_TRAVEL))
	var times: Array = []
	var tt := t0 + dash + wind + trav
	for i in int(f.hits):
		times.append(tt)
		tt += float(f.interval) * (1.0 + rng.randf_range(-JIT_INTERVAL, JIT_INTERVAL))
	return {"dash": dash, "wind": wind, "travel": trav, "times": times}

## Monte Carlo: share of hits that spark for an order (Array of frame dicts) with delays, all on one target.
static func spark_rate(order: Array, delays: Array, trials: int = 60, seed_v: int = 7) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tot := 0
	var sp := 0
	for _t in trials:
		var all: Array = []
		for i in order.size():
			var dl: float = float(delays[i]) if i < delays.size() else 0.0
			var r := roll_hits(order[i], i * SLOT_STAGGER + dl, NOMINAL_DASH * rng.randf_range(0.85, 1.15), rng)
			for h in r.times: all.append([float(h), i])
		all.sort_custom(func(a, b): return a[0] < b[0])
		for k in all.size():
			tot += 1
			if sparks_at(all, k): sp += 1
	return float(sp) / maxf(1.0, float(tot))

static func sparks_at(all: Array, k: int) -> bool:
	var tk: float = all[k][0]
	var who = all[k][1]
	var j := k - 1
	while j >= 0 and tk - float(all[j][0]) <= SPARK_WINDOW:
		if all[j][1] != who: return true
		j -= 1
	j = k + 1
	while j < all.size() and float(all[j][0]) - tk <= SPARK_WINDOW:
		if all[j][1] != who: return true
		j += 1
	return false

## Best order (by spark rate) among all permutations (party is small).
static func best_order(fr: Array, delays: Array) -> Array:
	var idx: Array = []
	for i in fr.size(): idx.append(i)
	var best: Array = idx.duplicate()
	var best_r := -1.0
	for p in _perms(idx):
		var o: Array = []
		var d: Array = []
		for i in p:
			o.append(fr[i]); d.append(delays[i])
		var r := spark_rate(o, d, 24)
		if r > best_r:
			best_r = r; best = p
	return best

static func _perms(a: Array) -> Array:
	if a.size() <= 1: return [a.duplicate()]
	var out: Array = []
	for i in a.size():
		var rest := a.duplicate(); rest.remove_at(i)
		for p in _perms(rest):
			out.append([a[i]] + p)
	return out

## Best order, then per-slot delays tuned one at a time (Build "Suggest" button). Returns {"order": [idx], "delays": [ms]}.
static func best_plan(fr: Array) -> Dictionary:
	var zero: Array = []
	for i in fr.size(): zero.append(0.0)
	var bo := best_order(fr, zero)
	var o: Array = []
	for i in bo: o.append(fr[i])
	var d: Array = zero.duplicate()
	var cur := spark_rate(o, d, 24)
	for _pass in 2:
		for s in range(1, o.size()):
			var keep: float = d[s]
			var step := 0.0
			while step <= DELAY_MAX:
				d[s] = step
				var r := spark_rate(o, d, 24)
				if r > cur + 0.004:
					cur = r; keep = step
				step += DELAY_STEP
			d[s] = keep
	return {"order": bo, "delays": d, "rate": cur}
