extends GameplayEffect
class_name GE_ApplyStatus

## 应用状态效果
## 为目标应用一个状态（Buff/Debuff）

@export var status_data: GameplayStatusData = null  ## 状态数据
@export var stacks: int = 1  ## 层数

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	status_data = context.get("status_data", status_data)
	stacks = context.get("status_stacks", stacks)
	
	if not is_instance_valid(status_data):
		push_error("GE_ApplyStatus: status_data is not set!")
		return
	
	var status_comp : GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not status_comp:
		push_error("GE_ApplyStatus: Target %s has no GameplayStatusComponent!" % target.name)
		return
	
	# 应用状态
	status_comp.apply_status(status_data, instigator, stacks, context)

func _get_description() -> String:
	if not is_instance_valid(status_data):
		return "Apply status to target\n"
	return "Apply status %s to target\n" % [status_data.status_display_name]
