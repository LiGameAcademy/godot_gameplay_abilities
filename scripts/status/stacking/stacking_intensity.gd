extends StatusStackingPolicy
class_name StackingIntensity

## 增加层数策略
## 当相同状态重复施加时，增加层数并刷新持续时间

func _handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool:
	existing_instance.add_stack(new_stacks, true)
	return true
