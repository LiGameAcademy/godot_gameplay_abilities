extends BTDecorator
class_name BTTagScope

## 标签作用域装饰器
## 职责：在子节点执行期间管理状态标签（如 State.Casting, Block.Movement）
##
## 原理：
## - 进入时：添加指定的标签到 Agent（通常是施法者）
## - 退出时：移除这些标签
## - 支持引用计数，确保嵌套使用时不会互相干扰
##
## 用途：
## - 标记技能状态（如 "State.Casting", "State.Attacking"）
## - 阻止某些行为（如 "Block.Movement", "Block.Rotation"）

@export_group("Tag Management")
## 要添加的标签列表（进入时添加，退出时移除）
@export var tags: Array[StringName] = []
## 目标节点（如果为空，则使用 Agent）
## 通常用于技能系统，Agent 就是施法者
@export var target_key: String = ""  # 如果为空，使用 agent

func _enter(instance: BTInstance) -> void:
	# 获取目标节点
	var target = _get_target(instance)
	if not is_instance_valid(target):
		push_warning("BTTagScope: Target is not valid, cannot add tags")
		return
	
	# 添加所有标签
	for tag_id in tags:
		if tag_id != &"":
			TagManager.add_tag(target, tag_id)
	
	# 记录已添加的标签，用于退出时清理
	_set_storage(instance, tags.duplicate())

func _exit(instance: BTInstance) -> void:
	# 获取目标节点
	var target = _get_target(instance)
	if not is_instance_valid(target):
		return
	
	# 获取已添加的标签列表
	var added_tags = _get_storage(instance, [])
	
	# 移除所有标签
	for tag_id in added_tags:
		if tag_id != &"":
			TagManager.remove_tag(target, tag_id)
	
	# 清理存储
	_clear_storage(instance)

## 获取目标节点
func _get_target(instance: BTInstance) -> Node:
	# 如果指定了 target_key，从黑板获取
	if not target_key.is_empty():
		var target = instance.blackboard.get_var(target_key)
		if is_instance_valid(target) and target is Node:
			return target as Node
	
	# 否则使用 Agent（通常是施法者）
	return instance.agent

