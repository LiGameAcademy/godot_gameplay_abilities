extends Node
## Exercises default channeling tree construction and rejects missing execution trees.

var _failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_channeling_tree(false)
	_test_channeling_tree(true)
	_test_missing_execution_tree()
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
