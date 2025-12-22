extends HitDetectorBase
class_name AreaHitDetector

## 区域命中检测器（物理检测）
## 适用于：AOE技能、非指向性技能、地雷、暴风雪
## 特点：精确、支持复杂形状、依赖物理引擎

## 检测位置来源
enum DetectionPositionSource {
	CASTER_POSITION,      ## 使用施法者位置（默认，适用于献祭等范围技能）
	TARGET_POSITION,      ## 使用目标位置（鼠标位置，适用于地面目标技能）
	HIT_POSITION,         ## 使用命中位置（投射物爆炸位置）
	DETECTION_POSITION    ## 使用显式指定的检测位置（通过 context["detection_position"] 传递）
}

@export_group("Area Settings")
@export var detection_radius: float = 3.0  ## 检测半径
@export var detection_shape: Shape3D = null  ## 自定义检测形状（如果为null，使用球形）
@export_flags_3d_physics 
var collision_mask: int = 0 | 4  ## 碰撞遮罩
@export var detection_position_source: DetectionPositionSource = DetectionPositionSource.CASTER_POSITION  ## 检测位置来源

@export_group("Query Settings")
@export var max_results: int = 32  ## 最大检测结果数量
@export var use_world_position: bool = true  ## 是否使用世界坐标
@export var exclude_caster: bool = true  ## 是否排除施法者自己（false 时，施法者也会被检测到，适用于治疗光环、群体Buff等）

func _get_targets(caster: Node3D, context: Dictionary = {}) -> Array[Node]:
	if not is_instance_valid(caster):
		return []
	
	# 确定检测位置（根据配置项决定，允许 context 覆盖）
	var position_source = context.get("detection_position_source", detection_position_source)
	var detection_position: Vector3 = Vector3.ZERO
	
	match position_source:
		DetectionPositionSource.CASTER_POSITION:
			# 使用施法者位置（适用于献祭等范围技能）
			if caster is Node3D:
				detection_position = caster.global_position
			else:
				push_warning("AreaHitDetector: Caster is not Node3D, cannot use CASTER_POSITION")
				detection_position = Vector3.ZERO
		
		DetectionPositionSource.TARGET_POSITION:
			# 使用目标位置（鼠标位置，适用于地面目标技能）
			if context.has("target_position") and context["target_position"] is Vector3:
				detection_position = context["target_position"] as Vector3
			else:
				push_warning("AreaHitDetector: TARGET_POSITION source selected but target_position not found in context")
				# 回退到施法者位置
				if caster is Node3D:
					detection_position = caster.global_position
				else:
					detection_position = Vector3.ZERO
		
		DetectionPositionSource.HIT_POSITION:
			# 使用命中位置（投射物爆炸位置）
			if context.has("hit_position") and context["hit_position"] is Vector3:
				detection_position = context["hit_position"] as Vector3
			else:
				push_warning("AreaHitDetector: HIT_POSITION source selected but hit_position not found in context")
				# 回退到施法者位置
				if caster is Node3D:
					detection_position = caster.global_position
				else:
					detection_position = Vector3.ZERO
		
		DetectionPositionSource.DETECTION_POSITION:
			# 使用显式指定的检测位置（通过 context["detection_position"] 传递）
			if context.has("detection_position") and context["detection_position"] is Vector3:
				detection_position = context["detection_position"] as Vector3
			else:
				push_warning("AreaHitDetector: DETECTION_POSITION source selected but detection_position not found in context")
				# 回退到施法者位置
				if caster is Node3D:
					detection_position = caster.global_position
				else:
					detection_position = Vector3.ZERO
		
		_:
			push_warning("AreaHitDetector: Unknown detection_position_source: %d" % position_source)
			# 回退到施法者位置
			if caster is Node3D:
				detection_position = caster.global_position
			else:
				detection_position = Vector3.ZERO
	
	# 调试信息
	if detection_position == Vector3.ZERO:
		print("AreaHitDetector: WARNING - Using Vector3.ZERO as detection position! Source: %d" % position_source)
	else:
		print("AreaHitDetector: Using detection position: %s (Source: %d)" % [detection_position, position_source])
	
	# 确定检测半径（允许上下文覆盖）
	var radius = context.get("detection_radius", detection_radius)
	
	# 确定碰撞遮罩（允许上下文覆盖）
	var mask = context.get("collision_mask", collision_mask)
	
	# 使用PhysicsServer3D进行同步查询（避免异步问题）
	var space_state = caster.get_world_3d().direct_space_state
	
	# 创建查询参数
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 设置形状
	var shape: Shape3D
	if detection_shape:
		shape = detection_shape
		shape.radius = radius
	else:
		shape = SphereShape3D.new()
		shape.radius = radius
	
	query.shape = shape
	query.transform = Transform3D(Basis(), detection_position)
	query.collision_mask = mask
	query.collide_with_bodies = true  # 检测刚体（CharacterBody3D, RigidBody3D等）
	query.collide_with_areas = true   # 检测区域（Area3D，如Hurtbox）
	
	# 是否排除施法者（允许上下文覆盖）
	var should_exclude_caster = context.get("exclude_caster", exclude_caster)
	if should_exclude_caster:
		query.exclude = [caster]  # 排除施法者自己
	else:
		query.exclude = []  # 不排除，允许检测到施法者
	
	# 执行查询
	var results = space_state.intersect_shape(query, max_results)
	
	# 调试信息
	if results.is_empty():
		print("AreaHitDetector: No results found. Position: %s, Radius: %.2f, Mask: %d, CollideWithBodies: %s, CollideWithAreas: %s" % [
			detection_position, radius, mask, query.collide_with_bodies, query.collide_with_areas
		])
	else:
		print("AreaHitDetector: Found %d results" % results.size())
	
	# 转换结果为实体列表
	var valid_targets: Array[Node] = []
	var processed_entities = {}  # 避免重复
	
	for result in results:
		var collider = result.get("collider")
		if not is_instance_valid(collider):
			continue
		
		# 调试信息：打印检测到的碰撞体
		print("AreaHitDetector: Found collider: %s (type: %s)" % [collider.name, collider.get_class()])
		
		# 通过工具函数转换为实体根节点
		var entity = collider.get_parent()
		if not is_instance_valid(entity):
			print("AreaHitDetector: Failed to get entity from collider: %s" % collider.name)
			continue
		
		# 避免重复添加同一实体
		var entity_id = entity.get_instance_id()
		if processed_entities.has(entity_id):
			continue
		
		processed_entities[entity_id] = true
		valid_targets.append(entity)
		print("AreaHitDetector: Added target: %s" % entity.name)
	
	return valid_targets

func _get_description() -> String:
	var shape_name = "Sphere" if not detection_shape else detection_shape.get_class()
	var source_names = {
		DetectionPositionSource.CASTER_POSITION: "Caster",
		DetectionPositionSource.TARGET_POSITION: "Target",
		DetectionPositionSource.HIT_POSITION: "Hit",
		DetectionPositionSource.DETECTION_POSITION: "Explicit"
	}
	var source_name = source_names.get(detection_position_source, "Unknown")
	return "Area Detector: %s (Radius %.1f, Mask %d, Position: %s)" % [shape_name, detection_radius, collision_mask, source_name]
