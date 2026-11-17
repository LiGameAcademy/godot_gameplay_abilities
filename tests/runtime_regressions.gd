extends Node
## Tests combo construction, independent runtime memory and deterministic disposal.
var _failed: int = 0
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	_test_default_commit()
	var debug_scene: PackedScene = load("res://addons/godot_gameplay_abilities/ui/bt_debug_panel.tscn") as PackedScene
	var debug_window: Window = debug_scene.instantiate() as Window
	_check(not debug_window.visible, "debug window is hidden before runtime ready and editor preview")
	debug_window.free()
	var step: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	step.ability_id = &"regression_step"
	step.cooldown_duration = 1.0
	step.costs.append(VitalCost.new())
	var standalone: BTNode = step._build_default_behavior_tree()
	_check(_count(standalone, "AbilityNodeCommitCost") == 1, "standalone cost retained")
	_check(_count(standalone, "AbilityNodeCommitCooldown") == 1, "standalone cooldown retained")
	var combo: ComboAbilityDefinition = ComboAbilityDefinition.new()
	combo.ability_id = &"regression_combo"
	combo.combo_steps = [step, step]
	combo.costs.append(VitalCost.new())
	combo.cooldown_duration = 1.0
	var owner: Node = Node.new()
	add_child(owner)
	var instance: GameplayAbilityInstance = combo.create_instance(owner)
	_check(instance.get_bt_instance() != null, "combo has executable tree")
	var tree: BTNode = instance.get_bt_instance().tree_root
	_check(_count(tree, "AbilityNodeCommitCost") == 1, "combo pays once, not per step")
	_check(_count(tree, "AbilityNodeCommitCooldown") == 1, "combo commits one cooldown")
	_check(combo.execution_tree == null and step.execution_tree == null, "definitions remain unchanged")
	var reference: WeakRef = weakref(instance)
	instance.dispose()
	instance = null
	_check(reference.get_ref() == null, "disposed instance can be released")
	var board: BTBlackboard = BTBlackboard.new()
	var wait: BTWait = BTWait.new()
	board.set_node_data(wait, {"elapsed": 1.0})
	board.clear()
	_check(not board.has_node_data(wait), "clear removes node-owned runtime memory")
	var timer: BTWait = BTWait.new()
	timer.duration = 0.1
	var timer_a: BTInstance = BTInstance.new(owner, timer)
	var timer_b: BTInstance = BTInstance.new(owner, timer)
	_check(timer_a.tick(0.05) == BTNode.Status.RUNNING, "wait starts in game time")
	_check(timer_a.tick(0.06) == BTNode.Status.SUCCESS, "wait completes from delta")
	_check(timer_b.tick(0.01) == BTNode.Status.RUNNING, "shared wait has independent instance state")
	var apply: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
	apply.effects.append((load("res://addons/godot_gameplay_abilities/tests/counting_effect.gd") as GDScript).new() as GameplayEffect)
	var execution: BTInstance = BTInstance.new(owner, apply)
	execution.blackboard.set_var("context", {"instigator": owner})
	execution.blackboard.set_var("targets", [owner])
	_check(execution.tick(0.01) == BTNode.Status.SUCCESS and owner.get_meta("effect_count", 0) == 1, "dictionary context executes effects")
	var search: AbilityNodeTargetSearch = AbilityNodeTargetSearch.new()
	search.strategy = SelfTargetingStrategy.new()
	execution = BTInstance.new(owner, search)
	execution.blackboard.set_var("context", {"instigator": owner})
	_check(execution.tick(0.01) == BTNode.Status.SUCCESS, "debug target search uses current strategy API")
	var sacrifice: SacrificeAbilityDefinition = SacrificeAbilityDefinition.new()
	sacrifice.ability_id = &"sacrifice_regression"
	sacrifice.icon_when_active = GradientTexture1D.new()
	sacrifice.cooldown_duration = 1.0
	var toggle_instance: GameplayAbilityInstance = sacrifice.create_instance(owner)
	_check(toggle_instance.has_feature("ToggleFeature") and toggle_instance.has_feature("CooldownFeature"), "sacrifice inherits toggle and cooldown features")
	_check(sacrifice.area_targeting_strategy == null, "sacrifice default targeting does not mutate config")
	toggle_instance.dispose()
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var modifiers: GameplayModifierComponent = GameplayModifierComponent.new()
	modifiers.name = "GameplayModifierComponent"
	owner.add_child(modifiers)
	component.modifier_component = modifiers
	modifiers.add_modifier(CooldownReductionModifier.new())
	var extra: MultiCastModifier = MultiCastModifier.new()
	extra.extra_projectiles = 2
	modifiers.add_modifier(extra)
	var active: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	active.ability_id = &"modifier_regression"
	active.cooldown_duration = 1.0
	active.targeting_strategy = SelfTargetingStrategy.new()
	active.effects = apply.effects
	component.learn_ability(active)
	_check(component.try_activate_ability(active.ability_id), "modified ability activates")
	var modified: GameplayAbilityInstance = component.get_ability_instance(active.ability_id)
	modified.update(0.01)
	var cd: CooldownFeature = modified.get_feature("CooldownFeature") as CooldownFeature
	_check(is_equal_approx(cd.get_cooldown_remaining(modified), 0.8), "modifier reduces actual cooldown")
	var modified_context: Dictionary = modified.get_blackboard_var("context")
	_check(modified_context.get("extra_projectiles", 0) == 2, "pre-apply modifier hook runs")
	component.forget_ability(active.ability_id)
	component.cancel_ability()
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"regression_lifecycle"
	definition.execution_tree = BTWait.new()
	component.learn_ability(definition)
	reference = weakref(component.get_ability_instance(definition.ability_id))
	component.forget_ability(definition.ability_id)
	_check(reference.get_ref() == null, "forget releases runtime instance")
	component.learn_ability(definition)
	reference = weakref(component.get_ability_instance(definition.ability_id))
	var other: Node = Node.new()
	add_child(other)
	component.reparent(other)
	_check(reference.get_ref() != null and component.get_ability_instance(definition.ability_id) != null, "reparent preserves learned abilities")
	component.reparent(owner)
	other.queue_free()
	owner.queue_free()
	await get_tree().process_frame
	_check(reference.get_ref() == null, "component exit releases runtime instance")
	if _failed == 0:
		print("PASS: GAS combo cost/cooldown, immutable definitions, blackboard and lifecycle disposal")
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)
func _count(node: BTNode, expected: String) -> int:
	var count: int = int((node.get_script() as Script).get_global_name() == expected)
	if node is BTComposite:
		for child: BTNode in (node as BTComposite).children:
			count += _count(child, expected)
	return count
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)

class WindupCost extends AbilityCostBase:
	func _can_pay(_ability_comp: Node, instigator: Node) -> bool:
		return int(instigator.get_meta("balance")) >= 1

	func _try_pay(_ability_comp: Node, instigator: Node) -> bool:
		instigator.set_meta("balance", int(instigator.get_meta("balance")) - 1)
		return true

class CommitObserver extends GameplayAbilityModifier:
	func on_after_ability_commit(
		_ability_comp: GameplayAbilityComponent, ability: GameplayAbilityInstance, context: Dictionary
	) -> void:
		var owner: Node = context["instigator"]
		var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
		owner.set_meta("commit_hook", Vector2(float(owner.get_meta("balance")), cooldown.get_cooldown_remaining(ability)))

func _test_default_commit() -> void:
	var owner: Node = Node.new()
	add_child(owner)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var modifiers: GameplayModifierComponent = GameplayModifierComponent.new()
	owner.add_child(modifiers)
	component.modifier_component = modifiers
	modifiers.add_modifier(CommitObserver.new())
	modifiers.add_modifier(CooldownReductionModifier.new())
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.ability_id = &"windup_commit"
	definition.pre_cast_delay = 0.1
	definition.cooldown_duration = 1.0
	definition.costs = [WindupCost.new()]
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var events: Array[StringName] = []
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") == definition.ability_id:
			events.append(event)
	AbilityEventBus.game_event_occurred.connect(observe)
	owner.set_meta("balance", 1)
	_check(component.try_activate_ability(definition.ability_id), "accept windup before payment")
	ability.update(0.05)
	_check(ability.is_active and events == [&"ability_activated"] and not owner.has_meta("commit_hook"),
		"acceptance and windup do not report a commit")
	owner.set_meta("balance", 0)
	ability.update(0.06)
	_check(not ability.is_active and cooldown.get_cooldown_remaining(ability) == 0.0
		and not owner.has_meta("commit_hook") and events == [&"ability_activated", &"ability_commit_failed", &"ability_completed"],
		"failed payment ends the cast without cooldown or a success hook/event")
	owner.set_meta("balance", 1)
	events.clear()
	_check(component.try_activate_ability(definition.ability_id), "retry after failed commit")
	ability.update(0.05)
	ability.update(0.06)
	_check(events == [&"ability_activated", &"ability_committed", &"ability_completed"]
		and owner.get_meta("commit_hook", Vector2(-1, -1)).is_equal_approx(Vector2(0, 0.8)),
		"successful payment and reduced cooldown are visible to the commit hook")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	owner.free()
