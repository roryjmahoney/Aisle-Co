class_name SimClock
extends RefCounted
## Business time. One simulation second at 1x speed is two in-game minutes,
## so an opening day (08:00–20:00) takes six real minutes at normal speed.

signal minute_changed(day: int, minute: int)
signal phase_changed(phase: int)
signal day_started(day: int)

enum Phase { PREOPEN, OPEN, CLOSING, CLOSED }

const MINUTES_PER_SECOND := 2.0
const DAY_START := 7 * 60
const OPEN_AT := 8 * 60
const CLOSE_AT := 20 * 60

var day := 1
var minute := float(DAY_START)
var phase := Phase.PREOPEN
var _last_whole := -1


func step(dt: float) -> void:
	if phase == Phase.CLOSED:
		return
	minute += dt * MINUTES_PER_SECOND
	var whole := int(minute)
	if whole != _last_whole:
		_last_whole = whole
		minute_changed.emit(day, whole)
	if phase == Phase.PREOPEN and minute >= OPEN_AT:
		_set_phase(Phase.OPEN)
	elif phase == Phase.OPEN and minute >= CLOSE_AT:
		_set_phase(Phase.CLOSING)


func finish_closing() -> void:
	## Called once the last shopper has left after closing time.
	if phase == Phase.CLOSING:
		_set_phase(Phase.CLOSED)


func start_next_day() -> void:
	day += 1
	minute = float(DAY_START)
	_last_whole = -1
	_set_phase(Phase.PREOPEN)
	day_started.emit(day)


func open_now() -> void:
	## Skip the morning setup hour.
	if phase == Phase.PREOPEN:
		minute = float(OPEN_AT)
		_set_phase(Phase.OPEN)


func is_open() -> bool:
	return phase == Phase.OPEN


func absolute_minute() -> float:
	return (day - 1) * 1440.0 + minute


func time_string() -> String:
	var m := int(minute)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


func day_fraction() -> float:
	return fmod(minute, 1440.0) / 1440.0


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func to_dict() -> Dictionary:
	return {"day": day, "minute": minute, "phase": phase}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minute = float(d.get("minute", DAY_START))
	phase = int(d.get("phase", Phase.PREOPEN))
	_last_whole = -1
