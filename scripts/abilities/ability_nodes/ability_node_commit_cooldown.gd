extends AbilityNodeBase
class_name AbilityNodeCommitCooldown 

@export var cooldown_feature_name: String = "CooldownFeature"
var report_commit_success: bool = false
var allow_missing_feature: bool = false

func _tick(instance: BTInstance, delta: float) -> int:
	var ability = instance.blackboard.get_var("ability_instance")
	if not is_instance_valid(ability):
		push_error("AbilityNodeCommitCooldown: ability is not valid!")
		return Status.FAILURE
	var cooldown_feature : CooldownFeature = ability.get_feature(cooldown_feature_name)
	if is_instance_valid(cooldown_feature):
		cooldown_feature.start_cooldown(ability)
	elif not (report_commit_success or allow_missing_feature):
		push_error("AbilityNodeCommitCooldown: cooldown_feature is not valid!")
		return Status.FAILURE
	if report_commit_success:
		var context: Dictionary = instance.blackboard.get_var("context", {})
		var component: GameplayAbilityComponent = context.get("ability_component") as GameplayAbilityComponent
		if is_instance_valid(component):
			component.report_default_commit(ability, context, true)
	return Status.SUCCESS
