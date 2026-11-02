extends GameplayEffect
## Records execution without rendering, attributes or host entities.
func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
	target.set_meta("effect_count", int(target.get_meta("effect_count", 0)) + 1)
