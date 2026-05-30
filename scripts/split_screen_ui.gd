extends VBoxContainer

@onready var top_container = $TopPlayerView
@onready var bot_container = $BottomOpponentView
@onready var viewport1     = $TopPlayerView/Viewport1
@onready var viewport2     = $BottomOpponentView/Viewport2
@onready var camera1       = $TopPlayerView/Viewport1/Player1Camera
@onready var camera2       = $BottomOpponentView/Viewport2/OpponentCamera

var player:   Node2D = null
var opponent: Node2D = null

const CAMERA_Y_OFFSET: float = -120.0
const CAMERA_SMOOTH:   float = 12.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	top_container.stretch = false
	bot_container.stretch = false
	_resize()
	get_tree().root.size_changed.connect(_resize)

	await get_tree().process_frame
	player   = get_node_or_null(
		"TopPlayerView/Viewport1/GameWorld/PlayerLane/Player")
	opponent = get_node_or_null(
		"BottomOpponentView/Viewport2/AILane/OpponentAI")

func _resize() -> void:
	var win:    Vector2 = get_viewport_rect().size
	var half_h: int     = int(win.y / 2.0)

	size = win
	top_container.custom_minimum_size = Vector2(win.x, half_h)
	top_container.size                = Vector2(win.x, half_h)
	bot_container.custom_minimum_size = Vector2(win.x, half_h)
	bot_container.size                = Vector2(win.x, half_h)

	if viewport1:
		viewport1.size = Vector2i(int(win.x), half_h)
	if viewport2:
		viewport2.size = Vector2i(int(win.x), half_h)

func _process(delta: float) -> void:
	if player and camera1:
		var target: Vector2 = player.global_position + Vector2(0.0, CAMERA_Y_OFFSET)
		camera1.global_position = camera1.global_position.lerp(target, CAMERA_SMOOTH * delta)
	if opponent and camera2:
		var target: Vector2 = opponent.global_position + Vector2(0.0, CAMERA_Y_OFFSET)
		camera2.global_position = camera2.global_position.lerp(target, CAMERA_SMOOTH * delta)
