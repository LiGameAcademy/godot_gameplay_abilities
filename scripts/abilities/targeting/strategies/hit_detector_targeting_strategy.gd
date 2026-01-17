extends TargetingStrategy
class_name HitDetectorTargetingStrategy

## 命中检测器目标策略
## 适用于：简单的目标检测场景（普通攻击、范围技能等）
## 直接使用 HitDetectorBase 进行目标检测，提供最简单的目标获取方式
##
## 注意：对于更复杂的目标获取逻辑，应该使用其他策略（如 AreaTargetingStrategy）

@export var hit_detector: HitDetectorBase = null  ## 命中检测器

func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	# 优先级1: 使用配置的 hit_detector
	if is_instance_valid(hit_detector) and instigator is Node3D:
		return hit_detector.get_targets(instigator as Node3D, context)
	
	# 优先级2: 从 context 中获取 hit_detector（向后兼容）
	var detector = context.get("hit_detector")
	if detector is HitDetectorBase and instigator is Node3D:
		return detector.get_targets(instigator as Node3D, context)
	
	# 无目标
	return []

func _get_description() -> String:
	if is_instance_valid(hit_detector):
		return "Hit Detector (%s)" % hit_detector.get_description()
	return "Hit Detector (未配置检测器)"

