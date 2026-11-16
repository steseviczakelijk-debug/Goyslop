extends RefCounted
## Progress and settings on disk. The version number lets later releases
## migrate old saves.

const PATH := "user://save.cfg"
const VERSION := 3

## key -> [section, default]
const FIELDS := {
	"level": ["progress", 1],
	"coins": ["progress", 0],
	"up_army": ["upgrades", 0],
	"up_damage": ["upgrades", 0],
	"up_rate": ["upgrades", 0],
	"up_coins": ["upgrades", 0],
	"daily_day": ["daily", 0],
	"daily_streak": ["daily", 0],
	"music": ["settings", 0.7],
	"sfx": ["settings", 1.0],
	"vibrate": ["settings", true],
}


static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # a missing file simply leaves every default in place
	var data := {}
	for key in FIELDS:
		var fallback = FIELDS[key][1]
		var value = cfg.get_value(FIELDS[key][0], key, fallback)
		if typeof(fallback) == TYPE_INT:
			value = maxi(0, int(value))
		elif typeof(fallback) == TYPE_FLOAT:
			value = clampf(float(value), 0.0, 1.0)
		else:
			value = bool(value)
		data[key] = value
	data.level = maxi(1, data.level)
	return data


static func write(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for key in FIELDS:
		cfg.set_value(FIELDS[key][0], key, data[key])
	cfg.save(PATH)
