extends Node
## Verifies settled component notifications and bounded dependency propagation.

class DiamondSet extends GameplayAttributeSet:
	func resolve_dependencies(component: GameplayAttributeComponent) -> void:
		on_attribute_changed(component, &"root", component.get_value(&"root"))

	func on_attribute_changed(component: GameplayAttributeComponent, id: StringName, value: float) -> void:
		match id:
			&"root":
				component.set_base_value(&"left", value + 2.0)
				component.set_base_value(&"right", value + 4.0)
			&"left", &"right":
				component.set_base_value(&"total", component.get_value(&"left") + component.get_value(&"right"))

class CyclicSet extends GameplayAttributeSet:
	var visits: Array[StringName] = []
	var back_edge_rejected: bool = false
	@export var write_through_instance: bool = false

	func on_attribute_changed(component: GameplayAttributeComponent, id: StringName, value: float) -> void:
		visits.append(id)
		# Bounds the fixture on the old implementation as well.
		if visits.size() >= 12:
			return
		match id:
			&"a":
				component.set_base_value(&"b", value + 1.0)
				component.set_base_value(&"independent", 4.0)
			&"b":
				if write_through_instance:
					component.get_attribute(&"a").base_value = value + 1.0
				else:
					back_edge_rejected = not component.set_base_value(&"a", value + 1.0)

class PrecisionSet extends GameplayAttributeSet:
	func resolve_dependencies(component: GameplayAttributeComponent) -> void:
		on_attribute_changed(component, &"root", component.get_value(&"root"))

	func on_attribute_changed(component: GameplayAttributeComponent, id: StringName, value: float) -> void:
		if id == &"root":
			component.set_base_value(&"scaled", value * 100000.0)
			component.set_base_value(&"max_health", value)
		elif id == &"scaled":
			component.set_base_value(&"total", value + component.get_value(&"root"))

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_snapshots()
	_test_cycle(false)
	_test_cycle(true)
	_test_small_writes(false)
	_test_small_writes(true)
	_test_small_modifiers()
	_test_small_reinitialization()
	_test_unchanged_effective_values()
	for failure: String in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: GAS settled attribute snapshots and cycle diagnostics")
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

func _test_snapshots() -> void:
	var definition: DiamondSet = DiamondSet.new()
	_add_attributes(definition, [&"root", &"left", &"right", &"total"])
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	var ids: Array[StringName] = []
	var totals: Array[float] = []
	component.attribute_value_changed.connect(func(id: StringName, _value: float) -> void:
		ids.append(id)
		totals.append(component.get_value(&"total"))
	)
	component.initialize([definition])
	_expect(totals == [6.0, 6.0, 6.0], "initialization publishes only settled values")
	ids.clear()
	totals.clear()
	component.set_base_value(&"root", 3.0)
	_expect(ids == [&"root", &"left", &"total", &"right"], "each changed attribute is notified once in first-change order")
	_expect(totals == [12.0, 12.0, 12.0, 12.0], "all subscribers read the same settled total")
	component.free()

func _test_cycle(write_through_instance: bool) -> void:
	var definition: CyclicSet = CyclicSet.new()
	definition.write_through_instance = write_through_instance
	_add_attributes(definition, [&"a", &"b", &"independent"])
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	component.initialize([definition])
	var active: CyclicSet = component._active_sets[0] as CyclicSet
	component.set_base_value(&"a", 1.0)
	_expect(active.visits == [&"a", &"b", &"independent"], "a back edge stops without blocking an independent branch")
	if write_through_instance:
		_expect(component.get_value(&"a") == 3.0, "direct instance write is recorded without recurring")
	else:
		_expect(active.back_edge_rejected and component.get_value(&"a") == 1.0, "component rejects the cyclic base write")
	_expect(component.get_value(&"b") == 2.0 and component.get_value(&"independent") == 4.0,
		"completed dependency branches retain their values")
	component.free()

func _test_small_writes(direct: bool) -> void:
	var component: GameplayVitalAttributeComponent = _precision_component()
	var notifications: Array[StringName] = []
	var inconsistent: Array[StringName] = []
	component.attribute_value_changed.connect(func(id: StringName, _value: float) -> void:
		notifications.append(id)
		if not _precision_snapshot_matches(component):
			inconsistent.append(id)
	)
	for step: int in range(1, 1001):
		var value: float = 1.1 + float(step) * 0.000001
		if direct:
			component.get_attribute(&"root").base_value = value
		else:
			component.set_base_value(&"root", value)
		_expect(_precision_snapshot_matches(component), "every small write settles its dependency chain and Vital maximum")
	_expect(absf(component.get_value(&"scaled") - 110100.0) < 0.00000001,
		"a thousand small changes accumulate to the correct derived value")
	_expect(notifications.size() == 4000 and inconsistent.is_empty(),
		"each effective change publishes a settled snapshot including the tiny root and maximum changes")
	component.free()

func _test_small_modifiers() -> void:
	var component: GameplayVitalAttributeComponent = _precision_component()
	var ids: Array[StringName] = []
	component.attribute_value_changed.connect(func(id: StringName, _value: float) -> void: ids.append(id))
	var delta: float = 1.0 / 1048576.0
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new(
		&"root", delta, GameplayAttributeModifier.ModifierType.ADD, &"tiny")
	component.add_modifier(modifier)
	_expect(component.get_value(&"root") == 1.1 + delta and _precision_snapshot_matches(component) and ids.size() == 4,
		"a tiny modifier updates dependencies and publishes all changed values")
	ids.clear()
	component.remove_modifiers_by_source(&"tiny")
	_expect(component.get_value(&"root") == 1.1 and _precision_snapshot_matches(component) and ids.size() == 4,
		"removing a tiny modifier restores dependencies and notifies subscribers")
	ids.clear()
	var opposite: GameplayAttributeModifier = GameplayAttributeModifier.new(
		&"root", -delta, GameplayAttributeModifier.ModifierType.ADD, &"tiny")
	component.add_modifiers([modifier, opposite])
	_expect(ids.is_empty() and _precision_snapshot_matches(component), "a batch with no net effective change stays silent")
	component.remove_modifiers_by_source(&"tiny")
	_expect(ids.is_empty() and _precision_snapshot_matches(component), "removing a cancelling source also stays silent")
	component.free()

func _test_small_reinitialization() -> void:
	var component: GameplayVitalAttributeComponent = _precision_component()
	var ids: Array[StringName] = []
	var inconsistent: Array[StringName] = []
	component.attribute_value_changed.connect(func(id: StringName, _value: float) -> void:
		ids.append(id)
		if not _precision_snapshot_matches(component):
			inconsistent.append(id)
	)
	component.initialize([_precision_set(1.100001)])
	_expect(ids.size() == 4 and ids.has(&"root") and ids.has(&"max_health") and inconsistent.is_empty(),
		"reinitialization publishes small differences after replacement Vitals are ready")
	ids.clear()
	component.initialize()
	_expect(ids.is_empty(), "unchanged reinitialization does not publish attribute changes")
	component.free()

func _test_unchanged_effective_values() -> void:
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	var definition: GameplayAttribute = GameplayAttribute.new()
	definition.attribute_id = &"bounded"
	definition.min_value = 0.0
	definition.max_value = 1.0
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[definition] = 2.0
	component.initialize([attributes])
	var values: Array[float] = []
	component.attribute_value_changed.connect(func(_id: StringName, value: float) -> void: values.append(value))
	component.set_base_value(&"bounded", 2.000001)
	component.get_attribute(&"bounded").base_value = 2.000001
	_expect(values.is_empty() and component.get_value(&"bounded") == 1.0,
		"same effective values and clamped changes remain silent")
	component.free()

func _precision_component() -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.initialize([_precision_set(1.1)], [HealthVital.new()])
	return component

func _precision_set(root_value: float) -> PrecisionSet:
	var definition: PrecisionSet = PrecisionSet.new()
	_add_attributes(definition, [&"root", &"scaled", &"total", &"max_health"])
	for attribute: GameplayAttribute in definition.attributes:
		if attribute.attribute_id == &"root":
			definition.attributes[attribute] = root_value
	return definition

func _precision_snapshot_matches(component: GameplayVitalAttributeComponent) -> bool:
	var root_value: float = component.get_value(&"root")
	return component.get_value(&"scaled") == root_value * 100000.0 and \
		component.get_value(&"total") == root_value * 100000.0 + root_value and \
		component.get_value(&"max_health") == root_value and \
		component.get_vital(&"health").get_max_value() == root_value

func _add_attributes(attribute_set: GameplayAttributeSet, ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var definition: GameplayAttribute = GameplayAttribute.new()
		definition.attribute_id = id
		attribute_set.attributes[definition] = 0.0

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
