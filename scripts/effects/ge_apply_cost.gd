extends GameplayEffect
class_name GE_ApplyCost

## 应用资源消耗效果
## 在状态系统中用于周期性消耗资源（如引导技能的每 tick 消耗）

@export var costs: Array[AbilityCostBase] = []  ## 要应用的消耗列表

func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
	if costs.is_empty():
		return
	
	# 使用鸭子类型查询 GameplayAbilityComponent
	var ability_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayAbilityComponent")
	if not is_instance_valid(ability_comp):
		push_error("GE_ApplyCost: Instigator %s has no GameplayAbilityComponent!" % instigator.name)
		return
	
	# 应用所有消耗
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		
		# 检查是否可以支付
		if not cost.can_pay(ability_comp, instigator):
			push_warning("GE_ApplyCost: Cost cannot be paid for instigator %s" % instigator.name)
			# 注意：如果无法支付，可以选择中断状态（通过事件或返回值）
			# 这里只发出警告，由状态系统决定是否中断
			continue
		
		# 尝试支付
		if not cost.try_pay(ability_comp, instigator):
			push_warning("GE_ApplyCost: Cost pay failed for instigator %s" % instigator.name)
			continue

func _get_description() -> String:
	if costs.is_empty():
		return "Apply cost to instigator\n"
	
	var descriptions = []
	for cost in costs:
		if is_instance_valid(cost):
			descriptions.append(cost.get_cost_description())
	return "Apply cost: %s\n" % ", ".join(descriptions)

