extends Node
## Tests source isolation, immutable registrations and invalid attribute definitions.

const ModifierType = GameplayAttributeModifier.ModifierType
var _failures: Array[String] = []

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
