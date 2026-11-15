class_name NumberFormat
extends RefCounted
## Short number texts for the screens, so that no screen shows raw seconds or
## four decimal places. Static functions only; they keep no state.
## Added for the "minimize text walls" redesign (design/minimize_text_walls_options.md).
##
##   money(12.5)        -> "$12.5M"     money in million USD
##   duration(16635)    -> "4h37m"      seconds as hours, minutes or seconds
##   points_total(81.6) -> "82"         whole points, for totals
##   points_row(16.25)  -> "16.3"       at most one decimal, for score rows
##   kilometers(400)    -> "400km"
##   meters_per_second(1234.5) -> "1235m/s"

const MINUS_SIGN := "−"


## Million USD as "$12.5M": at most one decimal, none for whole amounts.
## Negative amounts read "−$3M".
static func money(amount_million_usd: float) -> String:
	# Rounded first, so that a sign is shown only for what is shown: -0.04 is "$0M".
	var rounded_tenths: int = roundi(amount_million_usd * 10.0)
	var sign_text := MINUS_SIGN if rounded_tenths < 0 else ""
	return "%s$%sM" % [sign_text, _at_most_one_decimal(absf(rounded_tenths / 10.0))]


## Seconds as "4h37m", "12m05s" or "45s". Infinite or negative values read "--".
## Minutes are rounded down so that a duration never looks longer than it is.
@warning_ignore("integer_division")
static func duration(duration_seconds: float) -> String:
	if not is_finite(duration_seconds) or duration_seconds < 0.0:
		return "--"
	var whole_seconds: int = floori(duration_seconds)
	var hours: int = whole_seconds / 3600
	var minutes: int = (whole_seconds % 3600) / 60
	var seconds: int = whole_seconds % 60
	if hours > 0:
		return "%dh%02dm" % [hours, minutes]
	if minutes > 0:
		return "%dm%02ds" % [minutes, seconds]
	return "%ds" % seconds


## Whole points for a total, for example "82" or "−5".
static func points_total(points: float) -> String:
	var rounded_points: int = roundi(points)
	if rounded_points < 0:
		return "%s%d" % [MINUS_SIGN, -rounded_points]
	return "%d" % rounded_points


## Points for one score row: at most one decimal, none when whole, for
## example "16", "7.5" or "−15".
static func points_row(points: float) -> String:
	var sign_text := MINUS_SIGN if points < 0.0 and not is_zero_approx(roundf(points * 10.0)) else ""
	return sign_text + _at_most_one_decimal(absf(points))


## Kilometres as "400km", whole numbers; below 10 km with one decimal.
static func kilometers(distance_kilometers: float) -> String:
	if absf(distance_kilometers) < 10.0:
		return _signed(distance_kilometers, _at_most_one_decimal(absf(distance_kilometers))) + "km"
	return _signed(distance_kilometers, "%d" % roundi(absf(distance_kilometers))) + "km"


## Metres per second as "1235m/s", whole numbers; below 10 with one decimal.
static func meters_per_second(speed_meters_per_second: float) -> String:
	if absf(speed_meters_per_second) < 10.0:
		return _signed(speed_meters_per_second, _at_most_one_decimal(absf(speed_meters_per_second))) + "m/s"
	return _signed(speed_meters_per_second, "%d" % roundi(absf(speed_meters_per_second))) + "m/s"


## A number with an explicit sign, for differences: "+42", "−7.5", "0".
static func signed_difference(value: float) -> String:
	var text := _at_most_one_decimal(absf(value)) if absf(value) < 10.0 else "%d" % roundi(absf(value))
	if text == "0":
		return "0"
	return ("+" if value > 0.0 else MINUS_SIGN) + text


## A plain number with at most one decimal and no trailing ".0", for chips.
static func compact(value: float) -> String:
	return _signed(value, _at_most_one_decimal(absf(value)))


@warning_ignore("integer_division")
static func _at_most_one_decimal(non_negative_value: float) -> String:
	var tenths: int = roundi(non_negative_value * 10.0)
	if tenths % 10 == 0:
		return "%d" % (tenths / 10)
	return "%d.%d" % [tenths / 10, tenths % 10]


static func _signed(value: float, magnitude_text: String) -> String:
	if value < 0.0 and magnitude_text != "0":
		return MINUS_SIGN + magnitude_text
	return magnitude_text
