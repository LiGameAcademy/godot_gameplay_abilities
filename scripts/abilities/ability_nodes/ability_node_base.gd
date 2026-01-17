extends BTAction
class_name AbilityNodeBase

## 技能节点基类
## 提供通用的目标获取和上下文处理功能

## [配置] 目标在黑板中的 Key
@export var target_key: String = "targets"

## 获取上下文（从黑板中获取 Dictionary）
## [param] instance: BTInstance 行为树实例
## [return] Dictionary 上下文，如果无效则返回空字典
func _get_context(instance: BTInstance) -> Dictionary:
	var context = instance.blackboard.get_var("context")
	if context is Dictionary:
		return context
	return {}

## 获取目标列表（统一化处理）
## 支持从黑板中获取单个 Node、Array[Node] 或空值
## 如果目标为空，且 use_instigator_as_fallback 为 true，则使用 instigator 作为目标（自施法）
## 
## [param] instance: BTInstance 行为树实例
## [param] use_instigator_as_fallback: bool 如果没有目标，是否使用 instigator 作为回退
## [return] Array[Node] 目标列表
func _get_target_list(instance: BTInstance, use_instigator_as_fallback: bool = false) -> Array[Node]:
	var raw_targets = instance.blackboard.get_var(target_key)
	var context = _get_context(instance)
	
	var target_list: Array[Node] = []
	
	# 处理空值或空数组
	if raw_targets == null or (raw_targets is Array and raw_targets.is_empty()):
		if use_instigator_as_fallback and context.has("instigator"):
			var instigator = context.get("instigator")
			if is_instance_valid(instigator):
				target_list.append(instigator)
		return target_list
	
	# 处理数组
	if raw_targets is Array:
		for item in raw_targets:
			if item is Node and is_instance_valid(item):
				target_list.append(item as Node)
		return target_list
	
	# 处理单个节点
	if raw_targets is Node and is_instance_valid(raw_targets):
		target_list.append(raw_targets as Node)
		return target_list
	
	# 如果都不匹配，尝试使用 instigator 作为回退
	if use_instigator_as_fallback and context.has("instigator"):
		var instigator = context.get("instigator")
		if is_instance_valid(instigator):
			target_list.append(instigator)
	
	return target_list

## 获取第一个目标（用于只需要单个目标的场景）
## [param] instance: BTInstance 行为树实例
## [param] use_instigator_as_fallback: bool 如果没有目标，是否使用 instigator 作为回退
## [return] Node 第一个目标，如果不存在则返回 null
func _get_first_target(instance: BTInstance, use_instigator_as_fallback: bool = false) -> Node:
	var target_list = _get_target_list(instance, use_instigator_as_fallback)
	if target_list.is_empty():
		return null
	return target_list[0]

## 验证上下文是否有效
## [param] instance: BTInstance 行为树实例
## [param] node_name: String 节点名称（用于错误提示）
## [return] bool 上下文是否有效
func _validate_context(instance: BTInstance, node_name: String = "") -> bool:
	var context = _get_context(instance)
	if context.is_empty():
		var name_str = node_name if not node_name.is_empty() else get_script().get_path().get_file()
		push_warning("%s: Context is empty!" % name_str)
		return false
	return true

