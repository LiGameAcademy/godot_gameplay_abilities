extends TargetingStrategy
class_name UnitTargetingStrategy

## 单位目标策略
## 适用于：指向性技能、治疗友军、攻击敌军等
##
## 策略优先级：
## 1. 如果提供了 input_target，使用它
## 2. 如果 context 中有 target_unit，使用它
## 3. 如果配置了 hit_detector，使用检测器
## 4. 否则返回空列表

func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []
	
	# 优先级1: 输入目标
	if is_instance_valid(input_target):
		targets.append(input_target)
		return targets
	
	# 优先级2: 上下文中的目标单位
	var target_unit = context.get("target_unit")
	if is_instance_valid(target_unit):
		targets.append(target_unit)
		return targets
	
	# 优先级3: 命中检测器
	var hit_detector = context.get("hit_detector")
	if hit_detector is HitDetectorBase:
		if instigator is Node3D:
			targets = hit_detector.get_targets(instigator as Node3D, context)
			if not targets.is_empty():
				return targets
	
	# 优先级4: 无目标
	return []

func _get_description() -> String:
	return "Unit Target (指定单位)"

func _is_ranged() -> bool:
	return true  # 单位目标通常是远程技能（需要指向目标）

