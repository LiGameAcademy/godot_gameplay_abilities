@tool
extends GameplayFilterData
class_name FilterTargetHasComponent

## 过滤器：检查目标是否有指定组件

@export var component_name: String = ""  ## 组件名称（如"HealthComponent"）

func _check(target: Node, _instigator: Node, _context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return false
	
	if component_name.is_empty():
		return true
	
	# 使用鸭子类型查询组件
	return CombatSystem.has_component(target, component_name)

