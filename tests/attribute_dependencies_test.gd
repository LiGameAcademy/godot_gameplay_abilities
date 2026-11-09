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

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_snapshots()
	_test_cycle(false)
	_test_cycle(true)
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

func _add_attributes(attribute_set: GameplayAttributeSet, ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var definition: GameplayAttribute = GameplayAttribute.new()
		definition.attribute_id = id
		attribute_set.attributes[definition] = 0.0

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
