extends Node
## Tests combo construction, independent runtime memory and deterministic disposal.
var _failed: int = 0
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	_test_combo_commit()
	_test_disabled_cast()
	_test_atomic_vital_costs()
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

func _test_atomic_vital_costs() -> void:
	var owner: Node = Node.new()
	add_child(owner)
	var attributes: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	attributes.name = &"GameplayAttributeComponent"
	owner.add_child(attributes)
	var definitions: GameplayAttributeSet = GameplayAttributeSet.new()
	var vitals: Array[GameplayVital] = []
	for id: StringName in [&"mana", &"stamina"]:
		var maximum: GameplayAttribute = GameplayAttribute.new()
		maximum.attribute_id = StringName("max_" + String(id))
		definitions.attributes[maximum] = 7.0 if id == &"mana" else 2.0
		var vital: GameplayVital = GameplayVital.new()
		vital.vital_id = id
		vital.max_value_attribute = maximum.attribute_id
		vitals.append(vital)
	attributes.initialize([definitions], vitals)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.ability_id = &"atomic_cost"
	definition.pre_cast_delay = 0.1
	definition.cooldown_duration = 1.0
	var stamina: VitalCost = VitalCost.new()
	stamina.vital_id = &"stamina"
	stamina.amount = 1.0
	var first: VitalCost = VitalCost.new()
	first.amount = 3.0
	var second: VitalCost = VitalCost.new()
	second.amount = 4.0
	definition.costs = [stamina, first, second]
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var snapshots: Array[Vector2] = []
	var notifications: Array[StringName] = []
	var events: Array[StringName] = []
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") == definition.ability_id:
			events.append(event)
	AbilityEventBus.game_event_occurred.connect(observe)
	attributes.vital_value_changed.connect(func(id: StringName, _current: float, _maximum: float, _fraction: float, _regen: bool) -> void:
		notifications.append(id)
		snapshots.append(Vector2(attributes.get_vital_value(&"mana"), attributes.get_vital_value(&"stamina")))
	)
	_check(attributes.try_spend(&"mana", 2.0), "prepare insufficient combined balance")
	_check(not component.can_activate_ability(definition.ability_id), "preflight checks combined mana cost")
	_check(attributes.modify_vital(&"mana", 2.0), "restore balance before activation")
	_check(component.try_activate_ability(definition.ability_id), "accept affordable cast")
	ability.update(0.05)
	_check(attributes.try_spend(&"mana", 2.0), "balance falls during windup")
	notifications.clear()
	snapshots.clear()
	ability.update(0.06)
	_check(attributes.get_vital_value(&"mana") == 5.0 and attributes.get_vital_value(&"stamina") == 2.0
		and notifications.is_empty() and cooldown.get_cooldown_remaining(ability) == 0.0
		and events == [&"ability_activated", &"ability_commit_failed", &"ability_completed"],
		"failed batch leaves all balances and cooldown untouched")
	_check(attributes.modify_vital(&"mana", 2.0), "restore balance for retry")
	notifications.clear()
	snapshots.clear()
	events.clear()
	_check(component.try_activate_ability(definition.ability_id), "retry with enough mana")
	ability.update(0.05)
	ability.update(0.06)
	_check(notifications == [&"stamina", &"mana"] and snapshots == [Vector2(0, 1), Vector2(0, 1)]
		and cooldown.get_cooldown_remaining(ability) == 1.0
		and events == [&"ability_activated", &"ability_committed", &"ability_completed"],
		"successful batch exposes both final balances and commits once")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	owner.free()

func _test_disabled_cast() -> void:
	var owner: Node = Node.new()
	add_child(owner)
	owner.set_meta("balance", 1)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.ability_id = &"disabled_cast"
	definition.disabled = true
	definition.cooldown_duration = 1.0
	definition.costs = [WindupCost.new()]
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var cd: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var events: Array[StringName] = []
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") == definition.ability_id:
			events.append(event)
	AbilityEventBus.game_event_occurred.connect(observe)

	_check(not component.can_activate_ability(definition.ability_id), "disabled definition rejects preflight")
	_check(not component.try_activate_ability(definition.ability_id), "disabled definition rejects direct component activation")
	_check(not ability.try_activate(), "disabled instance rejects direct activation")
	ability.update(0.01)
	_check(owner.get_meta("balance") == 1 and cd.get_cooldown_remaining(ability) == 0.0
		and not ability.is_active and events.is_empty(), "disabled cast has no payment, cooldown or events")

	component.enable_ability(definition.ability_id)
	var other_instance: GameplayAbilityInstance = definition.create_instance(owner)
	_check(not ability.disabled and other_instance.disabled and definition.disabled,
		"runtime enabling does not mutate the shared definition or another instance")
	other_instance.dispose()
	component.disable_ability(definition.ability_id)
	_check(not component.can_activate_ability(definition.ability_id)
		and not component.try_activate_ability(definition.ability_id), "runtime disable blocks both entries")
	component.enable_ability(definition.ability_id)
	_check(component.can_activate_ability(definition.ability_id)
		and component.try_activate_ability(definition.ability_id), "re-enabled cast can start")
	ability.update(0.01)
	_check(owner.get_meta("balance") == 0 and cd.get_cooldown_remaining(ability) == 1.0
		and events == [&"ability_activated", &"ability_committed", &"ability_completed"],
		"re-enabled cast pays, starts cooldown and emits normally")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	owner.free()

class ProbeStep extends BTNode:
	@export var index: int = 0
	@export var fails: bool = false

	func _tick(instance: BTInstance, _delta: float) -> int:
		var context: Dictionary = instance.blackboard.get_var("context", {})
		var owner: Node = context["instigator"]
		var steps: Array = owner.get_meta("steps")
		steps.append(index)
		return Status.FAILURE if fails else Status.SUCCESS

class ProbeModifier extends GameplayAbilityModifier:
	func on_after_ability_commit(
		_component: GameplayAbilityComponent, _ability: GameplayAbilityInstance, context: Dictionary
	) -> void:
		var owner: Node = context["instigator"]
		var hooks: Array = owner.get_meta("hooks")
		hooks.append(owner.get_meta("balance"))
		owner.set_meta("steps_at_commit", owner.get_meta("steps").size())
		if owner.get_meta("cancel_on_commit", false):
			_component.cancel_ability(_ability.get_definition().ability_id)

class CancelDuringPayment extends WindupCost:
	func _try_pay(component: Node, owner: Node) -> bool:
		var paid: bool = super(component, owner)
		(component as GameplayAbilityComponent).cancel_ability(&"cancel_during_payment")
		return paid

func _test_combo_commit() -> void:
	for scenario: String in ["full", "timeout", "step_failure", "second_step_failure", "late_cost_failure", "cancel_before_tick", "cancel_after_first", "cancel_on_commit", "cancel_during_payment", "no_cost", "no_cost_no_cooldown"]:
		_test_combo_case(scenario)

func _test_combo_case(scenario: String) -> void:
	var owner: Node = Node.new()
	add_child(owner)
	owner.set_meta("balance", 1)
	owner.set_meta("steps", [])
	owner.set_meta("hooks", [])
	owner.set_meta("cancel_on_commit", scenario == "cancel_on_commit")
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	owner.add_child(component)
	component.set_process(false)
	var modifiers: GameplayModifierComponent = GameplayModifierComponent.new()
	owner.add_child(modifiers)
	component.modifier_component = modifiers
	modifiers.add_modifier(ProbeModifier.new())
	var combo: ComboAbilityDefinition = ComboAbilityDefinition.new()
	combo.ability_id = StringName(scenario)
	combo.window_duration = 0.2
	combo.cooldown_duration = 0.0 if scenario == "no_cost_no_cooldown" else 1.0
	if not scenario.begins_with("no_cost"):
		var cost: AbilityCostBase = CancelDuringPayment.new() if scenario == "cancel_during_payment" else WindupCost.new()
		combo.costs = [cost]
	var fail_step: int = 0
	if scenario == "step_failure":
		fail_step = 1
	elif scenario == "second_step_failure":
		fail_step = 2
	for index: int in range(3 if fail_step == 2 else 2):
		var step: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
		var node: ProbeStep = ProbeStep.new()
		node.index = index + 1
		node.fails = node.index == fail_step

		step.execution_tree = node
		combo.combo_steps.append(step)
	component.learn_ability(combo)
	var next: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	next.ability_id = &"follow_up_cast"
	next.execution_tree = BTWait.new()
	component.learn_ability(next)
	var completed: Array[GameplayAbilityInstance] = []
	component.ability_completed.connect(func(finished: GameplayAbilityInstance) -> void: completed.append(finished))
	var ability: GameplayAbilityInstance = component.get_ability_instance(combo.ability_id)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var events: Array[StringName] = []
	var failures: Array[Vector3] = []
	var observe: Callable = func(event: StringName, context: Dictionary) -> void:
		if context.get("ability_id") == combo.ability_id:
			events.append(event)
			if event == &"ability_combo_step_failed":
				var step_number: int = context.get("step_number", 0)
				failures.append(Vector3(step_number, owner.get_meta("balance"), cooldown.get_cooldown_remaining(ability)))
				if scenario == "second_step_failure":
					_check(component.try_activate_ability(next.ability_id), "failure observer starts follow-up cast")
	AbilityEventBus.game_event_occurred.connect(observe)
	var accepted: bool = component.try_activate_ability(combo.ability_id)
	_check(accepted and owner.get_meta("balance") == 1 and events == [&"ability_activated"]
		and owner.get_meta("hooks").is_empty(), scenario + ": acceptance has no commit or payment")
	if scenario == "late_cost_failure":
		owner.set_meta("balance", 0)
	if scenario == "cancel_before_tick":
		component.cancel_ability(combo.ability_id)
	ability.update(0.01)
	if scenario == "cancel_after_first":
		component.cancel_ability(combo.ability_id)
	var first_cd: float = cooldown.get_cooldown_remaining(ability) if cooldown != null else 0.0
	if scenario == "full" or fail_step == 2:
		_check(component.can_activate_ability(combo.ability_id) and component.try_activate_ability(combo.ability_id),
		"follow-up works after spending the last point")
		ability.update(0.01)
		ability.update(0.01)
	elif scenario == "timeout" or scenario.begins_with("no_cost"):
		ability.update(0.3)
	if scenario == "late_cost_failure":
		_check(owner.get_meta("steps").is_empty() and owner.get_meta("hooks").is_empty()
			and cooldown.get_cooldown_remaining(ability) == 0.0 and not ability.is_active
			and events == [&"ability_activated", &"ability_commit_failed", &"ability_completed"],
			"combo commit failure runs no segments, success hook or cooldown")
	elif scenario == "cancel_before_tick":
		_check(owner.get_meta("balance") == 1 and owner.get_meta("steps").is_empty()
			and owner.get_meta("hooks").is_empty() and not ability.is_active and first_cd == 0.0
			and events == [&"ability_activated", &"ability_completed", &"ability_cancelled"],
			"cancel before commit leaves balance and cooldown untouched")
		_check(component.can_activate_ability(combo.ability_id), "pre-commit cancellation permits an immediate retry")
	elif scenario.begins_with("cancel_"):
		var expected: Array[int] = []
		if scenario == "cancel_after_first":
			expected.append(1)
		_check(owner.get_meta("balance") == 0 and owner.get_meta("hooks") == [0]
			and owner.get_meta("steps") == expected and not ability.is_active and first_cd == 1.0
			and events == [&"ability_activated", &"ability_committed", &"ability_completed", &"ability_cancelled"],
			scenario + ": retain payment and start cooldown without executing more steps")
	elif fail_step > 0:
		var executed: Array[int] = [1]
		if fail_step == 2:
			executed.append(2)
		_check(owner.get_meta("steps") == executed and not ability.is_active
			and failures == [Vector3(fail_step, 0, 1)]
			and events == [&"ability_activated", &"ability_committed", &"ability_combo_step_failed", &"ability_completed"],
			scenario + ": stop on the failed segment and report its number after starting cooldown")
		if scenario == "second_step_failure":
			_check(completed == [ability] and component.get_current_casting_ability() == component.get_ability_instance(next.ability_id),
				"original combo completes once and the next cast remains current")
	else:
		var expected_steps: Array[int] = [1]
		if scenario == "full" or fail_step == 2:
			expected_steps.append(2)
		var expected_balance: int = 1 if scenario.begins_with("no_cost") else 0
		_check(owner.get_meta("steps") == expected_steps and owner.get_meta("balance") == expected_balance
			and owner.get_meta("hooks") == [expected_balance] and owner.get_meta("steps_at_commit") == 0,
			scenario + ": whole cost commits once before the first segment")
		var final_cd: float = cooldown.get_cooldown_remaining(ability) if cooldown != null else 0.0
		_check(first_cd == 0.0 and not ability.is_active
			and final_cd == combo.cooldown_duration and failures.is_empty()
			and events == [&"ability_activated", &"ability_committed", &"ability_completed"],
			scenario + ": no reactivation event and cooldown starts only on exit")
	AbilityEventBus.game_event_occurred.disconnect(observe)
	owner.free()
