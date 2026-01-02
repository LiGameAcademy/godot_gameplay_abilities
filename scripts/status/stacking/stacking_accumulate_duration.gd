extends StatusStackingPolicy
class_name StackingAccumulateDuration

## 累加持续时间策略
## 当相同状态重复施加时，累加持续时间，不刷新

func _handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool:
	existing_instance.accumulate_duration()
	return true
