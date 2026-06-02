extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not has_node("FinishLineVisual"):
		var fl: Node2D = preload("res://scripts/Lane/finish_line.gd").new()
		fl.name = "FinishLineVisual"
		add_child(fl)

func _on_body_entered(body: Node2D) -> void:
	var is_player := body.is_in_group("player")
	var is_ai     := body.is_in_group("ai")

	if not is_player and not is_ai:
		return

	if not GameState.is_racing():
		return

	# FIX: Original used "Player" (capital P) and "AI" (capital letters).
	# results_screen.gd matches against lowercase "player" / "ai", so a
	# finish-line win by the human player always fell through to the tie
	# branch and displayed "IT'S A TIE!" instead of "PLAYER WINS!".
	GameState.winner     = "player" if is_player else "ai"
	GameState.win_reason = "finish_line"

	print("[Goal] winner → ", GameState.winner)
	GameState.set_phase(GameState.RacePhase.FINISHED)
