extends Node
## Exercises attribute replacement, Vital snapshots, payments and attributed damage.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	_test_reinitialize(failures)
	_test_maximum_notifications(failures)
	_test_payment(failures)
	_test_damage(failures)
	for failure: String in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: GAS Vital lifecycle, payment and attributed damage")
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)

func _test_reinitialize(failures: Array[String]) -> void:
	var component: GameplayAttributeComponent = GameplayAttributeComponent.new()
	component.initialize([_make_set({&"strength": 10.0, &"defense": 5.0})])
	var old: GameplayAttributeInstance = component.get_attribute(&"strength")
	var values: Array[float] = []
	component.attribute_value_changed.connect(func(_id: StringName, value: float) -> void: values.append(value))
	component.initialize([_make_set({&"strength": 30.0})])
	_expect(component.get_value(&"strength") == 30.0 and not component.has_attribute(&"defense"),
		"initializing again replaces old attributes", failures)
	old.base_value = 11.0
	component.set_base_value(&"strength", 31.0)
	_expect(values == [31.0], "discarded attributes no longer forward changes", failures)
	component.free()

func _test_maximum_notifications(failures: Array[String]) -> void:
	var owner: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _add_vitals(owner)
	var snapshots: Array[Vector3] = []
	component.vital_value_changed.connect(func(id: StringName, current: float, maximum: float, fraction: float, _regen: bool) -> void:
		if id == &"health":
			snapshots.append(Vector3(current, maximum, fraction))
	)
	component.set_base_value(&"max_health", 8.0)
	component.set_base_value(&"max_health", 6.0)
	component.set_base_value(&"max_health", 2.0)
	_expect(snapshots == [Vector3(4.0, 8.0, 0.5), Vector3(4.0, 6.0, 4.0 / 6.0), Vector3(2.0, 2.0, 1.0)],
		"every maximum change emits one consistent snapshot", failures)
	owner.free()

func _test_payment(failures: Array[String]) -> void:
	var first: Node = Node.new()
	var second: Node = Node.new()
	add_child(first)
	add_child(second)
	var a: GameplayVitalAttributeComponent = _add_vitals(first)
	var b: GameplayVitalAttributeComponent = _add_vitals(second)
	var cost: VitalCost = VitalCost.new()
	cost.amount = 3.0
	_expect(cost.try_pay(null, first) and a.get_vital_value(&"mana") == 2.0, "normal payment deducts the exact cost", failures)
	_expect(not cost.try_pay(null, first) and a.get_vital_value(&"mana") == 2.0, "insufficient payment leaves the balance intact", failures)
	_expect(cost.try_pay(null, second) and b.get_vital_value(&"mana") == 2.0, "shared cost resolves each caster independently", failures)
	cost.allow_overdraft = true
	_expect(cost.try_pay(null, first) and a.get_vital_value(&"mana") == 0.0, "explicit overdraft spends the remaining balance", failures)
	_expect(not cost.try_pay(null, first) and not a.try_spend(&"mana", -1.0) and not a.try_spend(&"missing", 0.0),
		"empty overdraft, negative amount and missing Vital fail", failures)
	first.free()
	second.free()

func _test_damage(failures: Array[String]) -> void:
	var target: Node = Node.new()
	var source: Node = Node.new()
	add_child(target)
	add_child(source)
	var component: GameplayVitalAttributeComponent = _add_vitals(target)
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	var deaths: Array[Node] = []
	var hits: Array[Vector2] = []
	health.health_depleted.connect(func(instigator: Node) -> void: deaths.append(instigator))
	health.damage_applied.connect(func(info: DamageInfo, damage: float) -> void:
		hits.append(Vector2(damage, float(info.source_component == source and info.instigator == source)))
	)
	var effect: GE_ApplyDamage = GE_ApplyDamage.new()
	effect.fixed_base_damage = 3.0
	effect.vital_comp_name = &"GameplayAttributeComponent"
	for tick: int in range(3):
		effect.apply(target, source, {"source_node": source})
	_expect(health.current_value == 0.0 and deaths == [source] and target.is_in_group(&"death"),
		"fixed damage can kill and attributes death exactly once", failures)
	_expect(hits == [Vector2(3.0, 1.0), Vector2(3.0, 1.0)], "damage emits source metadata and stops after death", failures)
	target.free()
	source.free()

func _add_vitals(owner: Node) -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = &"GameplayAttributeComponent"
	owner.add_child(component)
	var mana: GameplayVital = GameplayVital.new()
	mana.vital_id = &"mana"
	mana.max_value_attribute = &"max_mana"
	component.initialize([_make_set({&"max_health": 4.0, &"max_mana": 5.0})], [HealthVital.new(), mana])
	return component

func _make_set(values: Dictionary[StringName, float]) -> GameplayAttributeSet:
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	for id: StringName in values:
		var definition: GameplayAttribute = GameplayAttribute.new()
		definition.attribute_id = id
		attribute_set.attributes[definition] = values[id]
	return attribute_set

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
