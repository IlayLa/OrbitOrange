extends Control
## Gives a script-less Control a wrapped PixelTooltip instead of the engine's
## single-line tooltip. Attach it with PixelTooltip.attach(control); it works
## on any Control subclass (Button, Label...) because it only adds this hook.


func _make_custom_tooltip(for_text: String) -> Object:
	return PixelTooltip.for_control(self, for_text)
