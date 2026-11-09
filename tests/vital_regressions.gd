extends Node
## Exercises attribute replacement, Vital snapshots, payments and attributed damage.

class RecordedHealth extends HealthVital:
	static var instances: Array[GameplayVital] = []

	func create_instance(component: GameplayAttributeComponent) -> GameplayVital:
		var instance: GameplayVital = super(component)
		instances.append(instance)
		return instance

class DerivedHealthSet extends GameplayAttributeSet:
	func resolve_dependencies(component: GameplayAttributeComponent) -> void:
		component.set_base_value(&"max_health", component.get_value(&"strength") * 2.0)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	_test_vital_ids(failures)
	_test_reinitialize(failures)
	_test_maximum_notifications(failures)
	_test_reinitialize_vital_notifications(failures)
	_test_batch_vital_notifications(failures)
	_test_vital_subscriber_updates_another_maximum(failures)
	_test_payment(failures)
	_test_damage(failures)
	_test_death_forwarding_after_reinitialize(failures)
	_test_damage_during_vital_replacement(failures)
	for failure: String in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: GAS Vital lifecycle, payment and attributed damage")
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)

func _test_vital_ids(failures: Array[String]) -> void:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	var empty: HealthVital = RecordedHealth.new()
	empty.vital_id = &""
	var blank: HealthVital = RecordedHealth.new()
	blank.vital_id = &"  "
	var first: HealthVital = RecordedHealth.new()
	first.display_name = "First health"
	component.initialize([_make_set({&"max_health": 4.0})], [first, RecordedHealth.new(), empty, blank])
	var original: HealthVital = RecordedHealth.instances[0] as HealthVital
	_expect(RecordedHealth.instances.size() == 1 and component.get_vital(&"health") == original,
		"only the first valid template with a Vital ID is instantiated", failures)
	_expect(not component.has_vital(&"") and not component.has_vital(&"  "),
		"empty and whitespace-only Vital IDs are rejected", failures)
	var deaths: Array[Node] = []
	component.health_depleted.connect(func(_id: StringName, instigator: Node) -> void: deaths.append(instigator))
	component.initialize([], [HealthVital.new()])
	var damage: DamageInfo = DamageInfo.new(self, self, 4.0)
	damage.final_damage = damage.base_damage
	var applied: float = original.apply_damage(damage, self)
	_expect(applied == 0.0 and not is_in_group(&"death"),
		"real damage against a retired Vital cannot mark the current owner dead", failures)
	original.health_depleted.emit(self)
	_expect(deaths.is_empty() and component.get_vital_value(&"health") == 4.0,
		"the previous registration cannot report death for the current Vital", failures)
	var replacement: HealthVital = component.get_vital(&"health") as HealthVital
	replacement.apply_damage(damage, self)
	_expect(deaths == [self], "the current registration still reports attributed death", failures)
	remove_from_group(&"death")
	RecordedHealth.instances.clear()
	component.free()

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
	_expect(values == [30.0, 31.0], "reset publishes the new value and discarded attributes no longer forward changes", failures)
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

func _test_reinitialize_vital_notifications(failures: Array[String]) -> void:
	var owner: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _add_vitals(owner)
	var attributes: GameplayAttributeSet = DerivedHealthSet.new()
	attributes.attributes = _make_set({&"max_health": 4.0, &"max_mana": 5.0, &"strength": 7.0}).attributes
	component.try_spend(&"mana", 3.0)
	var attribute_reads: Array[Vector2] = []
	var vital_reads: Array[Vector2] = []
	var payloads: Dictionary[StringName, Vector3] = {}
	var read_vitals: Callable = func() -> Vector2:
		return Vector2(component.get_vital_value(&"health"), component.get_vital_value(&"mana"))
	component.attribute_value_changed.connect(func(_id: StringName, _value: float) -> void:
		attribute_reads.append(read_vitals.call())
	)
	component.vital_value_changed.connect(func(id: StringName, current: float, maximum: float, fraction: float, _regen: bool) -> void:
		payloads[id] = Vector3(current, maximum, fraction)
		vital_reads.append(read_vitals.call())
	)
	component.initialize([attributes])
	component.initialize()
	_expect(attribute_reads == [Vector2(14.0, 5.0)],
		"reinitialization publishes changed attributes only after replacement Vitals are ready", failures)
	_expect(vital_reads == [Vector2(14.0, 5.0), Vector2(14.0, 5.0)] and
		payloads == {&"health": Vector3(14.0, 14.0, 1.0), &"mana": Vector3(5.0, 5.0, 1.0)},
		"each reset Vital publishes its final snapshot once and an unchanged reset stays silent", failures)
	owner.free()

func _test_batch_vital_notifications(failures: Array[String]) -> void:
	var owner: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _add_vitals(owner)
	component.add_modifier(GameplayAttributeModifier.new(&"max_health", 10.0, GameplayAttributeModifier.ModifierType.ADD, &"gear"))
	component.add_modifier(GameplayAttributeModifier.new(&"max_mana", 10.0, GameplayAttributeModifier.ModifierType.ADD, &"gear"))
	component.modify_vital(&"health", 10.0)
	component.modify_vital(&"mana", 10.0)
	var reads: Array[Vector4] = []
	var payloads: Dictionary[StringName, Vector3] = {}
	var observe: Callable = func() -> void:
		reads.append(Vector4(component.get_vital_value(&"health"), component.get_vital_value(&"mana"),
			component.get_value(&"max_health"), component.get_value(&"max_mana")))
	component.attribute_value_changed.connect(func(_id: StringName, _value: float) -> void: observe.call())
	component.vital_value_changed.connect(func(id: StringName, current: float, maximum: float, fraction: float, _regen: bool) -> void:
		payloads[id] = Vector3(current, maximum, fraction)
		observe.call()
	)
	component.remove_modifiers_by_source(&"gear")
	component.remove_modifiers_by_source(&"gear")
	var settled: Vector4 = Vector4(4.0, 5.0, 4.0, 5.0)
	_expect(reads == [settled, settled, settled, settled] and
		payloads == {&"health": Vector3(4.0, 4.0, 1.0), &"mana": Vector3(5.0, 5.0, 1.0)},
		"both attribute and Vital subscribers see all clamped values from a source removal", failures)
	owner.free()

func _test_vital_subscriber_updates_another_maximum(failures: Array[String]) -> void:
	var owner: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _add_vitals(owner)
	component.add_modifier(GameplayAttributeModifier.new(&"max_health", 10.0, GameplayAttributeModifier.ModifierType.ADD, &"gear"))
	component.add_modifier(GameplayAttributeModifier.new(&"max_mana", 10.0, GameplayAttributeModifier.ModifierType.ADD, &"gear"))
	var mana_maxima: Array[float] = []
	var mana_reads: Array[Vector3] = []
	component.vital_value_changed.connect(func(id: StringName, _current: float, maximum: float, _fraction: float, _regen: bool) -> void:
		if id == &"health":
			component.set_base_value(&"max_mana", 3.0)
		elif id == &"mana":
			mana_maxima.append(maximum)
	)
	component.vital_value_changed.connect(func(id: StringName, _current: float, _maximum: float, _fraction: float, _regen: bool) -> void:
		if id == &"health":
			mana_reads.append(Vector3(component.get_value(&"max_mana"),
				component.get_vital(&"mana").get_max_value(), component.get_vital_value(&"mana")))
	)
	component.remove_modifiers_by_source(&"gear")
	_expect(mana_maxima == [3.0] and component.get_vital_value(&"mana") == 3.0,
		"a subscriber write settles before the next queued Vital notification", failures)
	_expect(mana_reads == [Vector3(3.0, 3.0, 3.0)],
		"a later subscriber to the same signal sees settled attributes and Vitals", failures)
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

func _test_death_forwarding_after_reinitialize(failures: Array[String]) -> void:
	var target: Node = Node.new()
	var source: Node = Node.new()
	add_child(target)
	add_child(source)
	var component: GameplayVitalAttributeComponent = _add_vitals(target)
	var original: HealthVital = component.get_vital(&"health") as HealthVital
	var deaths: Array[Node] = []
	component.health_depleted.connect(func(id: StringName, instigator: Node) -> void:
		if id == &"health":
			deaths.append(instigator)
	)
	component.try_spend(&"health", 4.0)
	_expect(deaths.is_empty(), "health payments do not publish attributed deaths", failures)
	component.initialize()
	var replacement: HealthVital = component.get_vital(&"health") as HealthVital
	original.health_depleted.emit(source)
	_expect(deaths.is_empty(), "a discarded Vital cannot publish through the component", failures)
	var damage: DamageInfo = DamageInfo.new(source, source, 4.0)
	damage.final_damage = damage.base_damage
	replacement.apply_damage(damage, target)
	replacement.apply_damage(damage, target)
	_expect(original != replacement and deaths == [source], "replacement Vital forwards one attributed death", failures)
	target.free()
	source.free()

func _test_damage_during_vital_replacement(failures: Array[String]) -> void:
	var target: Node = Node.new()
	add_child(target)
	var component: GameplayVitalAttributeComponent = _add_vitals(target)
	var original: HealthVital = component.get_vital(&"health") as HealthVital
	original.damage_received.connect(func(_info: DamageInfo) -> void: component.initialize(), CONNECT_ONE_SHOT)
	var damage: DamageInfo = DamageInfo.new(self, self, 4.0)
	damage.final_damage = damage.base_damage
	var applied: float = original.apply_damage(damage, target)
	_expect(applied == 0.0 and not target.is_in_group(&"death") and component.get_vital_value(&"health") == 4.0,
		"replacing a Vital during damage reception cancels the hit on the retired instance", failures)
	var replacement: HealthVital = component.get_vital(&"health") as HealthVital
	replacement.damage_applied.connect(func(_info: DamageInfo, _amount: float) -> void: component.initialize(), CONNECT_ONE_SHOT)
	replacement.apply_damage(damage, target)
	_expect(not target.is_in_group(&"death") and component.get_vital_value(&"health") == 4.0,
		"replacing a Vital during the applied event prevents its death from affecting the new owner state", failures)
	target.free()

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
