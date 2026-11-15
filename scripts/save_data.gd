extends RefCounted
## Progress on disk. The version number lets later releases migrate old saves.

const PATH := "user://save.cfg"
const VERSION := 1


static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	var data := {"level": 1, "coins": 0}
	if cfg.load(PATH) == OK:
		data.level = maxi(1, int(cfg.get_value("progress", "level", 1)))
		data.coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
	return data


static func write(level: int, coins: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "coins", coins)
	cfg.save(PATH)
