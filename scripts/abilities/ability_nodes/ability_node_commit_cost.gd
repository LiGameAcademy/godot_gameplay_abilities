extends BTAction
class_name AbilityNodeCommitCost

## 提交消耗节点
## 职责：检查并消耗技能所需的资源（如魔法值、体力等）
##
## 原理：
## 该节点从 AbilityInstance 中获取 CostFeature，并调用其 try_pay 方法。
## 如果消耗失败，节点返回 FAILURE，中断技能执行。

@export var cost_feature_name: String = "CostFeature"

func _tick(instance: BTInstance, delta: float) -> int:
	var ability = instance.blackboard.get_var("ability_instance")
	if not is_instance_valid(ability):
		push_warning("AbilityNodeCommitCost: AbilityInstance 不存在，无法提交消耗")
		return Status.FAILURE
	
	var context = instance.blackboard.get_var("context")

	# 获取 CostFeature
	var cost_feature : CostFeature = ability.get_feature(cost_feature_name)
	if not is_instance_valid(cost_feature):
		# 如果没有配置 CostFeature，视为成功（允许无消耗技能）
		return Status.SUCCESS
	
	# 尝试支付消耗
	if cost_feature.has_method("try_pay"):
		var success = cost_feature.try_pay(ability, context)
		if not success:
			# 消耗失败（如魔法值不足），返回失败
			return Status.FAILURE
	else:
		push_error("AbilityNodeCommitCost: CostFeature 没有 try_pay 方法")
	
	return Status.SUCCESS
