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
	_test_tick_payment_batch(5.0, [])
	_test_tick_payment_batch(10.0, [3.0])
	_test_tick_payment_batch(14.0, [7.0, 0.0])
	_test_channel_end(&"released", true, 0.0, false, false)
	_test_channel_end(&"released", true, 0.25, false, false)
	_test_channel_end(&"max_duration", false, 0.25, false, false)
	_test_channel_end(&"interrupted", true, 0.25, true, false)
	_test_channel_end(&"interrupted", false, 0.0, true, false)
	_test_channel_end(&"resource_exhausted", false, 0.0, false, false)
	_test_channel_end(&"released", true, 0.25, false, true)
	_test_channel_end(&"interrupted", true, 0.25, true, true)
	_test_channel_end(&"cancelled", true, 0.25, true, false)
	_test_same_channel_recast_from_end()
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
			and events == [&"ability_activated", &"ability_commit_failed", &"ability_channel_ended", &"ability_completed"],
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

func _make_payer(entity: Node, starting_balance: float) -> GameplayVitalAttributeComponent:
	var attributes: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	attributes.name = &"GameplayVitalAttributeComponent"
	entity.add_child(attributes)
	var max_mana: GameplayAttribute = GameplayAttribute.new()
	max_mana.attribute_id = &"max_mana"
	var definitions: GameplayAttributeSet = GameplayAttributeSet.new()
	definitions.attributes[max_mana] = starting_balance
	var mana: GameplayVital = GameplayVital.new()
	mana.vital_id = &"mana"
	mana.max_value_attribute = &"max_mana"
	attributes.initialize([definitions], [mana])
	return attributes

func _test_tick_payment_batch(starting_balance: float, expected_balances: Array[float]) -> void:
	var caster: Node = Node.new()
	var target: Node = Node.new()
	add_child(caster)
	add_child(target)
	var payer: GameplayVitalAttributeComponent = _make_payer(caster, starting_balance)
	var recipient: GameplayVitalAttributeComponent = _make_payer(target, 30.0)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	caster.add_child(component)
	var definition: ChannelingAbilityDefinition = ChannelingAbilityDefinition.new()
	definition.ability_id = &"channel_payment_batch"
	definition.tick_interval = 0.25
	definition.cooldown_duration = 2.0
	definition.interrupt_tags = []
	var first: VitalCost = VitalCost.new()
	first.amount = 3.0
	var second: VitalCost = VitalCost.new()
	second.amount = 4.0
	definition.tick_costs = [first, second]
	var effect: GameplayEffect = (load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect
	definition.tick_effects = [effect]
	component.learn_ability(definition)
	var balances: Array[float] = []
	payer.vital_value_changed.connect(
		func(_id: StringName, balance: float, _max: float, _fraction: float, _regen: bool) -> void:
			balances.append(balance)
	)
	_check(component.try_activate_ability(definition.ability_id), "batch channel accepts before tick payment")
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	ability.set_blackboard_var("targets", [target])
	ability.update(0.01)
	ability.update(0.26)
	var expected_final: float = starting_balance if expected_balances.is_empty() else expected_balances.back()
	_check(balances == expected_balances and payer.get_vital_value(&"mana") == expected_final,
		"same-Vital costs commit in full with one notice per paid tick, or leave the balance untouched")
	_check(recipient.get_vital_value(&"mana") == 30.0 and target.get_meta("effect_count", 0) == expected_balances.size(),
		"target receives only fully paid ticks and never pays their costs")
	_check(ability.is_active == (expected_balances.size() == 2), "an unaffordable tick ends the channel")
	caster.free()
	target.free()


func _test_channel_end(
	expected_reason: StringName, release: bool, duration: float, interrupt: bool, during_windup: bool
) -> void:
	var caster: Node = Node.new()
	var target: Node = Node.new()
	add_child(caster)
	add_child(target)
	# Only exhaustion starts the decisive frame with insufficient funds.
	var starting_balance: float = 5.0 if expected_reason == &"resource_exhausted" else 8.0
	var payer: GameplayVitalAttributeComponent = _make_payer(caster, starting_balance)
	var statuses: GameplayStatusComponent = GameplayStatusComponent.new()
	statuses.name = &"GameplayStatusComponent"
	caster.add_child(statuses)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	caster.add_child(component)

	var definition: ChannelingAbilityDefinition = ChannelingAbilityDefinition.new()
	definition.ability_id = &"channel_end"
	definition.pre_cast_delay = 0.5 if during_windup else 0.0
	definition.max_duration = duration
	definition.tick_interval = 0.25
	definition.cooldown_duration = 2.0
	var cost: VitalCost = VitalCost.new()
	cost.amount = 3.0
	definition.tick_costs = [cost]
	var effect: GameplayEffect = (load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect
	definition.tick_self_effects = [effect]
	definition.completion_effects = [effect]
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var balances: Array[float] = []
	payer.vital_value_changed.connect(
		func(_id: StringName, balance: float, _max: float, _fraction: float, _regen: bool) -> void:
			balances.append(balance)
	)
	var events: Array[StringName] = []
	var reasons: Array[StringName] = []
	var completion_at_end: Array[int] = []
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") != definition.ability_id:
			return
		events.append(event)
		if event == &"ability_channel_ended":
			reasons.append(context["reason"])
			completion_at_end.append(target.get_meta("effect_count", 0))
	AbilityEventBus.game_event_occurred.connect(observe)
	_check(component.try_activate_ability(definition.ability_id), "channel accepts ending fixture")
	ability.set_blackboard_var("targets", [target])
	ability.update(0.01)
	_check(ability.is_active, "channel is still active before the competing end conditions")

	if release:
		ability.set_blackboard_var("event_input_released", true)
	if interrupt:
		var status: GameplayStatusData = GameplayStatusData.new()
		status.status_id = &"state.stunned"
		statuses.apply_status(status, caster)
	if expected_reason == &"cancelled":
		component.cancel_ability(definition.ability_id)
	ability.update(0.25)
	ability.update(0.25)

	var label: String = "channel end %s (windup %s)" % [expected_reason, during_windup]
	var expected_ticks: int = 0 if during_windup else 1
	var expected_completion: int = int(not during_windup and expected_reason in [&"released", &"max_duration"])
	_check(not ability.is_active and reasons == [expected_reason] and events.count(&"ability_completed") == 1,
		label + " reports the selected ending exactly once")
	var expected_balance: float = starting_balance - 3.0 * expected_ticks
	_check(balances == ([] if during_windup else [expected_balance])
		and payer.get_vital_value(&"mana") == expected_balance
		and caster.get_meta("effect_count", 0) == expected_ticks,
		label + " stops before any additional payment, notification or tick effect")
	_check(completion_at_end == [expected_completion] and target.get_meta("effect_count", 0) == expected_completion,
		label + " applies completion effects only for a committed normal end")
	var expected_events: Array[StringName] = [&"ability_activated"]
	if not during_windup:
		expected_events.append(&"ability_committed")
	expected_events.append_array([&"ability_channel_ended", &"ability_completed"])
	if expected_reason == &"cancelled":
		expected_events.append(&"ability_cancelled")
	_check(events == expected_events and (cooldown.get_cooldown_remaining(ability) > 0.0) != during_windup,
		label + " preserves lifecycle order and the existing cooldown")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	caster.free()
	target.free()


func _test_same_channel_recast_from_end() -> void:
	var caster: Node = Node.new()
	add_child(caster)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	caster.add_child(component)
	var definition: ChannelingAbilityDefinition = ChannelingAbilityDefinition.new()
	definition.ability_id = &"recast_from_end"
	definition.pre_cast_delay = 0.5
	var effect: GameplayEffect = (load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect
	definition.tick_self_effects = [effect]
	component.learn_ability(definition)

	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var reasons: Array[StringName] = []
	var accepted: Array[bool] = []
	var completed: Array[GameplayAbilityInstance] = []
	var completed_events: Array[StringName] = []
	component.ability_completed.connect(func(finished: GameplayAbilityInstance) -> void: completed.append(finished))
	var on_event: Callable = func(event: StringName, data: Dictionary) -> void:
		if data.get("ability_id") != definition.ability_id:
			return
		if event == &"ability_completed":
			completed_events.append(event)
		if event == &"ability_channel_ended":
			reasons.append(data["reason"])
			if reasons.size() == 1:
				accepted.append(component.try_activate_ability(definition.ability_id))
				ability.update(0.25)
	AbilityEventBus.game_event_occurred.connect(on_event)

	_check(component.try_activate_ability(definition.ability_id), "accept original channel")
	ability.update(0.01)
	ability.set_blackboard_var("event_input_released", true)
	ability.update(0.01)
	_check(accepted == [true] and ability.is_active and component.get_current_casting_ability() == ability,
		"recasting the same channel in its end observer preserves the new current cast")
	_check(reasons == [&"released"] and completed == [ability] and completed_events.size() == 1,
		"the original cast emits one ending and one completion")
	ability.update(0.26)
	_check(caster.get_meta("effect_count", 0) == 1, "old cleanup preserves the new cast's windup progress")
	ability.set_blackboard_var("event_input_released", true)
	ability.update(0.01)
	_check(not ability.is_active and component.get_current_casting_ability() == null
		and reasons == [&"released", &"released"] and completed == [ability, ability] and completed_events.size() == 2,
		"the new cast emits its own ending and completion")
	AbilityEventBus.game_event_occurred.disconnect(on_event)
	caster.free()
