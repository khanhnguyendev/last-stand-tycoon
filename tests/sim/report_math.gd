class_name ReportMath
extends RefCounted
## Pure statistics of the report scripts (tests/sim/report_*.gd). Plain arrays in, numbers out; no autoloads.

## Median of the values; 0.0 for an empty list. Even counts average the two middle values.
static func median(values: Array) -> float:
	return percentile(values, 50.0)

## Linear-interpolation percentile (p in 0..100) of the values; 0.0 for an empty list.
static func percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	var pos := clampf(p, 0.0, 100.0) / 100.0 * float(s.size() - 1)
	var lo := int(floor(pos))
	var hi := int(ceil(pos))
	return float(s[lo]) + (float(s[hi]) - float(s[lo])) * (pos - float(lo))
