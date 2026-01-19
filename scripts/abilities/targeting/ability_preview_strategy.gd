extends Resource
class_name AbilityPreviewStrategy

## 技能预览策略基类
## 职责：
## 1. 实例化并更新视觉指示器（Indicator）
## 2. 将鼠标位置转换为技能所需的上下文数据（Context）
## 
## 注意：与 TargetingStrategy（目标选择策略）不同
## - AbilityPreviewStrategy：预览阶段，显示指示器，获取鼠标位置
## - TargetingStrategy：执行阶段，在行为树中搜索目标单位

@export_group("Visuals")
## 指示器预制体（如圆形贴花、箭头模型）
@export var indicator_scene: PackedScene

@export_group("Constraints")
## 最大施法距离
@export var max_range: float = 10.0
## 是否贴地（通常为 true）
@export var snap_to_ground: bool = true

## [1] 开始瞄准：创建指示器
func create_indicator(parent: Node) -> Node3D:
	if is_instance_valid(indicator_scene):
		var instance = indicator_scene.instantiate()
		# 通常添加到当前场景根节点，避免跟随角色旋转（视需求而定）
		var root = parent.get_tree().current_scene
		root.add_child(instance)
		return instance
	return null

## [2] 更新循环：根据鼠标位置更新指示器
## [param] indicator: 由 create_indicator 创建的实例
## [param] caster: 施法者
## [param] mouse_position: 鼠标在世界空间的位置（通常是 Raycast 击中点）
func update_indicator(indicator: Node3D, caster: Node3D, mouse_position: Vector3) -> void:
	pass

## [API] 取消预览
func cancel_targeting() -> void:
	pass

## [3] 获取数据：确定目标，返回 Context 字典
## 注意：返回的 context 会传递给行为树，供 TargetingStrategy 使用
## context 中应包含 target_position，供 GroundTargetingStrategy 等策略读取
func get_targeting_context(caster: Node3D, mouse_position: Vector3) -> Dictionary:
	var final_pos = _get_clamped_position(caster.global_position, mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_type": "position"
	}
	
## [辅助] 计算限制在最大距离内的位置
func _get_clamped_position(caster_pos: Vector3, target_pos: Vector3) -> Vector3:
	var dir = target_pos - caster_pos
	# 忽略 Y 轴高度差，只计算平面距离
	var flat_dir = Vector3(dir.x, 0, dir.z)

	if flat_dir.length() > max_range:
		flat_dir = flat_dir.normalized() * max_range
		return Vector3(caster_pos.x + flat_dir.x, target_pos.y, caster_pos.z + flat_dir.z)

	return target_pos
