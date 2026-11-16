extends RefCounted
## Every number that shapes how the game plays lives here, so tuning never means
## hunting through the simulation code.

# Playfield
const ROAD_HALF := 4.0
const SCROLL_SPEED := 7.0
const SPAWN_AHEAD := 55.0

# Squad
const MAX_SHOWN := 60          # soldiers drawn; the rest are only counted
const FORMATION_SPACING := 0.33
const DRAG_SENSITIVITY := 1.5
const MAX_SOLDIERS := 999999

# Shooting
const FIRE_INTERVAL := 0.16
const MAX_SHOOTERS := 8        # arrows per volley; damage is spread over them
const BULLET_SPEED := 45.0
const BULLET_RANGE := 32.0
const MAX_BULLETS := 160

# Enemies
const MAX_ENEMIES := 1500
const ENEMY_R := 0.38
const ENEMY_SPEED := 2.0
const ENEMY_STEER := 1.3
const ENEMY_STEER_RANGE := 16.0
const ENEMY_SPACING := 0.72

# Armored orcs: tougher, costlier and they strike before they take their toll
const ARMORED_FROM_LEVEL := 3
const ARMORED_HP := 3.0          # times a normal orc of the same wave
const ARMORED_COST := 3          # soldiers lost per normal orc's worth
const ARMORED_COINS := 3
const ARMORED_SHARE := 0.06      # part of a wave at ARMORED_FROM_LEVEL
const ARMORED_SHARE_GROWTH := 0.02
const ARMORED_SHARE_MAX := 0.25
const ARMORED_MIN_ARMY := 30.0   # no armored orcs in a wave meant for a smaller army
const ARMORED_ATTACK := 0.5      # seconds from raising the axe to the blow
const ARMORED_STRIKE := 0.18     # the last part of that, axe coming down

# Gates
const GATE_HITS_PER_POINT := 7
const GATE_STEP_SHARE := 0.05  # each step raises a gate by this part of its value (at least 1)
const GATE_COST_GROWTH := 1.3  # every next step needs this many times more hits
const GATE_AIM_SHARE := 1.0    # part of the approach a perfect player spends shooting the gate

# Boss
const BOSS_R := 1.5
const BOSS_SPEED := 1.8
const BOSS_STEER := 1.0
const BOSS_STOP_DISTANCE := 22.0
const BOSS_REACH := 3.4          # how far in front of himself the mace lands
const BOSS_WINDUP := 0.9         # seconds of warning before the smash
const BOSS_RECOVER := 0.7        # seconds before he raises the mace again
const BOSS_SMASH_HALF := 1.7     # half-width of the impact
const BOSS_SMASH_SHARE := 0.35   # part of the squad a direct hit removes
const BOSS_SMASH_MIN := 4

# Upgrades bought with coins. `step` is what one level adds.
const UPGRADES := [
	{"key": "up_army", "name": "ARMY", "icon": "res://assets/ui_up_army.png", "base": 150, "step": 1.0, "text": "Start with %d archers"},
	{"key": "up_damage", "name": "DAMAGE", "icon": "res://assets/ui_up_damage.png", "base": 200, "step": 0.05, "text": "Arrow damage +%d%%"},
	{"key": "up_rate", "name": "FIRE RATE", "icon": "res://assets/arrow.png", "base": 200, "step": 0.03, "text": "Fire rate +%d%%"},
	{"key": "up_coins", "name": "COINS", "icon": "res://assets/coin.png", "base": 250, "step": 0.1, "text": "Coins earned +%d%%"},
]
const UPGRADE_PRICE_GROWTH := 1.45
const UPGRADE_MAX_LEVEL := 25
const DAILY_REWARDS := [100, 200, 300, 400, 500, 750, 1500]

# Rewards
const STARS_3 := 0.85   # part of the perfect army you must still have for three stars
const STARS_2 := 0.6
const COINS_PER_KILL := 1
const COINS_PER_BOSS := 50

# Level generator
const FIRST_SEGMENT_AT := 32.0
const SEGMENT_GAP := 16.0
const BASE_SEGMENTS := 5
const MAX_SEGMENTS := 12
const GROWTH_PER_LEVEL := 0.05
const GROWTH_MAX := 1.2
const EARLY_EASE := [0.55, 0.75]   # levels 1 and 2 are gentler, to learn the game
const WAVE_MIN := 1.8          # wave size as a multiple of the expected army
const WAVE_MAX := 2.8
const WAVE_CAP := 350
# A level is built around the army the perfect route yields. The troll is sized
# so that an army this far below perfect still just beats him.
const ALLOWED_DEVIATION := 0.28
const BOSS_HP_PER_SOLDIER := 75.0  # health one soldier gets through in a boss fight
const PERFECT_KEEPS := 0.75        # calibration: waves may cost the perfect route at most the rest
const CALIBRATED_LEVELS := 100     # levels measured in scripts/level_table.gd
const CYCLE_FROM_LEVEL := 21       # beyond the table, layouts repeat from this level on

# Pace: from SPEED_FROM_LEVEL on, the march and the orcs get a little faster
# every level, up to SPEED_MAX times the starting pace.
const SPEED_FROM_LEVEL := 3
const SPEED_PER_LEVEL := 0.03
const SPEED_MAX := 1.4


static func speed_for(level: int) -> float:
	return minf(1.0 + maxi(0, level - SPEED_FROM_LEVEL + 1) * SPEED_PER_LEVEL, SPEED_MAX)


static func upgrade_price(index: int, owned: int) -> int:
	return int(round(UPGRADES[index].base * pow(UPGRADE_PRICE_GROWTH, owned) / 10.0)) * 10
