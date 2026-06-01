# power_up.gd
# ─────────────────────────────────────────────────────────────────────────────
# Collectible fruit power-up placed along the racing track.
#
# Placed: scenes/PowerUp.tscn  →  attach to root Area2D
# Required child nodes in PowerUp.tscn:
#   • CollisionShape2D  (name: "CollisionShape2D")  — existing
#   • Sprite2D          (name: "FruitSprite")        — NEW: shows the fruit
#   • Sprite2D          (name: "CollectEffect")      — NEW: burst on pickup
#
# ── Effects ───────────────────────────────────────────────────────────────────
#  Fruit        │ Effect               │ Value
#  ─────────────┼──────────────────────┼─────────────────────────────────────
#  Apple        │ Speed Boost          │ +30 % speed for 5 s
#  Bananas      │ Banana Peel          │ Opponent speed −25 % for 4 s
#  Cherries     │ Shield               │ Absorbs next 1 obstacle hit
#  Kiwi         │ Ghost Mode           │ Collision disabled for 3 s
#  Melon        │ Score Rush           │ 2× score multiplier for 6 s
#  Orange       │ Sabotage Charge      │ Resets sabotage cooldown to 0
#  Pineapple    │ High Jump            │ Next jump is ×2 height (5 s window)
#  Strawberry   │ Opponent Freeze      │ Freezes opponent for 2 s
# ─────────────────────────────────────────────────────────────────────────────
# Player / AI racers must implement:
#   receive_powerup(fruit_type: int) -> void
# See the "Effect constants" section below for the int → fruit mapping.
# ─────────────────────────────────────────────────────────────────────────────
@tool
extends Area2D

# ── Fruit enum ────────────────────────────────────────────────────────────────
enum FruitType {
	APPLE      = 0,   # Speed Boost
	BANANAS    = 1,   # Banana Peel  (offensive — slow opponent)
	CHERRIES   = 2,   # Shield
	KIWI       = 3,   # Ghost Mode
	MELON      = 4,   # Score Rush
	ORANGE     = 5,   # Sabotage Charge
	PINEAPPLE  = 6,   # High Jump
	STRAWBERRY = 7,   # Opponent Freeze (offensive)
	RANDOM     = -1,  # Picks one of the above at runtime
}

# ── Effect constants (for player.gd / opponent_ai.gd receive_powerup) ────────
const EFFECT_SPEED_BOOST      : int   = 0   # Apple      — value: duration (5.0 s)
const EFFECT_BANANA_PEEL      : int   = 1   # Bananas    — value: duration (4.0 s)
const EFFECT_SHIELD           : int   = 2   # Cherries   — value: hit count (1.0)
const EFFECT_GHOST_MODE       : int   = 3   # Kiwi       — value: duration (3.0 s)
const EFFECT_SCORE_RUSH       : int   = 4   # Melon      — value: duration (6.0 s)
const EFFECT_SABOTAGE_CHARGE  : int   = 5   # Orange     — value: unused (0.0)
const EFFECT_HIGH_JUMP        : int   = 6   # Pineapple  — value: window  (5.0 s)
const EFFECT_FREEZE_OPPONENT  : int   = 7   # Strawberry — value: duration (2.0 s)

# ── Asset paths ───────────────────────────────────────────────────────────────
const _ASSET_BASE    : String = "res://assets/environment/Fruits for PowerUps/"
const COLLECT_PATH   : String = _ASSET_BASE + "Collected.png"
const FRUIT_SCALE    : Vector2 = Vector2(2.0, 2.0)   # world scale for fruit sprite
const BOB_AMPLITUDE  : float   = 5.0                  # px — idle bob height
const BOB_SPEED      : float   = 3.0                  # rad/s

# Maps FruitType enum value → texture filename
const FRUIT_TEXTURES : Dictionary = {
	FruitType.APPLE:      _ASSET_BASE + "Apple.png",
	FruitType.BANANAS:    _ASSET_BASE + "Bananas.png",
	FruitType.CHERRIES:   _ASSET_BASE + "Cherries.png",
	FruitType.KIWI:       _ASSET_BASE + "Kiwi.png",
	FruitType.MELON:      _ASSET_BASE + "Melon.png",
	FruitType.ORANGE:     _ASSET_BASE + "Orange.png",
	FruitType.PINEAPPLE:  _ASSET_BASE + "Pineapple.png",
	FruitType.STRAWBERRY: _ASSET_BASE + "Strawberry.png",
}

# Maps FruitType → (effect_type: int, effect_value: float)
# effect_type  = the constant defined above; passed to receive_powerup().
# effect_value = numeric parameter for the effect (duration, count, etc.)
const FRUIT_EFFECTS : Dictionary = {
	FruitType.APPLE:      [EFFECT_SPEED_BOOST,     5.0],
	FruitType.BANANAS:    [EFFECT_BANANA_PEEL,      4.0],
	FruitType.CHERRIES:   [EFFECT_SHIELD,           1.0],
	FruitType.KIWI:       [EFFECT_GHOST_MODE,       3.0],
	FruitType.MELON:      [EFFECT_SCORE_RUSH,       6.0],
	FruitType.ORANGE:     [EFFECT_SABOTAGE_CHARGE,  0.0],
	FruitType.PINEAPPLE:  [EFFECT_HIGH_JUMP,        5.0],
	FruitType.STRAWBERRY: [EFFECT_FREEZE_OPPONENT,  2.0],
}

# ── Exports ───────────────────────────────────────────────────────────────────
@export var fruit_type: FruitType = FruitType.RANDOM:
	set(v):
		fruit_type = v
		_apply_fruit_visual()

# ── Node references ───────────────────────────────────────────────────────────
@onready var _fruit_sprite  : Sprite2D           = $FruitSprite
@onready var _collect_sprite: Sprite2D           = $CollectEffect
@onready var _col_shape     : CollisionShape2D   = $CollisionShape2D

# ── Runtime state ─────────────────────────────────────────────────────────────
var _collected     : bool      = false
var _timer         : float     = 0.0
var _resolved_type : FruitType = FruitType.APPLE   # set in _ready()

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_fruit_visual()
		return

	# ── Runtime only ──────────────────────────────────────────────────────────
	collision_layer = 0    # power-up does not block movement
	collision_mask  = 3    # detect layer 1 (player) and layer 2 (AI) bodies
	body_entered.connect(_on_body_entered)

	# Resolve random type NOW so the visual is stable from spawn.
	if fruit_type == FruitType.RANDOM:
		_resolved_type = FruitType.values()[randi() % 8]
	else:
		_resolved_type = fruit_type

	_collect_sprite.visible = false
	_apply_fruit_visual()

# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _collected or Engine.is_editor_hint():
		return
	_timer += delta
	# Gentle vertical bob so the item is obviously interactive
	if _fruit_sprite:
		_fruit_sprite.position.y = sin(_timer * BOB_SPEED) * BOB_AMPLITUDE

# ── Visual setup ──────────────────────────────────────────────────────────────

func _apply_fruit_visual() -> void:
	if not is_inside_tree():
		return

	# In the editor, show whatever fruit_type is set; treat RANDOM as APPLE.
	var display_type: FruitType
	if Engine.is_editor_hint():
		display_type = FruitType.APPLE if fruit_type == FruitType.RANDOM else fruit_type
	else:
		display_type = _resolved_type

	if _fruit_sprite == null:
		_fruit_sprite = get_node_or_null("FruitSprite")
	if _fruit_sprite == null:
		return

	var path: String = FRUIT_TEXTURES.get(display_type, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[PowerUp] Texture not found for FruitType %d at '%s'" % [display_type, path])
		return

	_fruit_sprite.texture = load(path)
	_fruit_sprite.scale   = FRUIT_SCALE

# ── Collision ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.has_method("receive_powerup"):
		return

	_collected = true

	if _col_shape:
		_col_shape.set_deferred("disabled", true)

	if _fruit_sprite:
		_fruit_sprite.visible = false
	if _collect_sprite and ResourceLoader.exists(COLLECT_PATH):
		_collect_sprite.texture = load(COLLECT_PATH)
		_collect_sprite.visible = true

	# ↓ explicit Array type — fixes "Cannot infer type of 'effect' variable"
	var effect : Array = FRUIT_EFFECTS.get(_resolved_type, [EFFECT_SPEED_BOOST, 5.0])
	body.receive_powerup(effect[0], effect[1])

	print("[PowerUp] Collected: %s → effect %d (value %.1f)" % [
		FruitType.keys()[_resolved_type], effect[0], effect[1]
	])

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale",    Vector2(2.2, 2.2),          0.3)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tw.chain().tween_callback(queue_free)

# ── Player / AI integration contract ─────────────────────────────────────────
# Implement this method in player.gd and opponent_ai.gd:
#
# func receive_powerup(effect_type: int, effect_value: float) -> void:
#     match effect_type:
#
#         PowerUp.EFFECT_SPEED_BOOST:
#             # Increase move speed by 30% for effect_value seconds.
#             # e.g.: _move_speed *= 1.3; await delay(effect_value); _move_speed /= 1.3
#
#         PowerUp.EFFECT_BANANA_PEEL:
#             # Relay to opponent: slow their speed by 25% for effect_value seconds.
#             # e.g.: GameState.apply_debuff_to_opponent(lane_id, "slow", 0.25, effect_value)
#
#         PowerUp.EFFECT_SHIELD:
#             # Set a shield flag. On next obstacle hit, absorb it and clear flag.
#             # e.g.: _shield_active = true
#
#         PowerUp.EFFECT_GHOST_MODE:
#             # Disable collision layer for effect_value seconds.
#             # e.g.: collision_layer = 0; await delay(effect_value); collision_layer = <normal>
#
#         PowerUp.EFFECT_SCORE_RUSH:
#             # Apply 2× score multiplier for effect_value seconds via GameState.
#             # e.g.: GameState.set_score_multiplier(lane_id, 2.0, effect_value)
#
#         PowerUp.EFFECT_SABOTAGE_CHARGE:
#             # Find this lane's SabotageSystem and call add_charge(1).
#             # e.g.: get_tree().get_first_node_in_group("sabotage_system_" + lane_id).add_charge()
#
#         PowerUp.EFFECT_HIGH_JUMP:
#             # Allow next jump to be ×2 height within effect_value seconds.
#             # e.g.: _jump_boost_active = true; await delay(effect_value); _jump_boost_active = false
#
#         PowerUp.EFFECT_FREEZE_OPPONENT:
#             # Relay to opponent: freeze (velocity = 0) for effect_value seconds.
#             # e.g.: GameState.apply_debuff_to_opponent(lane_id, "freeze", 0, effect_value)
