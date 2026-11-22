extends Node
## Exercises a skill that applies a periodic status after Ability is added to the host.

const StatusProbe = preload("status_vital.gd")

class ApplyBleeding extends BTAction:
	@export var bleeding: GameplayStatusData

	func _tick(instance: BTInstance, _delta: float) -> int:
		var context: Dictionary = instance.get_var("context", {})
		var target: GameplayStatusComponent = context.get("status_target") as GameplayStatusComponent
		if not is_instance_valid(target) or target.apply_status(bleeding, instance.agent) == null:
			return Status.FAILURE
		var ability: GameplayAbilityInstance = instance.get_var("ability_instance") as GameplayAbilityInstance
		var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
		cooldown.start_cooldown(ability)
		return Status.SUCCESS

func _ready() -> void:
	var target: StatusProbe.Combatant = StatusProbe.Combatant.new()
	var caster: Node = Node.new()
	add_child(target)
	add_child(caster)
	target.setup(20.0)

	var action: ApplyBleeding = ApplyBleeding.new()
	action.bleeding = StatusProbe.create_bleeding()
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 1.0
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"bleeding_strike"
	definition.features = [cooldown]
	definition.execution_tree = action
	var abilities: GameplayAbilityComponent = GameplayAbilityComponent.new()
	caster.add_child(abilities)
	abilities.set_process(false)
	abilities.learn_ability(definition)
	var id: StringName = definition.ability_id
	var ability: GameplayAbilityInstance = abilities.get_ability_instance(id)
	var context: Dictionary = {"status_target": target.statuses}

	var accepted: bool = abilities.try_activate_ability(id, context) \
		and not target.statuses.has_status(action.bleeding.status_id) \
		and is_zero_approx(cooldown.get_cooldown_remaining(ability))
	ability.update(0.0)
	var committed: bool = not ability.is_active and target.statuses.has_status(action.bleeding.status_id) \
		and target.values.is_empty() and is_equal_approx(cooldown.get_cooldown_remaining(ability), 1.0)
	ability.update(0.5)
	target.statuses._process(0.5)
	var rejected: bool = not abilities.try_activate_ability(id, {"status_target": target.statuses}) \
		and target.values == [17.0] and target.applied == 1

	ability.update(0.5)
	for step: int in range(4):
		target.statuses._process(0.5)
	var expired: bool = not target.statuses.has_status(action.bleeding.status_id) \
		and target.values == [17.0, 14.0, 11.0] and target.received == 3 and target.applied == 3
	var recovered: bool = abilities.try_activate_ability(id, {"status_target": target.statuses})
	if not (accepted and committed and rejected and expired and recovered):
		push_error("Ability and periodic damage disagreed after incremental installation")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: Ability applies periodic damage after incremental install")
	get_tree().quit.call_deferred(0)
