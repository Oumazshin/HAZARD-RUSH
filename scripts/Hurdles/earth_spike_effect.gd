# earth_spike_effect.gd
# ─────────────────────────────────────────────────────────────────────────────
# Self-contained sabotage earth-spike hazard.
#
# Placed : scenes/EarthSpikeEffect.tscn  →  attach to root Area2D
#
# ── Animation ─────────────────────────────────────────────────────────────────
# FRAME_COUNT      = 9  total frames on disk (001.png – 009.png)
# ANIM_FRAME_LIMIT = 6  only frames 0–5 are loaded and played (001.png – 006.png)
# Frames 007–009 are intentionally excluded from runtime playback.
#
# ── Floor alignment ───────────────────────────────────────────────────────────
# spawn_y = SpikeHurdle global Y (floor reference).
# Auto bottom-anchor formula (applied after measuring first frame):
#   local_offset = -(frame_h / 2.0)
#   world sprite bottom = spawn_y + local_offset × WORLD_SCALE.y + (frame_h × WORLD_SCALE.y / 2)
#                       = spawn_y  ✓
# ─────────────────────────────────────────────────────────────────────────────
extends Area2D

# ── Asset ─────────────────────────────────────────────────────────────────────
const SPRITE_DIR       : String  = "res://assets/environment/Hurdles/traps_and_sabotage/earth_spike Hurdle/"
const FRAME_COUNT      : int     = 9    # total frames available on disk
const ANIM_FRAME_LIMIT : int     = 6    # restrict playback to frames 0–5 (001–006)
const ANIM_FPS         : float   = 12.0

# ── Scale ─────────────────────────────────────────────────────────────────────
const WORLD_SCALE : Vector2 = Vector2(3.0, 3.0)   # 64 px × 3 = 192 px world

# ── Collision ─────────────────────────────────────────────────────────────────
const COL_LAYER : int   = 7
const COL_MASK  : int   = 3
const HITBOX_W  : float = 20.0
const HITBOX_H  : float = 50.0

# ── Fine-tune vertical offset (local space, applied on top of auto-anchor) ────
const MANUAL_Y_OFFSET : float = 8.0

# ── Node references ───────────────────────────────────────────────────────────
@onready var _sprite    : AnimatedSprite2D = $SpikeSprite
@onready var _col_shape : CollisionShape2D = $CollisionShape2D

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	scale = WORLD_SCALE

	# ── Collision ──────────────────────────────────────────────────────────────
	collision_layer = COL_LAYER
	collision_mask  = COL_MASK
	monitoring      = true
	monitorable     = false

	var rect         := RectangleShape2D.new()
	rect.size        =  Vector2(HITBOX_W, HITBOX_H)
	_col_shape.shape =  rect

	body_entered.connect(_on_body_entered)
	_build_and_play()
	print("[EarthSpikeEffect] Spawned at world pos ", global_position)

# ── Animation + bottom-anchor ─────────────────────────────────────────────────

func _build_and_play() -> void:
	if _sprite == null:
		push_error("[EarthSpikeEffect] $SpikeSprite not found.")
		return

	var sf := SpriteFrames.new()
	sf.add_animation("rise")
	sf.set_animation_loop("rise", false)
	sf.set_animation_speed("rise", ANIM_FPS)

	var loaded  : int   = 0
	var frame_h : float = 0.0

	# Load only frames 0–5 (files 001–006).  Frames 007–009 are skipped.
	for i in range(1, ANIM_FRAME_LIMIT + 1):
		var path := SPRITE_DIR + "%03d.png" % i
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			sf.add_frame("rise", tex)
			loaded += 1
			if frame_h == 0.0 and tex != null:
				frame_h = float(tex.get_height())
		else:
			push_warning("[EarthSpikeEffect] Missing frame: %s" % path)

	if loaded == 0:
		push_error("[EarthSpikeEffect] No frames loaded — verify: %s" % SPRITE_DIR)
		return

	# ── Bottom-anchor ─────────────────────────────────────────────────────────
	var anchor : float = (-frame_h / 2.0) + MANUAL_Y_OFFSET
	_sprite.position.y    = anchor
	_col_shape.position.y = anchor

	print("[EarthSpikeEffect] frames=%d/%d  frame_h=%.0fpx  anchor=%.1f  world_offset=%.1fpx  scale=%.1f" \
		% [loaded, ANIM_FRAME_LIMIT, frame_h, anchor, anchor * WORLD_SCALE.y, WORLD_SCALE.x])

	_sprite.sprite_frames  = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("rise")

# ── Collision ─────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.has_method("trigger_momentum_crash"):
		# FIX: Original called trigger_momentum_crash() with no argument, so
		# is_sabotage defaulted to false. Since this fires BEFORE the player's
		# own _on_hitbox_area_entered (which carries the correct sabotage flag),
		# is_stumbling was already true when the second call arrived — meaning
		# ai_sabotage_hits was never incremented.
		# Passing true here ensures the flag is set on the very first call.
		body.trigger_momentum_crash(true)
		print("[EarthSpikeEffect] Hit — trigger_momentum_crash(true)")
	elif body.has_method("_trigger_stumble"):
		body._trigger_stumble()
		print("[EarthSpikeEffect] Hit — _trigger_stumble()")
