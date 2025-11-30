@tool
extends GameplayFilterData
class_name FilterTargetIsAlive

## 过滤器：检查目标是否存活

const DEATH_GROUP_NAME: String = "death"

@export var must_be_alive: bool = true  ## 是要检查"活着"还是"死了"

func _check(target: Node, _instigator: Node, _context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return not must_be_alive  # 目标无效
	
	# 检查目标是否在死亡组中
	return target.is_in_group(DEATH_GROUP_NAME) != must_be_alive

