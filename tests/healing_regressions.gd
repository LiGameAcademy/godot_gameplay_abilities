extends Node
## Verifies committed healing amounts independently of synchronous listener writes.

class ObservedHealing extends GE_ApplyHealing:
	var cue_amounts: Array[float] = []

	func _execute_cue(_target: Node, context: Dictionary) -> void:
		cue_amounts.append(context.get("final_healing", -1.0))

var _failures: Array[String] = []
var _events: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	AbilityEventBus.subscribe_to_event(&"healing_applied", _on_healing)
	_test_amounts_and_rejection()
	_test_reentrant_healing()
	_test_reentrant_damage()
	_test_bool_contract()
	AbilityEventBus.unsubscribe_from_event(&"healing_applied", _on_healing)
	_events.clear()
	for failure: String in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: GAS actual healing events and reentrant recovery")
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

func _test_amounts_and_rejection() -> void:
	var target: Node = _make_target()
	var component: GameplayVitalAttributeComponent = target.get_node("GameplayAttributeComponent")
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	var effect: ObservedHealing = _make_effect()
	var context: Dictionary = {"final_healing": 99.0}
	_events.clear()
	effect.apply(target, target, context)
	_expect(_events.is_empty() and effect.cue_amounts == [0.0], "full health has no healing event or stale Cue amount")
	health.modify_value(-1.0)
	effect.apply(target, target, context)
	_expect(_amounts() == [1.0] and health.current_value == 10.0 and effect.cue_amounts[-1] == 1.0,
		"overhealing reports only the one point restored")
	_expect(_events[0].get("target") == target and _events[0].get("instigator") == target,
		"successful healing preserves event attribution")
	health.modify_value(-7.0)
	effect.apply(target, target, context)
	_expect(_amounts() == [1.0, 5.0] and health.current_value == 8.0 and effect.cue_amounts[-1] == 5.0,
		"ordinary healing reports its full committed amount")
	for invalid: float in [0.0, -1.0, NAN, INF, -INF]:
		effect.healing_multiplier = invalid
		effect.apply(target, target, context)
		_expect(_events.size() == 2 and health.current_value == 8.0 and effect.cue_amounts[-1] == 0.0,
			"invalid or nonpositive healing neither changes health nor publishes success")
	effect.healing_multiplier = 1.0
	component.set_base_value(&"max_health", 0.0)
	effect.apply(target, target, context)
	_expect(_events.size() == 2 and effect.cue_amounts[-1] == 0.0, "zero capacity rejects healing")
	component.set_base_value(&"max_health", 10.0)
	effect.apply(target, target, context)
	_expect(_amounts() == [1.0, 5.0, 5.0] and health.current_value == 5.0,
		"restored capacity permits real healing")
	var lethal: DamageInfo = DamageInfo.new(self, self, 20.0)
	lethal.final_damage = 20.0
	health.apply_damage(lethal, target)
	component.set_base_value(&"max_health", 0.0)
	component.set_base_value(&"max_health", 10.0)
	effect.apply(target, target, context)
	_expect(_events.size() == 3 and health.current_value == 0.0 and effect.cue_amounts[-1] == 0.0,
		"an attributed death cannot be revived or reported as successful healing")
	_expect(context["final_healing"] == 99.0, "effect-local results do not mutate the caller context")
	target.free()

func _test_reentrant_healing() -> void:
	var target: Node = _make_target()
	var component: GameplayVitalAttributeComponent = target.get_node("GameplayAttributeComponent")
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	health.modify_value(-8.0)
	var outer: ObservedHealing = _make_effect()
	var inner: ObservedHealing = _make_effect()
	_events.clear()
	health.value_changed.connect(func(_current: float, _maximum: float, _percent: float, _regen: bool) -> void:
		inner.apply(target, target)
	, CONNECT_ONE_SHOT)
	outer.apply(target, target)
	_expect(_amounts() == [3.0, 5.0] and inner.cue_amounts == [3.0] and outer.cue_amounts == [5.0],
		"nested healing reports each committed amount exactly once")
	_expect(health.current_value == 10.0, "nested healing respects maximum capacity")
	target.free()

func _test_reentrant_damage() -> void:
	var target: Node = _make_target()
	var component: GameplayVitalAttributeComponent = target.get_node("GameplayAttributeComponent")
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	health.modify_value(-8.0)
	var effect: ObservedHealing = _make_effect()
	_events.clear()
	health.health_restored.connect(func() -> void:
		var hit: DamageInfo = DamageInfo.new(self, self, 20.0)
		hit.final_damage = 20.0
		health.apply_damage(hit, target)
	, CONNECT_ONE_SHOT)
	effect.apply(target, target)
	_expect(_amounts() == [5.0] and effect.cue_amounts == [5.0] and health.current_value == 0.0,
		"a later lethal callback cannot rewrite the healing already committed")
	effect.apply(target, target)
	_expect(_amounts() == [5.0] and effect.cue_amounts == [5.0, 0.0], "subsequent ordinary healing still rejects death")
	target.free()

func _test_bool_contract() -> void:
	var target: Node = _make_target()
	var component: GameplayVitalAttributeComponent = target.get_node("GameplayAttributeComponent")
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	_expect(not health.heal(1.0), "legacy heal returns false at full health")
	health.modify_value(-1.0)
	_expect(health.heal(5.0) and health.current_value == 10.0, "legacy heal returns true for positive recovery")
	health.unbind_attributes()
	_expect(not health.heal(1.0), "a discarded Vital rejects healing")
	target.free()

func _make_target() -> Node:
	var target: Node = Node.new()
	add_child(target)
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = &"GameplayAttributeComponent"
	target.add_child(component)
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	for id: StringName in [&"max_health", &"attack"]:
		var definition: GameplayAttribute = GameplayAttribute.new()
		definition.attribute_id = id
		attributes.attributes[definition] = 10.0 if id == &"max_health" else 5.0
	component.initialize([attributes], [HealthVital.new()])
	return target

func _make_effect() -> ObservedHealing:
	var effect: ObservedHealing = ObservedHealing.new()
	effect.cue = GameplayCue.new()
	return effect

func _amounts() -> Array[float]:
	var amounts: Array[float] = []
	for event: Dictionary in _events:
		amounts.append(event["amount"])
	return amounts

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _on_healing(_event_type: StringName, context: Dictionary) -> void:
	_events.append(context.duplicate())
