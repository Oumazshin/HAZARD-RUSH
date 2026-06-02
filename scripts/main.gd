extends Node2D

const EARTH_SPIKE_DIR : String = "res://assets/new/Earth_Spike/"

@onready var results_menu = get_node_or_null("ResultsMenu")
@onready var hud : CanvasLayer = get_node_or_null("HUD")

var results_shown : bool  = false
var time_left     : float = 60.0

func _ready() -> void:
	if results_menu:
		results_menu.hide()

	# Remove any leftover editor countdown labels
	if hud:
		for child in hud.get_children():
			if child is Label or "Countdown" in child.name:
				child.queue_free()

	GameState.set_phase(GameState.RacePhase.PRE_MATCH)

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui and game_ui.has_method("run_countdown"):
		game_ui.run_countdown()

		# FIX: Wait for the exact moment "GO!" appears on screen.
		# Old code used create_timer(3.0) which fired during the "1" beat —
		# both racers could already be moving before "GO!" was visible.
		# game_ui now emits countdown_go_reached when "GO!" text is set,
		# so we await that signal rather than a guessed fixed duration.
		if game_ui.has_signal("countdown_go_reached"):
			await game_ui.countdown_go_reached
		else:
			# Fallback: full 3-2-1-GO animation is ~3.95 s
			await get_tree().create_timer(3.95).timeout

	GameState.set_phase(GameState.RacePhase.RACING)

func _process(delta: float) -> void:
	if GameState.is_racing():
		time_left -= delta
		if time_left <= 0.0 and not results_shown:
			time_left = 0.0
			_finish_race("time_up")

		GameState.match_timer = time_left

		if GameState.has_signal("match_timer_updated"):
			GameState.match_timer_updated.emit(time_left)

func _finish_race(reason: String) -> void:
	if results_shown: return
	results_shown = true
	GameState.win_reason = reason
	GameState.set_phase(GameState.RacePhase.FINISHED)

	if results_menu:
		results_menu.show()
