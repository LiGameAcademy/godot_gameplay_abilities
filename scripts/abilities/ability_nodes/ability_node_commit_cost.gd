extends AbilityNodeBase
class_name AbilityNodeCommitCost

## 提交消耗节点
## 职责：检查并消耗技能所需的资源（如魔法值、体力等）
##
## 原理：
## 该节点从 AbilityInstance 中获取 CostFeature，并调用其 try_pay 方法。
## 如果消耗失败，节点返回 FAILURE，中断技能执行。

@export var cost_feature_name: String = "CostFeature"
var report_commit_failure: bool = false
var report_commit_success: bool = false
var allow_missing_feature: bool = false

func _tick(instance: BTInstance, _delta: float) -> int:
	var ability: GameplayAbilityInstance = instance.blackboard.get_var("ability_instance") as GameplayAbilityInstance
	if not is_instance_valid(ability):
		push_error("AbilityNodeCommitCost: ability is not valid!")
		return Status.FAILURE
	var cost_feature: CostFeature = ability.get_feature(cost_feature_name) as CostFeature
	var context: Dictionary = instance.blackboard.get_var("context", {})
	var paid: bool = allow_missing_feature
	var tracks_combo: bool = report_commit_success and ability.uses_default_combo()
	if tracks_combo:
		ability.combo_payment_in_progress = true
	if is_instance_valid(cost_feature):
		paid = cost_feature.try_pay(ability, context)
	elif not allow_missing_feature:
		push_error("AbilityNodeCommitCost: cost feature is not valid!")
	if tracks_combo:
		ability.combo_payment_in_progress = false
		ability.combo_committed = paid
	var component: GameplayAbilityComponent = context.get("ability_component") as GameplayAbilityComponent
	if (paid and report_commit_success) or (not paid and report_commit_failure):
		if is_instance_valid(component):
			component.report_default_commit(ability, context, paid)
	# A payment listener can request cancellation before the payment result is known.
	if tracks_combo and ability.combo_cancel_pending:
		ability.combo_cancel_pending = false
		if ability.is_active and is_instance_valid(component):
			component.cancel_ability(ability.get_definition().ability_id)
	# A commit observer may synchronously end the combo.
	return Status.SUCCESS if paid and (not report_commit_success or ability.is_active) else Status.FAILURE
