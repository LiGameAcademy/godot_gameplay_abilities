extends AbilityNodeBase
class_name AbilityNodeStopCue

## 停止 Cue 节点
## 停止之前通过 AbilityNodeExecuteCue 执行的持续性 Cue
##
## 注意：此节点会从黑板中读取之前保存的 Cue 实例，并调用其所有组件的 stop 方法

## [配置] Cue 实例在黑板中的 Key（从 AbilityNodeExecuteCue 的 save_instance_key 读取）
@export var cue_instance_key: String = ""

func _tick(instance: BTInstance, delta: float) -> int:
	if cue_instance_key.is_empty():
		push_warning("AbilityNodeStopCue: cue_instance_key is empty")
		return Status.FAILURE
	
	# 1. 获取上下文和目标
	var context = _get_context(instance)
	if not is_instance_valid(context):
		return Status.SUCCESS
	
	# 2. 从黑板中获取 Cue 实例
	var cue_data = instance.blackboard.get_var(cue_instance_key)
	if not is_instance_valid(cue_data):
		# 如果没有保存的 Cue 实例，说明可能没有执行过 Cue，直接返回成功
		return Status.SUCCESS
	
	# 3. 获取目标列表（如果没目标，使用 instigator 作为目标）
	var target_list = _get_target_list(instance, true)
	if target_list.is_empty():
		push_warning("AbilityNodeStopCue: No valid target found")
		return Status.FAILURE
	
	# 4. 处理 Cue 实例（可能是单个实例或字典）
	if cue_data is GameplayCue:
		# 单个 Cue 实例（单个目标的情况）
		var cue_instance = cue_data as GameplayCue
		var target = target_list[0] if not target_list.is_empty() else context.instigator
		if is_instance_valid(target):
			_stop_cue_instance(cue_instance, target)
	else:
		# 字典形式（多个目标的情况）
		if cue_data is Dictionary:
			for target in target_list:
				if not is_instance_valid(target):
					continue
				var target_rid_str = str(target.get_rid())
				if cue_data.has(target_rid_str):
					var cue_instance = cue_data[target_rid_str]
					if is_instance_valid(cue_instance) and cue_instance is GameplayCue:
						_stop_cue_instance(cue_instance as GameplayCue, target)
	
	# 5. 清理黑板中的 Cue 实例
	instance.blackboard.erase_var(cue_instance_key)
	
	return Status.SUCCESS

## 停止单个 Cue 实例
## [param] cue_instance: GameplayCue Cue 实例
## [param] target: Node 目标节点
func _stop_cue_instance(cue_instance: GameplayCue, target: Node) -> void:
	if not is_instance_valid(cue_instance) or not is_instance_valid(target):
		return
	
	# 【关键】使用克隆的 Cue 实例停止持续效果
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in cue_instance.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 如果 Cue 组件实现了 stop 方法，调用它
		if cue_component.has_method("stop"):
			cue_component.stop(target)

