extends Node
## Verifies typed default isolation and loading nested effects from legacy resources.

const COUNTER = preload("res://addons/godot_gameplay_abilities/tests/counting_effect.gd")
const LEGACY_COMPOSITE_PATH: String = "res://addons/godot_gameplay_abilities/tests/legacy_composite_effect.tres"

func _ready() -> void:
	var first: GameplayEffect = COUNTER.new()
	var second: GameplayEffect = COUNTER.new()
	var children: Array[GameplayEffect] = first.sub_effects
	children.append(second)
	if first.sub_effects.size() != 1 or not second.sub_effects.is_empty():
		push_error("New effects must own independent typed child arrays")
		get_tree().quit.call_deferred(1)
		return
	var legacy: GameplayEffect = load(LEGACY_COMPOSITE_PATH) as GameplayEffect
	if (legacy == null or legacy.sub_effects.size() != 1 or legacy.sub_effects[0] == null
			or legacy.sub_effects[0].sub_effects.size() != 1):
		push_error("Legacy typed resources must retain both levels of nested children")
		get_tree().quit.call_deferred(1)
		return
	legacy.apply(self, null)
	if get_meta("effect_count", 0) != 3:
		push_error("All three legacy effects must execute")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: GAS typed composite effect resources and independent defaults")
	get_tree().quit.call_deferred(0)
