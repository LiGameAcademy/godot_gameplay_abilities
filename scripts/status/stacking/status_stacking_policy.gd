@abstract
extends Resource
class_name StatusStackingPolicy

## 堆叠策略基类（抽象类）
## 定义当相同状态重复施加时的处理逻辑

## 处理堆叠逻辑
## [param] existing_instance: GameplayStatusInstance 已存在的状态实例
## [param] new_status_data: GameplayStatusData 新状态数据
## [param] new_stacks: int 新状态的层数
## [param] context: Dictionary 上下文信息
## [return] bool 是否已处理（true 表示已处理，无需创建新实例）
func handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool:
	return _handle_stacking(existing_instance, new_status_data, new_stacks, context)

## [子类重写] 处理堆叠逻辑的具体实现
@abstract
func _handle_stacking(
	existing_instance: GameplayStatusInstance,
	new_status_data: GameplayStatusData,
	new_stacks: int,
	context: Dictionary
) -> bool
