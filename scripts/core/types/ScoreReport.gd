class_name ScoreReport
extends RefCounted
## The final score with its explanation. Scoring.compute_score creates it;
## the final screen displays it.

var total_points: float = 0.0
## "Failure", "Partial Success", "Success", "Great Success", "Perfect" or "Scientific Breakthrough".
var band_name: String = ""
## True when the craft never reached orbit: total_points is 0 and a special screen is shown.
var is_launch_failure: bool = false
var lines: Array[ScoreLine] = []
