extends GameplayAbilityDefinition
class_name TargetedStatusAbilityDefinition

## Runs a single-target status cast on the authoritative simulation or in single player.

enum Result { PENDING, CANCELLED, TARGET_INVALID, PAYMENT_FAILED, APPLIED, STATUS_NOT_APPLIED }

const CAST_KEY: String = "targeted_status_cast"

@export_range(0.0, 60.0, 0.01, "or_greater") var windup_seconds: float = 1.0
@export_range(0.01, 60.0, 0.01, "or_greater") var cooldown_seconds: float = 3.0
@export var vital_id: StringName = &"mana"
@export_range(0.01, 1000.0, 0.01, "or_greater") var cost: float = 4.0
@export var status: GameplayStatusData


## One cast's local inputs and result. Retain it until ability_completed to read the outcome.
class Cast extends RefCounted:
	var result: Result = Result.PENDING
	var _payer: GameplayVitalAttributeComponent
	var _target: GameplayStatusComponent
	var _validate_target: Callable
	var _started: bool = false

	func _init(payer: GameplayVitalAttributeComponent, target: GameplayStatusComponent,
			validate_target: Callable) -> void:
		_payer = payer
		_target = target
		_validate_target = validate_target

	func _target_is_valid() -> bool:
		return is_instance_valid(_target) and _target.is_inside_tree() and not _target.is_queued_for_deletion() \
			and _validate_target.is_valid() and _validate_target.call(_target) == true \
			and is_instance_valid(_target) and _target.is_inside_tree() and not _target.is_queued_for_deletion()

	func _release_inputs() -> void:
		_payer = null
		_target = null
		_validate_target = Callable()


class CastGate extends GameplayAbilityFeature:
	func _init() -> void:
		super("TargetedStatusCast")

	func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
		var cast: Cast = context.get(CAST_KEY) as Cast
		var definition: TargetedStatusAbilityDefinition = ability.get_definition() as TargetedStatusAbilityDefinition
		var component: GameplayAbilityComponent = context.get("ability_component") as GameplayAbilityComponent
		var current: GameplayAbilityInstance = component.get_current_casting_ability() if is_instance_valid(component) else null
		return not ability.is_active and (current == null or not current.is_active) \
			and cast != null and not cast._started and cast._target_is_valid() \
			and is_instance_valid(cast._payer) and cast._payer.can_spend(definition.vital_id, definition.cost)

	func on_activate(_ability: GameplayAbilityInstance, context: Dictionary) -> void:
		var cast: Cast = context.get(CAST_KEY) as Cast
		cast._started = true

	func on_completed(ability: GameplayAbilityInstance) -> void:
		var context: Dictionary = ability.get_blackboard_var("context", {})
		var cast: Cast = context.get(CAST_KEY) as Cast
		if cast == null:
			return
		if cast.result == Result.PENDING:
			cast.result = Result.CANCELLED
		cast._release_inputs()
		context.erase(CAST_KEY)


class CastInstance extends GameplayAbilityInstance:
	func try_activate(context: Dictionary = {}) -> bool:
		return not is_active and super(context)


class Commit extends BTAction:
	func _tick(instance: BTInstance, _delta: float) -> int:
		var ability: GameplayAbilityInstance = instance.get_var("ability_instance") as GameplayAbilityInstance
		var context: Dictionary = instance.get_var("context", {})
		var cast: Cast = context.get(CAST_KEY) as Cast
		var component: GameplayAbilityComponent = context.get("ability_component") as GameplayAbilityComponent
		if cast == null or not is_instance_valid(component):
			return Status.FAILURE
		ability.resolve_commit(_settle.bind(ability, component, cast, context))
		return Status.SUCCESS if cast.result == Result.APPLIED else Status.FAILURE

	func _settle(ability: GameplayAbilityInstance, component: GameplayAbilityComponent,
			cast: Cast, context: Dictionary) -> void:
		var definition: TargetedStatusAbilityDefinition = ability.get_definition() as TargetedStatusAbilityDefinition
		if ability.disabled:
			cast.result = Result.CANCELLED
			return
		if not cast._target_is_valid():
			cast.result = Result.TARGET_INVALID
			return
		if not is_instance_valid(cast._payer) or not cast._payer.try_spend(definition.vital_id, definition.cost):
			cast.result = Result.PAYMENT_FAILED
			component.report_default_commit(ability, context, false)
			return
		var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
		cooldown.start_cooldown(ability)
		component.report_default_commit(ability, context, true)
		cast.result = Result.STATUS_NOT_APPLIED
		if cast._target_is_valid() and not cast._target.has_status(definition.status.status_id):
			if cast._target.apply_status(definition.status, context.get("instigator") as Node) != null:
				cast.result = Result.APPLIED


func uses_default_commit() -> bool:
	return true

func create_instance(owner: Node) -> GameplayAbilityInstance:
	if not is_finite(windup_seconds) or windup_seconds < 0.0 \
			or not is_finite(cooldown_seconds) or cooldown_seconds <= 0.0 \
			or not is_finite(cost) or cost <= 0.0 or vital_id.is_empty() \
			or not is_instance_valid(status) or status.status_id.is_empty() \
			or not is_finite(status.duration) or status.duration <= 0.0:
		return null
	var wait: BTWait = BTWait.new()
	wait.duration = windup_seconds
	var sequence: BTSequence = BTSequence.new()
	sequence.children = [wait, Commit.new()]
	var ability: GameplayAbilityInstance = CastInstance.new(owner, self, sequence)
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = cooldown_seconds
	ability.add_feature(cooldown.feature_name, cooldown)
	var gate: CastGate = CastGate.new()
	ability.add_feature(gate.feature_name, gate)
	return ability
