extends StatusStackingPolicy
class_name StackingRefreshDuration

## 刷新持续时间策略
## 当相同状态重复施加时，刷新持续时间，不增加层数

func _handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool:
	existing_instance.refresh_duration()
	return true
