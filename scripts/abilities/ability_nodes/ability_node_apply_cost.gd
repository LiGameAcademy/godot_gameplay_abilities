extends AbilityNodeBase
class_name AbilityNodeApplyCost

## 检查并应用消耗节点
## 直接检查并扣除目标的 Vital（不经过 CostFeature）
##
## 用途：
## - 周期性检查并消耗资源（如献祭技能每秒检查并消耗1点生命值）
## - 与 BTRepeatPeriodic 配合使用
##
## 注意：
## - 先检查是否可以支付消耗，如果可以则支付
## - 直接访问目标的 Vital 组件，不经过 CostFeature
## - 如果检查失败或支付失败，返回 FAILURE

@export_group("Cost Settings")
## 要消耗的 Vital ID（如 "health", "mana"）
@export var vital_id: StringName = &"health"
## 消耗数量
@export var cost_amount: float = 1.0
## 是否允许透支（如果为 false，当前值必须 >= cost_amount）
@export var allow_overdraft: bool = false
## 是否只检查不消耗（如果为 true，只检查不实际扣除）
@export var check_only: bool = false
## Vital 组件名称（用于查找组件）
@export var vital_comp_name: StringName = &"GameplayVitalAttributeComponent"

func _tick(instance: BTInstance, _delta: float) -> int:
	if not _validate_context(instance, "AbilityNodeApplyCost"):
		return Status.FAILURE
	
	# 获取目标列表（默认使用自身）
	var target_list: Array[Node] = _get_target_list(instance, true)
	if target_list.is_empty():
		push_warning("AbilityNodeApplyCost: 没有找到目标")
		return Status.FAILURE
	
	# 处理第一个目标的 Vital（通常只有一个目标）
	var target: Node = target_list[0]
	if not is_instance_valid(target):
		return Status.FAILURE
	
	# 获取 Vital 组件
	var vital_comp: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name) as GameplayVitalAttributeComponent
	if not is_instance_valid(vital_comp):
		push_warning("AbilityNodeApplyCost: 目标 %s 没有 %s 组件" % [target.name, vital_comp_name])
		return Status.FAILURE
	
	if check_only:
		return Status.SUCCESS if vital_comp.can_spend(vital_id, cost_amount, allow_overdraft) else Status.FAILURE
	return Status.SUCCESS if vital_comp.try_spend(vital_id, cost_amount, allow_overdraft) else Status.FAILURE
