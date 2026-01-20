extends AbilityPreviewStrategy
class_name StrategyCircleArea

func update_indicator(indicator: Node3D, caster: Node3D, mouse_position: Vector3) -> void:
	# 限制指示器在最大射程内
	var final_pos = _get_clamped_position(caster.global_position, mouse_position)
	indicator.global_position = final_pos

	# 如果是指向性贴花，可能需要调整 Y 轴适应地形（这里简化处理）

func get_targeting_context(caster: Node3D, mouse_position: Vector3) -> Dictionary:
	var final_pos = _get_clamped_position(caster.global_position, mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_type": "position"
	}
