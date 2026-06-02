@tool
extends Area2D

# 0 = HIGH (Requires Jump), 1 = LOW (Requires Slide)
@export_enum("HIGH", "LOW") var type: int = 0:
	set(value):
		type = value
		_update_visuals()

# ── FIX: Player clear tracking ───────────────────────────────────────────────
# _player_notified prevents double-counting: once the player moves past, done.
# _player_crashed is set to true in _on_body_entered when the player's body
# triggers a crash, so _process knows NOT to credit a successful clear.
var _player_notified : bool = false
var _player_crashed  : bool = false

func _ready() -> void:
	add_to_group("hurdles")
	_update_visuals()
	body_entered.connect(_on_body_entered)

func _update_visuals() -> void:
	if is_inside_tree():
		modulate = Color.RED if type == 0 else Color.BLUE

# ── FIX: Detect when the player moves past this hurdle ───────────────────────
# Runs every frame. Compares positions in the same coordinate space (same
# SubViewport) so this is reliable where group-scan + is_ancestor_of is not.
#
# Lane filter: get_parent() returns PlayerLane for player-lane hurdles and
# AILane for AI-lane hurdles. PlayerLane.is_ancestor_of(player) = true;
# AILane.is_ancestor_of(player) = false — so AI-lane hurdles are ignored.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _player_notified:
		return
	if not GameState.is_racing():
		return

	var player_node := get_tree().get_first_node_in_group("player_character")
	if player_node == null:
		return

	# Only process hurdles that share the player's lane
	if not get_parent().is_ancestor_of(player_node):
		return

	# Player has fully cleared this hurdle once they are 20 px past it
	if player_node.global_position.x > global_position.x + 20.0:
		_player_notified = true
		if not _player_crashed and player_node.has_method("on_hurdle_cleared"):
			player_node.on_hurdle_cleared(type)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("trigger_momentum_crash"):
		# ── FIX: Pass the sabotage meta flag directly ────────────────────────
		# Original called trigger_momentum_crash() with no argument (default
		# false). The player's _on_hitbox_area_entered would call it again with
		# the correct flag, but is_stumbling is already true from this call, so
		# it returns early — ai_sabotage_hits was never incremented.
		# Passing has_meta("sabotage") here ensures the flag is set on the
		# FIRST call, regardless of signal ordering.
		_player_crashed = true
		body.trigger_momentum_crash(has_meta("sabotage"))
		print("Player hit a hurdle of type: ", "HIGH" if type == 0 else "LOW")
	elif body.has_method("_trigger_stumble"):
		body._trigger_stumble()
		print("AI hit a hurdle of type: ", "HIGH" if type == 0 else "LOW")
