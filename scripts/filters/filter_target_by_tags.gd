@tool
extends GameplayFilterData
class_name FilterTargetByTags

## 过滤器：通过标签筛选目标
## 用于筛选敌我、阵营、类型等
##
## 使用场景：
## - 筛选敌人：required_tags = ["Team.Enemy"]
## - 筛选友军：required_tags = ["Team.Ally"]
## - 筛选特定类型：required_tags = ["Type.Boss"]
## - 排除特定标签：blocked_tags = ["State.Invulnerable"]

@export_group("Required Tags")
## 目标必须拥有的标签（所有标签都必须拥有）
## 如果目标没有所有必需的标签，将被过滤掉
## 例如：["Team.Enemy"] 表示只选择敌人
@export var required_tags: Array[StringName] = []

@export_group("Blocked Tags")
## 目标不能拥有的标签（任意一个标签存在就会被过滤掉）
## 如果目标拥有任意一个阻止标签，将被过滤掉
## 例如：["State.Invulnerable", "State.Dead"] 表示排除无敌和死亡的目标
@export var blocked_tags: Array[StringName] = []

@export_group("Options")
## 是否包含继承的标签（默认 true）
## 如果为 true，会检查标签的继承关系
## 例如：如果目标有 "Team.Enemy" 标签，且 "Team.Enemy" 继承自 "Team.Hostile"，
## 那么检查 "Team.Hostile" 时也会返回 true
@export var include_inherited: bool = true

func _check(target: Node, instigator: Node, context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return false
	
	# 1. 检查必须标签（所有标签都必须拥有）
	if not required_tags.is_empty():
		if not TagManager.has_all_tags(target, required_tags, include_inherited):
			return false
	
	# 2. 检查阻止标签（任意一个标签存在就会被过滤）
	if not blocked_tags.is_empty():
		if TagManager.has_any_tag(target, blocked_tags, include_inherited):
			return false
	
	return true

