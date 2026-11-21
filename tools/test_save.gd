extends RefCounted
## Fresh user data for headless tests and sims: every test starts from a new-game save, so running a test twice (or
## after another test or a play session on this machine) gives the same result. Call TestSave.fresh() before
## main.tscn loads. It deletes this project's own save files in user:// (the "Airron's Quest" app data folder).
const FILES := ["user://airrons_quest.cfg", "user://kingdom.cfg", "user://targeting.cfg", "user://dungeon.cfg", "user://bosses.cfg"]

static func fresh() -> void:
	for f in FILES:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
