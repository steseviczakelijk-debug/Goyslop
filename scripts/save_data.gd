extends RefCounted
## Progress and settings on disk. The version number lets later releases
## migrate old saves.

const PATH := "user://save.cfg"
const VERSION := 2


static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # a missing file simply leaves every default in place
	return {
		"level": maxi(1, int(cfg.get_value("progress", "level", 1))),
		"coins": maxi(0, int(cfg.get_value("progress", "coins", 0))),
		"music": clampf(float(cfg.get_value("settings", "music", 0.7)), 0.0, 1.0),
		"sfx": clampf(float(cfg.get_value("settings", "sfx", 1.0)), 0.0, 1.0),
		"vibrate": bool(cfg.get_value("settings", "vibrate", true)),
	}


static func write(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "level", data.level)
	cfg.set_value("progress", "coins", data.coins)
	cfg.set_value("settings", "music", data.music)
	cfg.set_value("settings", "sfx", data.sfx)
	cfg.set_value("settings", "vibrate", data.vibrate)
	cfg.save(PATH)
