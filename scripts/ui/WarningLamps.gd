class_name WarningLamps
extends RefCounted
## Turns the sentences of PlanSummary.warnings into warning lamps that can sit
## on the stage, pulse or rocket they are about (Option 1, "Warning lamps").
##
## The PlanSummary contract carries plain sentences only, so this is done on
## the screen side: a sentence in blocking_problems is BLOCKING, any other is
## a WARNING, and "Stage N" or "Pulse N" in the sentence attaches the lamp to
## that stage or pulse. Duplicate sentences are shown once. Nothing decides
## game rules from this; it only chooses where a lamp is drawn.
## Static functions only.

enum Severity { OK, WARNING, BLOCKING }

## Short target names shown next to a lamp in the bezel.
const ROCKET_TARGET_TEXT := "ROCKET"


## One Dictionary per distinct sentence, blocking ones first:
##   "severity"      Severity
##   "sentence"      the sentence without the "Warning:" prefix
##   "stage_number"  1 for the bottom stage, 0 when the sentence names no stage
##   "pulse_number"  1 for the first pulse, 0 when it names no pulse
##   "target_text"   "S2", "P1" or "ROCKET"
## An empty list (or a null summary) means every lamp is OK.
static func lamps_from_summary(summary: PlanSummary) -> Array[Dictionary]:
	var lamps: Array[Dictionary] = []
	if summary == null:
		return lamps
	var seen_sentences: Dictionary = {}
	for blocking_problem in summary.blocking_problems:
		_add_lamp(lamps, seen_sentences, blocking_problem, Severity.BLOCKING)
	for warning in summary.warnings:
		_add_lamp(lamps, seen_sentences, warning,
				Severity.BLOCKING if summary.blocking_problems.has(warning) else Severity.WARNING)
	return lamps


## The worst severity among the lamps of one stage (1 = bottom stage).
static func worst_severity_for_stage(lamps: Array[Dictionary], stage_number: int) -> Severity:
	var worst: Severity = Severity.OK
	for lamp in lamps:
		if lamp["stage_number"] == stage_number:
			worst = maxi(worst, lamp["severity"]) as Severity
	return worst


## The worst severity among the lamps of one pulse (1 = first pulse). For the
## pulse markers of the orbit planning screen.
static func worst_severity_for_pulse(lamps: Array[Dictionary], pulse_number: int) -> Severity:
	var worst: Severity = Severity.OK
	for lamp in lamps:
		if lamp["pulse_number"] == pulse_number:
			worst = maxi(worst, lamp["severity"]) as Severity
	return worst


## The sentences of one stage's lamps, joined, for a hover bubble.
static func sentences_for_stage(lamps: Array[Dictionary], stage_number: int) -> String:
	var sentences: PackedStringArray = []
	for lamp in lamps:
		if lamp["stage_number"] == stage_number:
			sentences.append(lamp["sentence"])
	return " ".join(sentences)


## How many lamps are BLOCKING and how many are WARNING, as Vector2i(blocking, warning).
static func counts(lamps: Array[Dictionary]) -> Vector2i:
	var result := Vector2i.ZERO
	for lamp in lamps:
		if lamp["severity"] == Severity.BLOCKING:
			result.x += 1
		elif lamp["severity"] == Severity.WARNING:
			result.y += 1
	return result


static func _add_lamp(lamps: Array[Dictionary], seen_sentences: Dictionary, raw_sentence: String, severity: Severity) -> void:
	var sentence := raw_sentence.strip_edges()
	if sentence.begins_with(RocketModel.WARNING_PREFIX):
		sentence = sentence.trim_prefix(RocketModel.WARNING_PREFIX).strip_edges()
	if sentence.is_empty() or seen_sentences.has(sentence):
		return
	seen_sentences[sentence] = true
	var stage_number := _number_after(sentence, "Stage ")
	var pulse_number := _number_after(sentence, "Pulse ")
	var target_text := ROCKET_TARGET_TEXT
	if pulse_number > 0:
		target_text = "P%d" % pulse_number
	elif stage_number > 0:
		target_text = "S%d" % stage_number
	lamps.append({
		"severity": severity,
		"sentence": sentence,
		"stage_number": stage_number,
		"pulse_number": pulse_number,
		"target_text": target_text,
	})


## The whole number that follows the first match of word in sentence, or 0.
static func _number_after(sentence: String, word: String) -> int:
	var word_position := sentence.find(word)
	if word_position < 0:
		return 0
	var digits := ""
	for character_index in range(word_position + word.length(), sentence.length()):
		var character := sentence[character_index]
		if character < "0" or character > "9":
			break
		digits += character
	return int(digits) if not digits.is_empty() else 0
