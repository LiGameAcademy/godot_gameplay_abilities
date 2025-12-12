extends GameplayEffect
class_name GE_ApplyToAreaTargets

## 对区域目标应用效果（Meta Effect）
## 使用 hit_detector 检测区域内的目标，然后对每个目标应用 sub_effects
## 适用于：AOE技能、范围伤害、区域效果

@export var hit_detector: HitDetectorBase = null  ## 区域命中检测器（如果为null，从context中获取）

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	# 1. 获取 hit_detector（优先使用配置的，否则从context中获取）
	var detector = hit_detector
	if not is_instance_valid(detector):
		detector = context.get("hit_detector", null) as HitDetectorBase
	
	if not is_instance_valid(detector):
		push_warning("GE_ApplyToAreaTargets: No hit_detector found in config or context")
		return
	
	# 2. 确保 instigator 是 Node3D（hit_detector 需要）
	if not instigator is Node3D:
		push_warning("GE_ApplyToAreaTargets: Instigator is not Node3D, cannot detect targets")
		return
	
	# 3. 检测区域内的目标
	var area_targets = detector.get_targets(instigator as Node3D, context)
	if area_targets.is_empty():
		# 没有目标，静默失败
		return
	
	# 4. 对每个目标应用 sub_effects
	# 注意：这是一个 Meta Effect，所以 _should_auto_apply_sub_effects() 返回 false
	# 我们需要手动控制子效果的应用
	for area_target in area_targets:
		if not is_instance_valid(area_target):
			continue
		
		# 对每个目标应用所有子效果
		for sub_effect_template in sub_effects:
			if not is_instance_valid(sub_effect_template):
				continue
			
			# 克隆子效果实例（避免状态共享）
			var sub_effect_clone = sub_effect_template.duplicate(true) as GameplayEffect
			if not is_instance_valid(sub_effect_clone):
				continue
			
			# 应用子效果到区域目标（不是原始target）
			sub_effect_clone.apply(area_target, instigator, context)

## [重写] Meta Effect 不自动应用子效果，由自己控制
func _should_auto_apply_sub_effects() -> bool:
	return false

func _get_description() -> String:
	var detector_desc = "未配置"
	if is_instance_valid(hit_detector):
		if hit_detector is AreaHitDetector:
			detector_desc = "范围: %.1f" % (hit_detector as AreaHitDetector).detection_radius
		else:
			detector_desc = hit_detector.get_class()
	
	return "对区域目标应用效果 (检测器: %s, 子效果数: %d)\n" % [detector_desc, sub_effects.size()]
