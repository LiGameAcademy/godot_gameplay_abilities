@tool
extends GameplayFilterData
class_name FilterTargetIsAlive

## Reads the target's health when available and uses the death group for other targets.

@export var must_be_alive: bool = true  ## 是要检查"活着"还是"死了"

func _check(target: Node, _instigator: Node, _context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return not must_be_alive  # 目标无效

	var component: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(
		target, "GameplayVitalAttributeComponent", false) as GameplayVitalAttributeComponent
	if not is_instance_valid(component):
		component = GameplayAbilitySystem.get_component_by_interface(
			target, "GameplayAttributeComponent", false) as GameplayVitalAttributeComponent
	if is_instance_valid(component):
		var health: HealthVital = component.get_vital(&"health") as HealthVital
		if is_instance_valid(health):
			return health.is_alive == must_be_alive
	return target.is_in_group(HealthVital.DEATH_GROUP_NAME) != must_be_alive

