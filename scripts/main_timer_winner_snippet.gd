## main_timer_winner_snippet.gd
## ─── ADD THIS TO YOUR EXISTING main.gd ───────────────────────────────────────
##
## This is the timer-expiry winner resolution block.
## If the 60-second timer runs out before anyone crosses the finish line,
## main.gd must set GameState.winner BEFORE making the ResultsMenu visible.
## Otherwise the results menu shows "It's a Tie" because winner is still "".
##
## Find your existing timer callback in main.gd (something like
## _on_race_timer_timeout or wherever you call set_phase(FINISHED) on timeout)
## and add the block below BEFORE you show the results menu.

# ── PASTE THIS into your race-timer-expired handler in main.gd ───────────────

func _resolve_winner_by_distance() -> void:
	## Called when the 60-second timer expires (Phase 4 → Phase 5).
	## Determines winner by distance, then KEI tiebreaker (GDD Table 5).

	if GameState.is_racing():            # only resolve if race hasn't ended yet
		if GameState.player_position > GameState.ai_position:
			GameState.winner = "Player"
		elif GameState.ai_position > GameState.player_position:
			GameState.winner = "AI"
		else:
			# Exact position tie → KEI tiebreaker (GDD Section III.A)
			if GameState.player_kei >= GameState.ai_kei:
				GameState.winner = "Player"
			else:
				GameState.winner = "AI"
			# Note: a true winner is always determined; "It's a Tie" is
			# unreachable in normal gameplay per the GDD rules.

		print("[Main] Timer expired. Winner resolved: '", GameState.winner, "'")
		GameState.set_phase(GameState.RacePhase.FINISHED)

## ── HOW TO WIRE IT ──────────────────────────────────────────────────────────
## In your existing timer signal callback, replace or add:
##
##   func _on_race_timer_timeout():        # or whatever your timer callback is
##       _resolve_winner_by_distance()     # ← add this line BEFORE set_phase
##
## Then phase_changed fires → main.gd shows ResultsMenu → visibility changed
## → results_menu._refresh_winner_label() reads the correct GameState.winner.
