extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var is_player := body.is_in_group("player")
	var is_ai     := body.is_in_group("ai")

	if not is_player and not is_ai:
		return

	if not GameState.is_racing():
		return

	GameState.winner     = "Player" if is_player else "AI"
	GameState.win_reason = "finish_line"

	print("[Goal] winner → ", GameState.winner)
	GameState.set_phase(GameState.RacePhase.FINISHED)
