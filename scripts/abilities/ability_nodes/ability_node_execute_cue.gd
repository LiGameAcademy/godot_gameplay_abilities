extends AbilityNodeBase
class_name AbilityNodeExecuteCue

## 执行 Cue 节点
## 在目标上执行 GameplayCue，用于播放特效、音效等表现
##
## 注意：对于持续性的 Cue（如附加粒子），会将 Cue 实例保存到黑板中，
## 以便后续通过 AbilityNodeStopCue 停止

## [配置] 要执行的 Cue 资源
@export var cue: GameplayCue = null

## [配置] Cue Key（如果设置了，优先从黑板读取 Cue，否则使用配置的 cue）
## 用于动态注入 Cue（如从技能定义中读取）
@export var cue_key: String = ""

## [配置] 保存 Cue 实例的 Key（用于后续停止）
## 如果设置了，会将克隆的 Cue 实例保存到黑板中
@export var save_instance_key: String = ""

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 获取上下文和施法者
	var context = _get_context(instance)
	if context.is_empty():
		return Status.SUCCESS
	
	var instigator = context.get("instigator")
	if not is_instance_valid(instigator):
		return Status.SUCCESS
	
	# 2. 获取目标列表（如果没目标，使用 instigator 作为目标）
	var target_list = _get_target_list(instance, true)
	if target_list.is_empty():
		push_warning("AbilityNodeExecuteCue: No valid target found")
		return Status.FAILURE
	
	# 3. 获取 Cue（优先从黑板读取，否则使用配置的）
	var cue_to_execute = cue
	if not cue_key.is_empty():
		var blackboard_cue = instance.blackboard.get_var(cue_key)
		if is_instance_valid(blackboard_cue) and blackboard_cue is GameplayCue:
			cue_to_execute = blackboard_cue as GameplayCue
	
	if not is_instance_valid(cue_to_execute):
		push_warning("AbilityNodeExecuteCue: Cue is not valid")
		return Status.FAILURE
	
	# 4. 对每个目标执行 Cue
	for target in target_list:
		if not is_instance_valid(target):
			continue
		
		# 【关键】克隆 Cue 实例（避免直接修改配置数据）
		# 使用 deep 复制，确保所有 Cue 组件也被克隆
		var cue_instance = cue_to_execute.duplicate(true) as GameplayCue
		if not is_instance_valid(cue_instance):
			push_warning("AbilityNodeExecuteCue: Failed to duplicate cue instance")
			continue
		
		# 构建上下文信息（包含 instigator，供 Cue 组件使用）
		var cue_context = {
			"instigator": instigator,
			"target": target,
			"ability_context": context
		}
		
		# 执行 Cue（Manager 会处理挂点计算）
		GameplayCueManager.execute_cue(cue_instance, target, cue_context)
		
		# 如果设置了 save_instance_key，保存 Cue 实例到黑板（用于后续停止）
		if not save_instance_key.is_empty():
			# 如果目标列表只有一个，直接保存；如果有多个，保存为字典
			if target_list.size() == 1:
				instance.blackboard.set_var(save_instance_key, cue_instance)
			else:
				# 多个目标时，使用字典保存，key 是目标的 RID
				var cue_dict = instance.blackboard.get_var(save_instance_key, {})
				if not cue_dict is Dictionary:
					cue_dict = {}
				cue_dict[str(target.get_rid())] = cue_instance
				instance.blackboard.set_var(save_instance_key, cue_dict)
	
	return Status.SUCCESS

