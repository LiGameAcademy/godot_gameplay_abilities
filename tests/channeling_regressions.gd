extends Node
## Exercises default channeling tree construction and rejects missing execution trees.

var _failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_channeling_tree(false)
	_test_channeling_tree(true)
	_test_missing_execution_tree()
	_test_first_tick_commit(false)
	_test_first_tick_commit(true)
	if _failed == 0:
		print("PASS: GAS channeling tree and missing-tree guard")
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)

func _test_channeling_tree(self_only: bool) -> void:
	var owner: Node = Node.new()
	var target: Node = Node.new()
	add_child(owner)
	add_child(target)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var definition: ChannelingAbilityDefinition = ChannelingAbilityDefinition.new()
	definition.ability_id = &"channeling_tree"
	definition.max_duration = 2.0
	definition.tick_interval = 0.25
	_check(is_instance_valid(definition._build_default_behavior_tree()), "interrupt and duration branches build with typed children")
	definition.interrupt_tags = []
	var effect: GameplayEffect = (load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect
	if self_only:
		definition.tick_self_effects.append(effect)
	else:
		definition.tick_effects.append(effect)
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var ended: Array[GameplayAbilityInstance] = []
	component.ability_completed.connect(func(finished: GameplayAbilityInstance) -> void: ended.append(finished))
	_check(component.can_activate_ability(definition.ability_id) and component.try_activate_ability(definition.ability_id),
		"generated channel accepts activation")
	ability.set_blackboard_var("targets", [target])
	ability.update(0.01)
	_check(ability.is_active and owner.get_meta("effect_count", 0) == int(self_only)
		and target.get_meta("effect_count", 0) == int(not self_only), "first periodic effect reaches the configured recipient")
	ability.update(0.26)
	_check(owner.get_meta("effect_count", 0) == 2 * int(self_only)
		and target.get_meta("effect_count", 0) == 2 * int(not self_only), "periodic branch runs a second tick")
	ability.set_blackboard_var("event_input_released", true)
	ability.update(0.01)
	_check(not ability.is_active and ended == [ability], "input release ends channeling exactly once")
	owner.free()
	target.free()

func _test_missing_execution_tree() -> void:
	var owner: Node = Node.new()
	add_child(owner)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"no_execution_tree"
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var activations: Array[GameplayAbilityInstance] = []
	component.ability_activated.connect(func(started: GameplayAbilityInstance) -> void: activations.append(started))
	_check(not component.can_activate_ability(definition.ability_id)
		and not component.try_activate_ability(definition.ability_id)
		and not ability.try_activate() and not ability.is_active and activations.is_empty(),
		"a learned skill without an execution tree cannot enter active state")
	owner.free()

class CommitObserver extends GameplayAbilityModifier:
	var snapshots: Array[Vector3] = []

	func on_after_ability_commit(
		_component: GameplayAbilityComponent, ability: GameplayAbilityInstance, context: Dictionary
	) -> void:
		var owner: Node = context["instigator"] as Node
		var vital: GameplayVitalAttributeComponent = owner.get_node("GameplayVitalAttributeComponent")
		var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
		snapshots.append(Vector3(vital.get_vital_value(&"mana"), cooldown.get_cooldown_remaining(ability),
			owner.get_meta("effect_count", 0)))

func _test_first_tick_commit(insufficient: bool) -> void:
	var owner: Node = Node.new()
	add_child(owner)
	var attributes: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	attributes.name = &"GameplayVitalAttributeComponent"
	owner.add_child(attributes)
	var max_mana: GameplayAttribute = GameplayAttribute.new()
	max_mana.attribute_id = &"max_mana"
	var definitions: GameplayAttributeSet = GameplayAttributeSet.new()
	definitions.attributes[max_mana] = 1.0 if insufficient else 7.0
	var mana: GameplayVital = GameplayVital.new()
	mana.vital_id = &"mana"
	mana.max_value_attribute = &"max_mana"
	attributes.initialize([definitions], [mana])

	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var modifiers: GameplayModifierComponent = GameplayModifierComponent.new()
	owner.add_child(modifiers)
	component.modifier_component = modifiers
	var observer: CommitObserver = CommitObserver.new()
	modifiers.add_modifier(observer)
	modifiers.add_modifier(CooldownReductionModifier.new())

	var definition: ChannelingAbilityDefinition = ChannelingAbilityDefinition.new()
	definition.ability_id = &"first_tick_commit"
	definition.pre_cast_delay = 0.1
	definition.tick_interval = 0.25
	definition.cooldown_duration = 2.0
	definition.interrupt_tags = []
	var effect: GameplayEffect = (load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect
	definition.tick_effects = [effect]
	definition.completion_effects = [effect]
	var cost: VitalCost = VitalCost.new()
	cost.amount = 2.0
	definition.tick_costs = [cost]

	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var events: Array[StringName] = []
	var paid_balances: Array[float] = []
	attributes.vital_value_changed.connect(
		func(_id: StringName, balance: float, _max: float, _fraction: float, _regen: bool) -> void:
			paid_balances.append(balance)
	)
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") == definition.ability_id:
			events.append(event)
	AbilityEventBus.game_event_occurred.connect(observe)
	_check(component.try_activate_ability(definition.ability_id), "channel accepts before the first payment")
	ability.set_blackboard_var("targets", [owner])
	ability.update(0.05)
	_check(events == [&"ability_activated"] and observer.snapshots.is_empty() and paid_balances.is_empty()
		and cooldown.get_cooldown_remaining(ability) == 0.0, "windup emits acceptance only")
	ability.update(0.06)
	if insufficient:
		_check(not ability.is_active and attributes.get_vital_value(&"mana") == 1.0
			and cooldown.get_cooldown_remaining(ability) == 0.0 and paid_balances.is_empty()
			and observer.snapshots.is_empty() and owner.get_meta("effect_count", 0) == 0
			and events == [&"ability_activated", &"ability_commit_failed", &"ability_completed"],
			"first payment failure ends without cooldown, tick effects, completion effects or a success hook")
	else:
		_check(events == [&"ability_activated", &"ability_committed"] and observer.snapshots.size() == 1
			and observer.snapshots[0].is_equal_approx(Vector3(5.0, 1.6, 0.0))
			and paid_balances == [5.0] and owner.get_meta("effect_count", 0) == 1,
			"first tick pays, starts reduced cooldown, then commits before the effect")
		ability.update(0.26)
		_check(observer.snapshots.size() == 1 and events == [&"ability_activated", &"ability_committed"]
			and paid_balances == [5.0, 3.0] and owner.get_meta("effect_count", 0) == 2
			and cooldown.get_cooldown_remaining(ability) < 1.6,
			"a later paid tick does not commit again or reset cooldown")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	owner.free()
