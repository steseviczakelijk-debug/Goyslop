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
const ARMORED_ATTACK := 0.5      # seconds from raising the axe to the blow
const ARMORED_STRIKE := 0.18     # the last part of that, axe coming down

# Gates
const GATE_HITS_PER_POINT := 7
const GATE_GROW_SHARE := 0.5   # shooting can raise a gate by this part of its value
const GATE_GROW_MIN := 3       # ... but always by at least this much

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

# Rewards
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
const BOSS_HP_FACTOR := 38.0
