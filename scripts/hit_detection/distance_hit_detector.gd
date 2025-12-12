extends HitDetectorBase
class_name DistanceHitDetector

## 距离命中检测器（数学检测）
## 适用于：普攻、指向性技能、远程攻击
## 特点：极快、即时、将单位视为质点

@export_group("Distance Settings")
@export var max_range: float = 5.0  ## 最大检测距离
@export var include_radius: bool = true  ## 是否考虑目标体积半径
@export var default_target_radius: float = 0.5  ## 默认目标半径（如果目标没有get_radius方法）

@export_group("Filter Settings")
@export var require_los: bool = false  ## 是否需要视线（Line of Sight）
@export var los_layer_mask: int = 1  ## 视线检测的碰撞遮罩

func _get_targets(caster: Node3D, context: Dictionary) -> Array[Node]:
	if not is_instance_valid(caster):
		return []
	
	# 从上下文中获取锁定目标
	var target_unit = context.get("target_unit")
	if not is_instance_valid(target_unit):
		return []
	
	# 确保目标也是Node3D
	if not target_unit is Node3D:
		push_warning("DistanceHitDetector: Target is not a Node3D")
		return []
	
	var target_3d = target_unit as Node3D
	
	# 计算距离
	var caster_pos = caster.global_position
	var target_pos = target_3d.global_position
	var distance = caster_pos.distance_to(target_pos)
	
	# 如果考虑目标体积半径，进行修正
	if include_radius:
		var target_radius = default_target_radius
		if target_unit.has_method("get_radius"):
			target_radius = target_unit.get_radius()
		distance -= target_radius
	
	# 检查是否在范围内
	if distance > max_range:
		return []
	
	# 检查视线（如果需要）
	if require_los:
		if not _check_line_of_sight(caster, target_3d):
			return []
	
	# 转换为实体根节点（通过工具函数）
	var entity = CombatUtils.get_entity_from_node(target_unit)
	if is_instance_valid(entity):
		return [entity]
	
	return []

## 检查视线
func _check_line_of_sight(caster: Node3D, target: Node3D) -> bool:
	var space_state = caster.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(caster.global_position, target.global_position)
	query.collision_mask = los_layer_mask
	query.exclude = [caster]  # 排除施法者自己
	
	var result = space_state.intersect_ray(query)
	
	# 如果射线被阻挡，返回false
	if result:
		# 检查是否命中目标
		return result.get("collider") == target
	
	return true

func _get_description() -> String:
	var desc = "Distance Detector: Range %.1f" % max_range
	if include_radius:
		desc += " (with radius)"
	if require_los:
		desc += " (requires LOS)"
	return desc
