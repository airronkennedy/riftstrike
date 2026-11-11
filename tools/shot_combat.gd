extends SceneTree
# Battle frame strip for feel review:
#   XDG_DATA_HOME=/tmp/combat-xdg godot --path . --resolution 960x540 --script res://tools/shot_combat.gd -- --out=/tmp/cs --mode=1
var g
var out := "/tmp/cs"
var mode := 1
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--mode="): mode = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _run() -> void:
	await wait(500)
	g.sfx.muted = true
	g.AUTO = false
	for h in g.HERO_NAMES:
		g.HERO_PROG[h] = {"level": 30, "xp": 0}; g.HERO_MP[h] = 0.0
		g.AB_EQUIP.erase(h); g.AB_AUTO.erase(h); g.validate_ab_equip(h)
	g.start_fight(mode)
	await wait(1300)
	var bl: Array = g.alive("blue")
	for i in bl.size():
		bl[i].gauge = 100.0 if i < 2 else (88.0 if i < 4 else 40.0)
	for u in bl: g.toggle_queue(u)
	g.queue_ability(bl[0], bl[0].ab_class)
	g.queue_ability(bl[1], bl[1].ab_sub)
	g.G.ab_focus = bl[1]
	await wait(250)
	await shot("00_select")
	g.execute_orders()
	for i in 22:
		await wait(230)
		await shot("t1_%02d" % i)
	g.speed = 2
	while g.phase == "battle" and g.G.side == "blue": await wait(60)
	for i in 10:
		await wait(250)
		await shot("e1_%02d" % i)
	g.AUTO = true
	while g.phase != "results": await wait(150)
	await wait(700)
	await shot("99_results")
	print("SHOTS ", g.G.result, " turns ", g.G.turn)
	quit()
