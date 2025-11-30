extends GameplayEffect
class_name GE_ApplyStatus

## 应用状态效果
## 为目标应用一个状态（Buff/Debuff）
## 注意：这个Effect依赖于StatusComponent，StatusComponent将在后续实现

@export var status_data: GameplayStatusData = null  ## 状态数据（将在StatusComponent实现时定义）
@export var stacks: int = 1  ## 层数

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(status_data):
		push_error("GE_ApplyStatus: status_data is not set!")
		return
	
	# 使用鸭子类型查询StatusComponent（将在后续实现）
	var status_comp = CombatSystem.get_component_by_interface(target, "StatusComponent")
	if not status_comp:
		push_error("GE_ApplyStatus: Target %s has no StatusComponent!" % target.name)
		return
	
	# 应用状态（StatusComponent的接口将在后续实现）
	if status_comp.has_method("apply_status"):
		status_comp.apply_status(status_data, instigator, stacks, context)
	else:
		push_error("GE_ApplyStatus: StatusComponent does not have apply_status method!")

func _get_description() -> String:
	if not is_instance_valid(status_data):
		return "Apply status to target\n"
	return "Apply status %s to target\n" % [status_data.status_display_name]

