extends Node
## Verifies source-specific expiration using a serialized built-in effect.

class InterfaceActor extends Node:
	var attributes: GameplayAttributeComponent

	func get_gameplay_attribute_component() -> GameplayAttributeComponent:
		return attributes

func _ready() -> void:
	var short_bonus: GameplayStatusData = load("res://timed_attribute_bonus.tres") as GameplayStatusData
	if short_bonus == null:
		push_error("Timed attribute effect resource did not load")
		get_tree().quit.call_deferred(1)
		return
	var long_bonus: GameplayStatusData = short_bonus.duplicate() as GameplayStatusData
	long_bonus.status_id = &"long_bonus"
	long_bonus.duration = 1.0
	var named_actor: Node = Node.new()
	var interface_actor: InterfaceActor = InterfaceActor.new()
	var passed: bool = _check_bonuses(named_actor, short_bonus, long_bonus)
	passed = _check_bonuses(interface_actor, short_bonus, long_bonus) and passed
	if not passed:
		push_error("Timed attribute modifiers were not applied or removed by their own sources")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Status + Attribute timed effect")
	get_tree().quit.call_deferred(0)

func _check_bonuses(actor: Node, short_bonus: GameplayStatusData, long_bonus: GameplayStatusData) -> bool:
	add_child(actor)
	var attributes: GameplayAttributeComponent = GameplayAttributeComponent.new()
	if actor is InterfaceActor:
		(actor as InterfaceActor).attributes = attributes
	else:
		attributes.name = &"GameplayAttributeComponent"
	actor.add_child(attributes)
	var power: GameplayAttribute = GameplayAttribute.new()
	power.attribute_id = &"power"
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[power] = 10.0
	attributes.initialize([attribute_set])
	var statuses: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(statuses)
	statuses.set_process(false)

	var values: Array[float] = [attributes.get_value(&"power")]
	statuses.apply_status(short_bonus, actor)
	values.append(attributes.get_value(&"power"))
	statuses.apply_status(long_bonus, actor)
	values.append(attributes.get_value(&"power"))
	statuses.apply_status(long_bonus, actor)
	values.append(attributes.get_value(&"power"))
	statuses._process(0.5)
	values.append(attributes.get_value(&"power"))
	var only_long_active: bool = not statuses.has_status(short_bonus.status_id) \
			and statuses.has_status(long_bonus.status_id)
	statuses._process(0.5)
	values.append(attributes.get_value(&"power"))
	var neither_active: bool = statuses.get_active_statuses().is_empty()
	actor.free()
	return only_long_active and neither_active and values == [10.0, 13.0, 16.0, 19.0, 16.0, 10.0]
