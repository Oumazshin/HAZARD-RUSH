# fireball_projectile.gd
# ─────────────────────────────────────────────────────────────────────────────
# Self-contained fireball sabotage projectile.  Spawned at lane level by
# sabotage_system.gd and moves LEFT at MOVE_SPEED px/s until freed by the
# sabotage system after hazard_lifetime seconds.
#
# ── Spawn types ───────────────────────────────────────────────────────────────
#   is_low_spawn = false  (HIGH)
#     spawn_y = SawHurdle global Y  (_get_y_for_type(1))
#     Sprite centred at spawn_y — aligns with the elevated SAW hurdle.
#
#   is_low_spawn = true   (LOW)
#     spawn_y = SpikeHurdle global Y  (_get_y_for_type(0))
#     Sprite bottom-anchored at spawn_y — fireball sits on the floor.
#     local_offset = -(frame_h × SPRITE_SCALE.y) / 2.0
#     Derivation (root scale = 1):
#       sprite world centre  = spawn_y + local_offset
#       sprite world bottom  = spawn_y + local_offset + (frame_h × SPRITE_SCALE.y / 2)
#                            = spawn_y  ✓
#
# Set is_low_spawn BEFORE add_child() so _ready() reads the correct value.
#
# ── Animation split ───────────────────────────────────────────────────────────
#   "fly"  : frames 001–004   loop = true   — normal in-flight animation
#   "hit"  : frames 005–009   loop = false  — impact burst, plays ONCE on hit
#
# ── Collision behaviour ───────────────────────────────────────────────────────
# On first impact: play "hit" → disable collision → keep moving → resume "fly"
# ─────────────────────────────────────────────────────────────────────────────
extends Area2D

# ── Asset ─────────────────────────────────────────────────────────────────────
const FIRE_BALL_DIR : String = "res://assets/environment/Hurdles/traps_and_sabotage/fire_ball hurdle/"

# ── Visual ─────────────────────────────────────────────────────────────────────
const SPRITE_SCALE : Vector2 = Vector2(4.0, 4.0)        # 64 px × 4 = 256 px world
const SPRITE_COLOR : Color   = Color(1.0, 0.85, 0.2, 1.0)

# ── Animation ─────────────────────────────────────────────────────────────────
const FLY_FRAMES : int   = 4    # frames 001 – 004 (looping flight)
const HIT_START  : int   = 5    # first impact frame (1-indexed filename)
const HIT_END    : int   = 9    # last  impact frame (inclusive)
const ANIM_FPS   : float = 14.0

# ── Movement ──────────────────────────────────────────────────────────────────
const MOVE_SPEED : float = 200.0   # px/s left

# ── Spawn configuration ───────────────────────────────────────────────────────
## Set by sabotage_system.gd BEFORE add_child().
## false = HIGH (centre-aligned with SAW hurdle)
## true  = LOW  (bottom-anchored on the floor)
@export var is_low_spawn : bool = false

# ── Node references ───────────────────────────────────────────────────────────
@onready var _anim_sprite : AnimatedSprite2D = $FireballSprite
@onready var _col_shape   : CollisionShape2D = $CollisionShape2D

# ── State ─────────────────────────────────────────────────────────────────────
var _has_hit : bool = false

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# ── Collision ──────────────────────────────────────────────────────────────
	add_to_group("hurdles")
	collision_layer = 7
	collision_mask  = 3
	monitoring      = true
	area_entered.connect(_on_area_entered)

	# ── Sprite ─────────────────────────────────────────────────────────────────
	if _anim_sprite:
		_anim_sprite.scale          = SPRITE_SCALE
		_anim_sprite.modulate       = SPRITE_COLOR
		_anim_sprite.speed_scale    = ANIM_FPS
		_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
	# FIXED: Scale the hitbox up to match the visual size of the fire
	if _col_shape:
		_col_shape.scale = SPRITE_SCALE

	# Build animations and apply vertical alignment based on is_low_spawn.
	_build_sprite_frames()

	print("[FireballProjectile] Spawned — %s — world pos %s" % [
		"LOW (floor)" if is_low_spawn else "HIGH (saw level)",
		global_position
	])

# ── Movement ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Always move left — never paused, even after a hit.
	global_position.x -= MOVE_SPEED * delta

# ── Sprite frames + alignment ─────────────────────────────────────────────────

func _build_sprite_frames() -> void:
	if not ResourceLoader.exists(FIRE_BALL_DIR + "001.png"):
		push_error("[FireballProjectile] Frame folder missing: '%s'" % FIRE_BALL_DIR)
		return

	var sf      := SpriteFrames.new()
	var frame_h :  float = 0.0   # measured from first loaded frame

	# ── "fly" : frames 001–004, looping ───────────────────────────────────────
	sf.add_animation("fly")
	sf.set_animation_loop("fly", true)
	sf.set_animation_speed("fly", 1.0)
	for i in range(1, FLY_FRAMES + 1):
		var tex := load(FIRE_BALL_DIR + "%03d.png" % i) as Texture2D
		sf.add_frame("fly", tex)
		if frame_h == 0.0 and tex != null:
			frame_h = float(tex.get_height())

	# ── "hit" : frames 005–009, one-shot ──────────────────────────────────────
	sf.add_animation("hit")
	sf.set_animation_loop("hit", false)
	sf.set_animation_speed("hit", 1.0)
	for i in range(HIT_START, HIT_END + 1):
		sf.add_frame("hit", load(FIRE_BALL_DIR + "%03d.png" % i))

	_anim_sprite.sprite_frames = sf
	_anim_sprite.play("fly")

	# ── Vertical alignment ────────────────────────────────────────────────────
	# Calculated from the actual frame pixel height so it is correct regardless
	# of the source image dimensions.
	# Root Area2D has no explicit scale (1, 1), so local offset == world offset.
	if frame_h > 0.0:
		if is_low_spawn:
			# Bottom-anchor: place sprite so its BOTTOM sits at spawn_y (floor).
			# The sprite child has scale SPRITE_SCALE; its rendered world height
			# = frame_h × SPRITE_SCALE.y.
			# For bottom at spawn_y:  local_y = -(frame_h × scale_y) / 2.0
			var local_y : float = -(frame_h * SPRITE_SCALE.y) / 2.0
			_anim_sprite.position.y = local_y
			_col_shape.position.y   = local_y
			print("[FireballProjectile] LOW  — frame_h=%.0fpx  local_y=%.1f  world_offset=%.1fpx" \
				% [frame_h, local_y, local_y])
		else:
			# Centre-align: sprite centre at spawn_y, matching the SAW hurdle centre.
			_anim_sprite.position.y = 0.0
			_col_shape.position.y   = 0.0
			print("[FireballProjectile] HIGH — frame_h=%.0fpx  centred at spawn_y" % frame_h)

	print("[FireballProjectile] Frames ready — fly: %d  hit: %d" % [
		sf.get_frame_count("fly"),
		sf.get_frame_count("hit")
	])

# ── Collision ──────────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
	# Character Hitbox areas only (layer 1 = player, 2 = AI)
	if area.collision_layer & 3 != 0:
		_play_hit()

func _play_hit() -> void:
	_has_hit = true

	# Disable collision so this trigger does not fire again.
	_col_shape.set_deferred("disabled", true)

	# Play impact animation (frames 5–9).
	_anim_sprite.play("hit")
	print("[FireballProjectile] Impact — playing frames 5–9.")

	# After the one-shot impact animation finishes, resume normal flight.
	await _anim_sprite.animation_finished

	if is_instance_valid(self) and not is_queued_for_deletion():
		_anim_sprite.play("fly")
		print("[FireballProjectile] Resumed 'fly' after impact.")
