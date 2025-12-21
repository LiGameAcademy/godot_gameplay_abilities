extends BTAction
class_name AbilityNodeCommitCooldown 

@export var cooldown_feature_name: String = "CooldownFeature"

func _tick(instance: BTInstance, delta: float) -> int:
    var ability = instance.blackboard.get_var("ability_instance")
    if not is_instance_valid(ability):
        return Status.FAILURE
    var cooldown_feature = ability.get_feature(cooldown_feature_name)
    if not is_instance_valid(cooldown_feature):
        return Status.FAILURE
    # 进 CD 通常不会失败
    cooldown_feature.start_cooldown(ability)
    return Status.SUCCESS