class_name BannerClock
extends RefCounted
## E6 (D-294.5): the one rule of the banner system (S3, D-175), pure: no scene access, no tuning reads (the durations are arguments).
## State: the seconds left of the showing banner (0 = none showing), its text, and the texts waiting. A new banner shortens the showing
## one to `min_s`; a banner shown while others wait plays `min_s`; otherwise it plays `time`. The HUD owns one (it draws what the clock
## says) and the PhaseController owns another, advanced per physics tick, to learn when the real one is free and whether a line was cut.

var left := 0.0
var current := ""
## True when the showing banner will end before its full time (cut by an arrival, or shown while others waited).
var current_cut := false
var queue: Array[String] = []
## The banner that last ended or was replaced, and whether it was cut: read, then `clear_ended`.
var ended := ""
var ended_cut := false
var _has_ended := false

## A banner arrives. Returns true when it started showing at once.
func arrive(text: String, time: float, min_s: float) -> bool:
	queue.append(text)
	if left <= 0.0:
		return show_next(time, min_s)
	if left > min_s:
		current_cut = true
	left = minf(left, min_s)
	return false

## Starts the next waiting banner. False (and nothing showing) when none waits.
func show_next(time: float, min_s: float) -> bool:
	if current != "" or left > 0.0:
		ended = current
		ended_cut = current_cut
		_has_ended = true
	if queue.is_empty():
		left = 0.0
		current = ""
		current_cut = false
		return false
	current = queue.pop_front()
	current_cut = not queue.is_empty() and min_s < time
	left = time if queue.is_empty() else minf(time, min_s)
	return true

## Moves the clock on by `dt`. Returns true when the showing banner ended and the next one (if any) started: `current` is then the new text.
func advance(dt: float, time: float, min_s: float) -> bool:
	if left <= 0.0:
		return false
	left -= dt
	if left <= 0.0:
		show_next(time, min_s)
		return true
	return false

func showing() -> bool:
	return left > 0.0

## Nothing showing and nothing waiting: a banner sent now is shown in full.
func is_idle() -> bool:
	return left <= 0.0 and queue.is_empty()

## True once when a banner has ended since the last call; then `ended` and `ended_cut` say which and how.
func take_ended() -> bool:
	var r := _has_ended
	_has_ended = false
	return r
