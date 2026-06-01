# fireball_projectile.gd
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
const MOVE_SPEED : float = 400.0   # px/s left

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
	
	# CRITICAL FIX: The hazard lives on layer 7, but it MUST scan layers 1 (Player) and 2 (AI).
	# Bit 1 = value 1. Bit 2 = value 2. Bit 7 = value 64. 1 + 2 + 64 = 67.
	collision_layer = 64
	collision_mask  = 67
	
	monitoring      = true
	area_entered.connect(_on_area_entered)

	# ── Sprite ─────────────────────────────────────────────────────────────────
	if _anim_sprite:
		_anim_sprite.scale          = SPRITE_SCALE
		_anim_sprite.modulate       = SPRITE_COLOR
		_anim_sprite.speed_scale    = ANIM_FPS
		_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
	if _col_shape:
		_col_shape.scale = SPRITE_SCALE

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
	var frame_h :  float = 0.0   

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
	if frame_h > 0.0:
		if is_low_spawn:
			var local_y : float = -(frame_h * SPRITE_SCALE.y) / 2.0
			_anim_sprite.position.y = local_y
			_col_shape.position.y   = local_y
		else:
			_anim_sprite.position.y = 0.0
			_col_shape.position.y   = 0.0

# ── Collision ──────────────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
		
	# Detect if the overlapping area belongs to the Player or Opponent hitboxes
	if area.name == "Hitbox" or area.is_in_group("player_character") or area.is_in_group("opponent_ai"):
		_play_hit()

func _play_hit() -> void:
	_has_hit = true
	_col_shape.set_deferred("disabled", true)

	_anim_sprite.play("hit")
	print("[FireballProjectile] Impact — playing frames 5–9.")

	await _anim_sprite.animation_finished

	if is_instance_valid(self) and not is_queued_for_deletion():
		_anim_sprite.play("fly")
