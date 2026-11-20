extends SceneTree
## Kingdom screenshot: xvfb-run godot --path . --resolution 1024x576 --script res://tools/shot_kingdom.gd -- --map=town --x=9 --y=9.6 --out=/tmp/k.png [--touch=1]
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var o := {"map": "town", "x": "12", "y": "15", "out": "/tmp/kingdom.png", "touch": "0"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			o[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var k = load("res://scenes/kingdom.tscn").instantiate()
	root.add_child(k)
	await process_frame
	k.joystick.visible = o.touch == "1"
	k.load_map(o.map, Vector2(float(o.x), float(o.y)))
	k._show_banner(k.map.name, k.map.sub)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(o.out)
	print("saved ", o.out)
	quit()
