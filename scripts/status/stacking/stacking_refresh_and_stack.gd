extends StatusStackingPolicy
class_name StackingRefreshAndStack

## 刷新持续时间并增加层数策略
## 同时刷新持续时间和增加层数

func _handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool:
	existing_instance.refresh_duration()
	existing_instance.add_stack(new_stacks, false)  # 不刷新持续时间（已经刷新过了）
	return true
