extends AbilityNodeBase
class_name AbilityNodeApplyEffect

## [配置] 要应用的效果列表
@export var effects : Array[GameplayEffect] = []

## 效果 Key（如果设置了，优先从黑板读取效果，否则使用配置的 effects）
## 用于动态注入效果（如献祭技能的周期性伤害效果）
@export var effect_key: String = ""

func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 获取上下文和施法者
	var context = _get_context(instance)
	if not is_instance_valid(context) or not is_instance_valid(context.instigator):
		return Status.SUCCESS
	
	var instigator = context.instigator

	# 2. 获取目标列表（如果没目标，视为成功（空挥））
	var target_list = _get_target_list(instance, false)

	# 3. 获取效果列表（优先从黑板读取，否则使用配置的）
	var effects_to_apply = effects
	if not effect_key.is_empty():
		var blackboard_effect = instance.blackboard.get_var(effect_key)
		if is_instance_valid(blackboard_effect) and blackboard_effect is GameplayEffect:
			effects_to_apply = [blackboard_effect as GameplayEffect]
		elif blackboard_effect is Array:
			# 支持从黑板读取效果数组
			effects_to_apply = []
			for e in blackboard_effect:
				if is_instance_valid(e) and e is GameplayEffect:
					effects_to_apply.append(e as GameplayEffect)

	# 4. 执行应用逻辑
	for target in target_list:
		if not is_instance_valid(target): 
			continue
			
		for effect in effects_to_apply:
			if not is_instance_valid(effect):
				continue
			
			# 克隆效果（避免状态共享）
			var effect_clone = effect.duplicate(true) as GameplayEffect
			if is_instance_valid(effect_clone):
				effect_clone.apply(target, instigator, context)
			
	return Status.SUCCESS
