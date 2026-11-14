extends Node
## Tests source isolation, immutable registrations and invalid attribute definitions.

const ModifierType = GameplayAttributeModifier.ModifierType
var _failures: Array[String] = []

class CombinedAttributes extends GameplayAttributeSet:
	func on_attribute_changed(component: GameplayAttributeComponent, id: StringName, _value: float) -> void:
		if id == &"attack" or id == &"defense":
			component.set_base_value(&"combined", component.get_value(&"attack") + component.get_value(&"defense"))

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var target: Node = Node.new()
	add_child(target)
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	component.name = &"GameplayAttributeComponent"
	target.add_child(component)
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[_definition(&"attack")] = 10.0
	attribute_set.attributes[_definition(&"attack")] = 20.0
	attribute_set.attributes[_definition(&"")] = 9.0
	attribute_set.attributes[_definition(&"  ")] = 9.0
	attribute_set.attributes[_definition(&"defense")] = 2.0
	component.initialize([attribute_set])
	_expect(component.get_value(&"attack") == 10.0 and component.get_value(&"defense") == 2.0,
		"duplicate IDs preserve the first definition and other attributes still initialize")
	_expect(not component.has_attribute(&"") and not component.has_attribute(&"  "), "blank IDs are skipped")
	_test_effect_sources(target, component)
	_test_modifier_snapshots(component)
	_test_source_removal_batch()
	_test_effect_apply_batch()
	_test_nonfinite_attribute_writes()
	_test_nonfinite_attribute_results()
	_test_cold_attribute_cache()
	target.free()
	for failure: String in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: GAS attribute sources, snapshots and definitions")
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

func _test_effect_sources(target: Node, component: GameplayAttributeComponent) -> void:
	var first: GE_AttributeModifier = _effect(3.0)
	var second: GE_AttributeModifier = _effect(5.0)
	first.apply(target, self)
	second.apply(target, self, {"source_id": &""})
	_expect(component.get_value(&"attack") == 18.0, "anonymous effects can coexist")
	first.remove(target, self)
	_expect(component.get_value(&"attack") == 15.0, "removing one anonymous effect preserves the other")
	second.remove(target, self)
	first.source_id = &"shared"
	second.source_id = &"shared"
	first.apply(target, self)
	second.apply(target, self, {"source_id": &"status-token"})
	first.remove(target, self)
	_expect(component.get_value(&"attack") == 15.0, "context source takes precedence over the configured group")
	var removal_copy: GE_AttributeModifier = second.duplicate() as GE_AttributeModifier
	removal_copy.remove(target, self, {"source_id": &"status-token"})
	_expect(component.get_value(&"attack") == 10.0, "explicit context supports removal through a duplicate")

func _test_modifier_snapshots(component: GameplayAttributeComponent) -> void:
	var mod: GameplayAttributeModifier = GameplayAttributeModifier.new(&"attack", 3.0, ModifierType.ADD, &"gear")
	var other: GameplayAttributeInstance = GameplayAttributeInstance.new(_definition(&"attack"), 10.0)
	component.add_modifier(mod)
	other.add_modifier(mod)
	mod.value = 8.0
	mod.modifier_type = ModifierType.MULTIPLY
	mod.source_id = &"edited"
	mod.attribute_id = &"defense"
	component.set_base_value(&"attack", 11.0)
	_expect(component.get_value(&"attack") == 14.0 and other.get_value() == 13.0,
		"shared resource edits do not alter either registration, including after recomputation")
	other.remove_modifiers_by_source(&"gear")
	component.remove_modifier(mod)
	_expect(component.get_value(&"attack") == 11.0 and other.get_value() == 10.0,
		"identity and original source both remove edited resources")
	component.add_modifier(mod)
	_expect(component.get_value(&"defense") == 18.0, "re-registering uses the edited configuration")
	component.remove_modifiers_by_source(&"edited")
	_expect(component.get_value(&"defense") == 2.0, "source removal also clears the re-registration")

func _test_source_removal_batch() -> void:
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[_definition(&"attack")] = 10.0
	attribute_set.attributes[_definition(&"defense")] = 20.0
	component.initialize([attribute_set])
	component.add_modifier(GameplayAttributeModifier.new(&"attack", 5.0, ModifierType.ADD, &"gear"))
	component.add_modifier(GameplayAttributeModifier.new(&"defense", 5.0, ModifierType.ADD, &"gear"))
	var snapshots: Array[Vector2] = []
	var observe: Callable = func(_id: StringName, _value: float) -> void:
		snapshots.append(Vector2(component.get_value(&"attack"), component.get_value(&"defense")))
	component.attribute_value_changed.connect(observe)
	component.remove_modifiers_by_source(&"gear")
	component.remove_modifiers_by_source(&"gear")
	_expect(snapshots == [Vector2(10.0, 20.0), Vector2(10.0, 20.0)],
		"source removal publishes each change once after the entire batch")
	component.attribute_value_changed.disconnect(observe)
	component.free()

func _test_effect_apply_batch() -> void:
	var target: Node = Node.new()
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	component.name = &"GameplayAttributeComponent"
	target.add_child(component)
	var attribute_set: GameplayAttributeSet = CombinedAttributes.new()
	attribute_set.attributes[_definition(&"attack")] = 10.0
	attribute_set.attributes[_definition(&"defense")] = 20.0
	attribute_set.attributes[_definition(&"combined")] = 30.0
	component.initialize([attribute_set])
	var snapshots: Dictionary[StringName, Vector3] = {}
	var events: Array[StringName] = []
	component.attribute_value_changed.connect(func(id: StringName, _value: float) -> void:
		events.append(id)
		snapshots[id] = Vector3(component.get_value(&"attack"), component.get_value(&"defense"),
			component.get_value(&"combined"))
	)
	var effect: GE_AttributeModifier = _effect(2.0)
	effect.modifiers.append(GameplayAttributeModifier.new(&"attack", 3.0, ModifierType.ADD))
	effect.modifiers.append(GameplayAttributeModifier.new(&"defense", 5.0, ModifierType.ADD))
	effect.apply(target, self)
	var final_values: Vector3 = Vector3(15.0, 25.0, 40.0)
	_expect(events.size() == 3 and snapshots == {&"attack": final_values, &"defense": final_values, &"combined": final_values},
		"one effect publishes each changed attribute once and every callback sees the whole batch")
	effect.remove(target, self)
	_expect(component.get_value(&"attack") == 10.0 and component.get_value(&"defense") == 20.0 and
		component.get_value(&"combined") == 30.0,
		"removal clears every registration in the applied effect")
	target.free()

func _test_nonfinite_attribute_writes() -> void:
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[_definition(&"attack")] = 10.0
	attribute_set.attributes[_definition(&"invalid_seed")] = INF
	component.initialize([attribute_set])
	var values: Array[float] = []
	component.attribute_value_changed.connect(func(_id: StringName, value: float) -> void: values.append(value))
	var instance: GameplayAttributeInstance = component.get_attribute(&"attack")
	for invalid: float in [NAN, INF, -INF]:
		_expect(not component.set_base_value(&"attack", invalid), "component rejects non-finite base writes")
		instance.base_value = invalid
		component.add_modifier(GameplayAttributeModifier.new(&"attack", invalid, ModifierType.ADD))
	_expect(not component.has_attribute(&"invalid_seed") and instance.base_value == 10.0 and
		component.get_value(&"attack") == 10.0 and values.is_empty(),
		"invalid seeds, direct base writes and modifiers do not enter runtime values")
	component.set_base_value(&"attack", 11.0)
	_expect(values == [11.0], "a finite write still updates and publishes")
	component.free()

func _test_nonfinite_attribute_results() -> void:
	var definition: GameplayAttribute = _definition(&"power")
	var instance: GameplayAttributeInstance = GameplayAttributeInstance.new(definition, 1.0e308)
	var events: Array[float] = []
	instance.value_changed.connect(func(_old: float, value: float) -> void: events.append(value))
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new(&"power", 2.0, ModifierType.MULTIPLY)
	instance.add_modifier(modifier)
	_expect(is_finite(instance.get_value()) and events.is_empty(),
		"overflow from finite inputs cannot enter the attribute cache or signals")
	instance.base_value = 2.0
	_expect(instance.get_value() == 6.0 and events == [6.0],
		"the same registered modifier works again after a finite recalculation")
	var invalid_bounds: GameplayAttribute = _definition(&"bounded")
	invalid_bounds.min_value = INF
	invalid_bounds.max_value = -INF
	var bounded: GameplayAttributeInstance = GameplayAttributeInstance.new(invalid_bounds, 10.0)
	_expect(bounded.get_value() == 10.0, "invalid infinite bounds cannot force a non-finite value")

func _test_cold_attribute_cache() -> void:
	var definition: GameplayAttribute = _definition(&"bounded")
	definition.min_value = 10.0
	var instance: GameplayAttributeInstance = GameplayAttributeInstance.new(definition, 0.0)
	var events: Array[Vector2] = []
	instance.value_changed.connect(func(old: float, value: float) -> void: events.append(Vector2(old, value)))
	instance.base_value = 1.0
	_expect(events.is_empty(), "a first write under the minimum does not publish a false change")
	instance.base_value = 12.0
	_expect(events == [Vector2(10.0, 12.0)], "the first real change reports the clamped old value")

func _definition(id: StringName) -> GameplayAttribute:
	var definition: GameplayAttribute = GameplayAttribute.new()
	definition.attribute_id = id
	return definition

func _effect(amount: float) -> GE_AttributeModifier:
	var effect: GE_AttributeModifier = GE_AttributeModifier.new()
	effect.attribute_component_name = &"GameplayAttributeComponent"
	effect.modifiers = [GameplayAttributeModifier.new(&"attack", amount, ModifierType.ADD)]
	return effect

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
