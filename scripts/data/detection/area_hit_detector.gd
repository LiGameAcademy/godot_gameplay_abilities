extends HitDetectorBase
class_name AreaHitDetector

## 区域命中检测器（物理检测）
## 适用于：AOE技能、非指向性技能、地雷、暴风雪
## 特点：精确、支持复杂形状、依赖物理引擎

@export_group("Area Settings")
@export var detection_radius: float = 3.0  ## 检测半径
@export var detection_shape: Shape3D = null  ## 自定义检测形状（如果为null，使用球形）
@export var collision_mask: int = 1  ## 碰撞遮罩

@export_group("Query Settings")
@export var max_results: int = 32  ## 最大检测结果数量
@export var use_world_position: bool = true  ## 是否使用世界坐标

func _get_targets(caster: Node3D, context: Dictionary = {}) -> Array[Node]:
	if not is_instance_valid(caster):
		return []
	
	# 确定检测位置
	var detection_position: Vector3
	if context.has("target_position"):
		detection_position = context["target_position"]
	else:
		detection_position = caster.global_position
	
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
	else:
		shape = SphereShape3D.new()
		shape.radius = radius
	
	query.shape = shape
	query.transform = Transform3D(Basis(), detection_position)
	query.collision_mask = mask
	query.exclude = [caster]  # 排除施法者自己
	
	# 执行查询
	var results = space_state.intersect_shape(query, max_results)
	
	# 转换结果为实体列表
	var valid_targets: Array[Node] = []
	var processed_entities = {}  # 避免重复
	
	for result in results:
		var collider = result.get("collider")
		if not is_instance_valid(collider):
			continue
		
		# 通过工具函数转换为实体根节点
		var entity = CombatUtils.get_entity_from_collider(collider)
		if not is_instance_valid(entity):
			continue
		
		# 避免重复添加同一实体
		var entity_id = entity.get_instance_id()
		if processed_entities.has(entity_id):
			continue
		
		processed_entities[entity_id] = true
		valid_targets.append(entity)
	
	return valid_targets

func _get_description() -> String:
	var shape_name = "Sphere" if not detection_shape else detection_shape.get_class()
	return "Area Detector: %s (Radius %.1f, Mask %d)" % [shape_name, detection_radius, collision_mask]
