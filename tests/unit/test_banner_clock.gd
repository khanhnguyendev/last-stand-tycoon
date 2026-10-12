extends GutTest
## E6 (D-294.5): the pure banner rule shared by the HUD and the PhaseController. T = banner_time 2.0, M = banner_min_s 0.6 in every call.

const T := 2.0
const M := 0.6

func _run(c: BannerClock, secs: float) -> void:
	for i in int(round(secs * 60.0)):
		c.advance(1.0 / 60.0, T, M)

## Mutation: an idle arrival is queued instead of shown, or plays another time.
func test_a_banner_on_an_idle_clock_shows_at_once_for_the_full_time() -> void:
	var c := BannerClock.new()
	assert_true(c.is_idle())
	assert_true(c.arrive("A", T, M))
	assert_eq(c.current, "A")
	assert_almost_eq(c.left, T, 1e-6)
	assert_false(c.is_idle())
	assert_false(c.current_cut)
	assert_true(c.queue.is_empty())

## Mutation: the showing banner is not cut, or is cut to something other than banner_min_s, or a short one is lengthened.
func test_an_arrival_cuts_the_showing_banner_to_min_and_marks_it_cut() -> void:
	var c := BannerClock.new()
	c.arrive("A", T, M)
	_run(c, 0.5)
	assert_false(c.arrive("B", T, M))
	assert_almost_eq(c.left, M, 1e-6)
	assert_true(c.current_cut)
	assert_eq(c.queue, ["B"] as Array[String])
	var d := BannerClock.new()
	d.arrive("A", T, M)
	_run(d, 1.6)  # 0.4 left: already under the minimum
	d.arrive("B", T, M)
	assert_almost_eq(d.left, 0.4, 0.02, "never lengthened")
	assert_false(d.current_cut, "it ends within its natural time")

## Mutation: the banner after a cut plays less or more than its full time; ended/cut flags wrong.
func test_the_next_banner_plays_in_full_when_alone_and_the_cut_one_is_reported() -> void:
	var c := BannerClock.new()
	c.arrive("A", T, M)
	_run(c, 0.5)
	c.arrive("B", T, M)
	_run(c, M + 0.05)
	assert_eq(c.current, "B")
	assert_true(c.take_ended())
	assert_eq(c.ended, "A")
	assert_true(c.ended_cut)
	assert_false(c.take_ended(), "reported once")
	assert_almost_eq(c.left, T - 0.05, 0.05)
	assert_false(c.current_cut)
	_run(c, T)
	assert_true(c.is_idle())
	assert_true(c.take_ended())
	assert_eq(c.ended, "B")
	assert_false(c.ended_cut, "B had its full time")

## Mutation: a banner shown while others wait plays the full time (the fail path, D-175).
func test_a_banner_shown_while_others_wait_plays_the_minimum() -> void:
	var c := BannerClock.new()
	c.arrive("A", T, M)
	c.arrive("B", T, M)
	c.arrive("C", T, M)
	_run(c, M + 0.02)
	assert_eq(c.current, "B")
	assert_almost_eq(c.left, M, 0.03, "B waits for C: minimum")
	assert_true(c.current_cut)
	_run(c, M + 0.02)
	assert_eq(c.current, "C")
	assert_almost_eq(c.left, T, 0.05)
