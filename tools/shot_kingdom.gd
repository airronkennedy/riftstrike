extends SceneTree
## Kingdom screenshot:
##   xvfb-run godot --path . --resolution 390x844 --script res://tools/shot_kingdom.gd -- --map=town --x=9 --y=9.6 --out=/tmp/k.png
## Options: --touch=1 (phone UI + a held floating joystick), --mapscreen=1 (open the M map), --gfx=high|phone|low,
## --wait=1.6 (seconds before the grab).
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var o := {"map": "town", "x": "12", "y": "15", "out": "/tmp/kingdom.png", "touch": "0", "mapscreen": "0", "gfx": "", "wait": "1.6"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			o[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var k = load("res://scenes/kingdom.tscn").instantiate()
	root.add_child(k)
	await process_frame
	k.touch_ui = o.touch == "1"
	if o.gfx != "":
		k.gfx_level = o.gfx
		k._apply_quality()
	k.load_map(o.map, Vector2(float(o.x), float(o.y)))
	k._show_banner(k.map.name, k.map.sub)
	await create_timer(0.3).timeout
	if o.touch == "1":
		# Hold a finger on the lower-left of the field and push up-right: the floating stick appears under it.
		var vs: Vector2 = root.get_viewport().get_visible_rect().size
		var p := Vector2(vs.x * 0.27, vs.y * 0.78)
		var t := InputEventScreenTouch.new()
		t.index = 0; t.position = p; t.pressed = true
		k._input(t)
		var d := InputEventScreenDrag.new()
		d.index = 0; d.position = p + Vector2(26, -20)
		k._input(d)
		k.touch.vec = Vector2.ZERO # keep the knob pushed on screen but hold the hero still for the shot
	if o.mapscreen == "1":
		k.toggle_big_map()
	await create_timer(float(o.wait)).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(o.out)
	print("saved ", o.out)
	quit()
