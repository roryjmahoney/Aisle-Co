class_name Fmt
extends RefCounted
## Text formatting helpers. Money is always integer cents internally.


static func money(cents: int, show_cents: bool = true) -> String:
	var neg := cents < 0
	var c := absi(cents)
	var dollars := c / 100
	var s := _group(dollars)
	if show_cents:
		s += ".%02d" % (c % 100)
	return ("−$" if neg else "$") + s


static func money_signed(cents: int) -> String:
	return ("+" if cents > 0 else "") + money(cents)


static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


static func percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
