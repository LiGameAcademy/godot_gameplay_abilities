extends Node
## Runs in Simple ARPG Demo, using its real player, derived attributes and healing asset.
## Dynamic host entry points keep this optional integration fixture importable without ARPG.

var _failures: Array[String] = []
var _healing_amounts: Array[float] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: Node = main.get_node("RoomLobby/Player")
	var attributes: GameplayVitalAttributeComponent = player.call("get_attribute_component")
	attributes.set_process(false)
	_test_precision(attributes)
	_test_potion(player, attributes)
	AbilityEventBus.subscribe_to_event(&"healing_applied", _on_healing)
	_test_life_drain(player, attributes)
	AbilityEventBus.unsubscribe_from_event(&"healing_applied", _on_healing)
	main.queue_free()
	await get_tree().process_frame
	for failure: String in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: ARPG actual healing, potion recovery and precise derived attributes")
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

func _test_precision(attributes: GameplayVitalAttributeComponent) -> void:
	var original_strength: float = attributes.get_attribute(&"strength").base_value
	var original_attack: float = attributes.get_value(&"attack")
	var original_maximum: float = attributes.get_value(&"max_health")
	var mismatches: Array[StringName] = []
	var strength_notices: Array[float] = []
	var observe: Callable = func(id: StringName, value: float) -> void:
		if id == &"strength":
			strength_notices.append(value)
		var delta: float = attributes.get_value(&"strength") - original_strength
		if absf(attributes.get_value(&"attack") - original_attack - delta * 2.0) > 0.000000001 or \
			absf(attributes.get_value(&"max_health") - original_maximum - delta * 2.0) > 0.000000001 or \
			attributes.get_vital(&"health").get_max_value() != attributes.get_value(&"max_health"):
			mismatches.append(id)
	attributes.attribute_value_changed.connect(observe)
	for step: int in range(1, 1001):
		attributes.set_base_value(&"strength", original_strength + float(step) * 0.000001)
	_expect(absf(attributes.get_value(&"attack") - original_attack - 0.002) < 0.000000001,
		"real SecondaryAttributeSet accumulates all small strength writes")
	_expect(strength_notices.size() == 1000 and mismatches.is_empty(),
		"player subscribers read settled attack, maximum health and Vital state")
	attributes.attribute_value_changed.disconnect(observe)
	attributes.set_base_value(&"strength", original_strength)

func _test_potion(player: Node, attributes: GameplayVitalAttributeComponent) -> void:
	var inventory: Node = player.call("get_inventory")
	var initial_stack: Object = inventory.call("get_item", 0)
	var initial_quantity: int = initial_stack.get("quantity")
	var maximum: float = attributes.get_attribute(&"max_health").base_value
	attributes.set_base_value(&"max_health", 0.0)
	var used_at_zero: bool = inventory.call("use_item", 0, player)
	_expect(not used_at_zero and initial_stack.get("quantity") == initial_quantity,
		"real potion at zero capacity is rejected without consuming inventory")
	attributes.set_base_value(&"max_health", maximum)
	var used_after_restore: bool = inventory.call("use_item", 0, player)
	_expect(used_after_restore and attributes.get_vital_value(&"health") == 20.0 and
		initial_stack.get("quantity") == initial_quantity - 1,
		"real potion restores 20 health after capacity returns and consumes one item")

func _test_life_drain(player: Node, attributes: GameplayVitalAttributeComponent) -> void:
	var effect: GE_ApplyHealing = load("res://data/ability_effects/ge_life_drain_healing.tres") as GE_ApplyHealing
	var health: HealthVital = attributes.get_vital(&"health") as HealthVital
	health.heal(health.get_max_value())
	effect.apply(player, player)
	_expect(_healing_amounts.is_empty(), "real life drain does not report healing at full health")
	health.modify_value(-1.0)
	effect.apply(player, player)
	_expect(_healing_amounts == [1.0] and health.current_value == health.get_max_value(),
		"real life drain reports one restored point when only one is missing")
	var maximum: float = attributes.get_attribute(&"max_health").base_value
	attributes.set_base_value(&"max_health", 0.0)
	effect.apply(player, player)
	_expect(_healing_amounts == [1.0], "real life drain rejects zero capacity")
	attributes.set_base_value(&"max_health", maximum)
	var expected: float = minf(attributes.get_value(&"attack") * effect.healing_multiplier, maximum)
	effect.apply(player, player)
	_expect(_healing_amounts == [1.0, expected] and health.current_value == expected,
		"real life drain restores health and reports its amount after capacity returns")
	var deaths: Array[Node] = []
	health.health_depleted.connect(func(instigator: Node) -> void: deaths.append(instigator))
	var hit: DamageInfo = DamageInfo.new(self, self, maximum)
	hit.final_damage = maximum
	health.apply_damage(hit, player)
	attributes.set_base_value(&"max_health", 0.0)
	attributes.set_base_value(&"max_health", maximum)
	effect.apply(player, player)
	_expect(health.current_value == 0.0 and deaths == [self] and _healing_amounts == [1.0, expected],
		"a killed player cannot be revived or emit a successful healing event")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _on_healing(_event_type: StringName, context: Dictionary) -> void:
	_healing_amounts.append(context["amount"])
