extends HitDetectorBase
class_name ConeHitDetector

## 扇形/锥形命中检测器（混合检测）
## 适用于：扇形AOE技能（如《英雄联盟》的某些技能）
## 特点：结合距离和角度判断

@export_group("Cone Settings")
@export var max_range: float = 5.0  ## 最大距离
@export var angle_degrees: float = 60.0  ## 扇形角度（度）
@export var include_radius: bool = true  ## 是否考虑目标体积半径
@export var default_target_radius: float = 0.5  ## 默认目标半径

@export_group("Filter Settings")
@export var require_los: bool = false  ## 是否需要视线
@export var los_layer_mask: int = 1  ## 视线检测的碰撞遮罩

func _get_targets(caster: Node3D, context: Dictionary) -> Array[Node]:
	if not is_instance_valid(caster):
		return []
	
	# 确定检测位置和方向
	var detection_position = caster.global_position
	var detection_direction: Vector3
	
	if context.has("target_position"):
		detection_direction = (context["target_position"] - detection_position).normalized()
	elif context.has("target_unit") and is_instance_valid(context["target_unit"]):
		var target = context["target_unit"] as Node3D
		if target:
			detection_direction = (target.global_position - detection_position).normalized()
	else:
		# 使用施法者的朝向
		if caster.has_method("get_forward_direction"):
			detection_direction = caster.get_forward_direction()
		else:
			# 默认朝向（例如：Z轴负方向）
			detection_direction = -Vector3.FORWARD
	
	# 使用物理查询获取范围内的所有潜在目标
	var space_state = caster.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 使用球形查询（半径 = max_range）
	var shape = SphereShape3D.new()
	shape.radius = max_range
	query.shape = shape
	query.transform = Transform3D(Basis(), detection_position)
	query.collision_mask = context.get("collision_mask", 1)
	query.exclude = [caster]
	
	var results = space_state.intersect_shape(query)
	var valid_targets: Array[Node] = []
	var processed_entities = {}
	
	# 计算角度阈值（转换为弧度）
	var angle_rad = deg_to_rad(angle_degrees)
	var cos_angle = cos(angle_rad / 2.0)
	
	for result in results:
		var collider = result.get("collider")
		if not is_instance_valid(collider):
			continue
		
		# 转换为实体
		var entity = CombatUtils.get_entity_from_collider(collider)
		if not is_instance_valid(entity):
			continue
		
		# 避免重复
		var entity_id = entity.get_instance_id()
		if processed_entities.has(entity_id):
			continue
		processed_entities[entity_id] = true
		
		# 获取目标位置
		var target_pos: Vector3
		if entity is Node3D:
			target_pos = entity.global_position
		else:
			# 尝试从子节点获取3D位置
			var target_3d = entity as Node
			for child in target_3d.get_children():
				if child is Node3D:
					target_pos = child.global_position
					break
			
			if target_pos == Vector3.ZERO:
				continue
		
		# 计算距离
		var distance = detection_position.distance_to(target_pos)
		
		# 考虑目标半径
		if include_radius:
			var target_radius = default_target_radius
			if entity.has_method("get_radius"):
				target_radius = entity.get_radius()
			distance -= target_radius
		
		# 检查距离
		if distance > max_range:
			continue
		
		# 检查角度（是否在扇形内）
		var to_target = (target_pos - detection_position).normalized()
		var dot_product = detection_direction.dot(to_target)
		
		if dot_product < cos_angle:
			continue  # 不在扇形内
		
		# 检查视线（如果需要）
		if require_los:
			if not _check_line_of_sight(caster, target_pos):
				continue
		
		valid_targets.append(entity)
	
	return valid_targets

## 检查视线
func _check_line_of_sight(caster: Node3D, target_position: Vector3) -> bool:
	var space_state = caster.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(caster.global_position, target_position)
	query.collision_mask = los_layer_mask
	query.exclude = [caster]
	
	var result = space_state.intersect_ray(query)
	return not result  # 如果没有阻挡，返回true

func _get_description() -> String:
	var desc = "Cone Detector: Range %.1f, Angle %.1f°" % [max_range, angle_degrees]
	if include_radius:
		desc += " (with radius)"
	if require_los:
		desc += " (requires LOS)"
	return desc
