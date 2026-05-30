extends Node

const SAVE_PATH = "user://highscore.save"

func save_best_time(new_time: float):
	var best = load_best_time()
	# In racing, a LOWER time is better. 
	# We save if new_time is less than best, or if no best exists (0.0).
	if new_time < best or best == 0.0:
		var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_float(new_time)
			file.close()

func load_best_time() -> float:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var value = file.get_float()
			file.close()
			return value
	return 0.0
