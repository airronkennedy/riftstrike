extends SceneTree
# Overworld tour screenshots (layout 3): xvfb-run godot --path . --script res://tools/shot_overworld.gd -- --out=DIR [--only=name]
var g
var out := "/tmp/ow"
var only := ""
const SPOTS := [
	["a1_rivenbrook", 20, 16], ["a1_fort_courtyard", 212, 57], ["a1_fort_span", 226, 54], ["a1_royal_causeway", 211, 84],
	["a2_emberfall_plaza", 252, 55], ["a2_emberfall_mines", 254, 44], ["a2_redcap_tarn", 297, 22], ["a2_redcap_camp", 316, 25],
	["a2_steppe", 304, 50], ["a2_glasswind_canyon", 313, 72], ["a2_sunken_abbey", 301, 90], ["a2_abbey_crypt", 304, 100],
	["a2_mirefen_bog", 379, 29], ["a2_foxglove_hamlet", 360, 48], ["a2_mirefen_deep", 390, 22], ["a2_lanternkeep_hall", 375, 72],
	["a2_underroot_catacomb", 375, 94], ["a2_caldera_lake", 418, 80], ["a2_caldera_bridge", 402, 98],
	["a3_frostveil_bridge", 330, 113], ["a3_frostveil_plaza", 329, 139], ["a3_frostveil_gate", 330, 126], ["a3_frostveil_east", 356, 140],
	["a3_moonlit_terraces", 410, 128], ["a3_seers_spire", 428, 160], ["a3_spire_sanctum", 428, 184], ["a3_deepvault_prison", 391, 162],
	["a3_molten_capital", 392, 187], ["a3_hoarfrost_pass", 340, 182],
	["a4_kingshold_approach", 230, 110], ["a4_crown_market", 236, 103], ["a4_citadel", 236, 172], ["a4_withered_garden", 172, 160],
	["a4_drakespire", 122, 164], ["a4_starfall_archive", 106, 124], ["a4_rift_heart", 34, 124], ["a5_riftsea", 39, 177], ["a4_citadel_keep", 237, 179], ["a2_redcap_burrows", 336, 16], ["a3_rime_cave", 362, 189], ["a4_royal_crypt", 166, 190], ["a2_abbey_garth", 318, 96], ["a2_emberfall_lane", 252, 64], ["a5_riftsea_depths", 69, 194],
]
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--only="): only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	var sc: PackedScene = load("res://main.tscn")
	g = sc.instantiate()
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
	g.WORLD.gates_enabled = false
	g.WORLD.enc_mult = 0.0
	g.ow_ready = false
	g.open_overworld()
	await wait(600)
	for s in SPOTS:
		if only != "" and not str(s[0]).contains(only):
			continue
		g.ow_x = float(s[1]) * 64 + 32.0; g.ow_y = float(s[2]) * 64 + 40.0
		if g.ow_blocked_at(g.ow_x, g.ow_y):
			print("spot blocked ", s)
		g.ow_tx = g.ow_x; g.ow_ty = g.ow_y; g.ow_camx = g.ow_x; g.ow_camy = g.ow_y
		await wait(450)
		await shot(s[0])
		print(s[0], " -> ", g.WORLD.cur_area, " / ", g.WORLD.cur_zone)
	g.ow_open_menu_screen("map")
	await wait(300)
	await shot("z_map_region")
	g.WMAP.tab = "local"
	await wait(300)
	await shot("z_map_local")
	quit()
