extends Node
## Tests combo construction, independent runtime memory and deterministic disposal.
var _failed: int = 0
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
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
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
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
