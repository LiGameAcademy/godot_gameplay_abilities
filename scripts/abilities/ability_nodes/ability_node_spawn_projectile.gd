extends BTAction
class_name AbilityNodeSpawnProjectile

## 生成投射物节点
## 职责：在行为树中生成投射物，支持多重施法、散射角度等

@export_group("Projectile Config")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点）
@export var muzzle_attachment_point: StringName = &"body"

func _tick(instance: BTInstance, delta: float) -> int:
	var context : AbilityContext = instance.blackboard.get_var("context")
	var instigator = context.instigator
	
	if not is_instance_valid(instigator):
		push_warning("AbilityNodeSpawnProjectile: Instigator is not valid!")
		return Status.FAILURE
	
	# 检查投射物数据
	if not is_instance_valid(projectile_data):
		push_warning("AbilityNodeSpawnProjectile: projectile_data is not set!")
		return Status.FAILURE
	
	# 检查投射物场景
	if not is_instance_valid(projectile_data.projectile_scene):
		push_warning("AbilityNodeSpawnProjectile: projectile_scene is not set in projectile_data!")
		return Status.FAILURE
	
	# 获取目标（用于追踪）
	var raw_targets = instance.blackboard.get_var("targets")
	var target_for_homing: Node3D = null
	if raw_targets is Node3D:
		target_for_homing = raw_targets as Node3D
	elif raw_targets is Array and not raw_targets.is_empty():
		var first_target = raw_targets[0]
		if first_target is Node3D:
			target_for_homing = first_target as Node3D
	
	# 确定发射基准信息
	var spawn_transform = _get_muzzle_transform(instigator, context.to_dict())
	
	# 计算实际发射数量（支持 Modifier 修改）
	var actual_projectile_count = projectile_count
	actual_projectile_count += context.extra_projectiles
	actual_projectile_count = max(1, actual_projectile_count)
	
	# 计算散射角度分布
	var effective_spread_angle = spread_angle
	if actual_projectile_count > 1 and spread_angle <= 0.0:
		effective_spread_angle = (actual_projectile_count - 1) * 15.0
	
	# 存储生成的投射物列表到黑板（用于事件监听）
	var spawned_projectiles: Array[ProjectileBase] = []
	
	# 循环生成投射物
	for i in range(actual_projectile_count):
		var angle_offset: float = 0.0
		if actual_projectile_count > 1 and effective_spread_angle > 0.0:
			var half_spread = effective_spread_angle / 2.0
			if actual_projectile_count > 1:
				var t = float(i) / float(actual_projectile_count - 1)
				angle_offset = lerp(-half_spread, half_spread, t)
		
		var projectile = _spawn_projectile(
			instigator,
			spawn_transform,
			projectile_data.duplicate(),
			target_for_homing,
			context.to_dict(),
			angle_offset
		)
		
		if is_instance_valid(projectile):
			spawned_projectiles.append(projectile)
			# 连接信号，将撞击信息写入黑板
			_connect_projectile_signals(projectile, instance, context.to_dict())
	
	# 将投射物列表存储到黑板（用于后续的事件监听节点）
	instance.blackboard.set_var("spawned_projectiles", spawned_projectiles)
	
	return Status.SUCCESS

## 生成投射物
func _spawn_projectile(
		instigator: Node,
		spawn_transform: Transform3D,
		data: ProjectileData,
		target_node: Node3D,
		context: Dictionary = {},
		angle_offset: float = 0.0) -> ProjectileBase:
	if not is_instance_valid(data) or not is_instance_valid(data.projectile_scene):
		push_error("AbilityNodeSpawnProjectile: projectile_scene is not set in projectile_data")
		return null
	
	var projectile = data.projectile_scene.instantiate()
	if not projectile is ProjectileBase:
		push_error("AbilityNodeSpawnProjectile: projectile_scene must be a ProjectileBase")
		projectile.queue_free()
		return null
	
	var projectile_base = projectile as ProjectileBase
	
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("AbilityNodeSpawnProjectile: Cannot find current scene root")
		projectile_base.queue_free()
		return null
	
	level_root.add_child(projectile_base)
	
	projectile_base.global_transform = spawn_transform
	var forward_offset = -spawn_transform.basis.z * 0.5
	var up_offset = Vector3.UP * 0.5
	projectile_base.global_position += forward_offset + up_offset
	
	if abs(angle_offset) > 0.001:
		var angle_rad = deg_to_rad(angle_offset)
		projectile_base.rotate_y(angle_rad)
	elif spread_angle > 0.0:
		var random_angle = deg_to_rad(randf_range(-spread_angle / 2.0, spread_angle / 2.0))
		projectile_base.rotate_y(random_angle)
	
	projectile_base.instigator = instigator
	projectile_base.target_reference = target_node
	data.apply_to_projectile(projectile_base)
	
	return projectile_base

## 连接投射物信号
## 当投射物撞击时，将撞击信息写入黑板变量
func _connect_projectile_signals(
		projectile: ProjectileBase,
		instance: BTInstance,
		context: Dictionary) -> void:
	if not is_instance_valid(projectile):
		return
	
	# 连接撞击信号，将撞击信息写入黑板
	# 这样其他节点（如 BTWaitSignal）可以通过监听黑板变量来响应撞击事件
	projectile.impact_triggered.connect(_on_projectile_impact.bind(instance))
	
	# 可选：连接超时信号
	projectile.timeout_triggered.connect(_on_projectile_timeout.bind(instance))

## 投射物撞击回调
## 将撞击信息写入黑板，触发观察者节点
func _on_projectile_impact(
		hit_position: Vector3,
		direct_hit_target: Node,
		impact_context: Dictionary,
		instance: BTInstance) -> void:
	# 将撞击信息存储到黑板
	# 使用两个变量：
	# 1. projectile_impact_triggered (bool) - 用于 BTWaitSignal 监听
	# 2. projectile_impact (Dictionary) - 存储详细的撞击信息
	instance.blackboard.set_var("projectile_impact", {
		"hit_position": hit_position,
		"direct_hit_target": direct_hit_target,
		"impact_context": impact_context
	})
	# 设置触发标志，触发观察者节点
	instance.blackboard.set_var("projectile_impact_triggered", true)

## 投射物超时回调
func _on_projectile_timeout(
		position: Vector3,
		timeout_context: Dictionary,
		instance: BTInstance) -> void:
	# 超时处理（如果需要）
	pass

## 获取枪口变换
func _get_muzzle_transform(instigator: Node, context: Dictionary) -> Transform3D:
	# 优先使用 context 中的 muzzle_transform
	if context.has("muzzle_transform") and context["muzzle_transform"] is Transform3D:
		return context["muzzle_transform"] as Transform3D
	
	# 回退：使用 instigator 的位置和面朝方向
	var facing_direction = _get_facing_direction(instigator, context)
	var spawn_position: Vector3
	
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		if instigator_3d.has_node("Visuals"):
			var visuals = instigator_3d.get_node("Visuals")
			if visuals is Node3D:
				spawn_position = (visuals as Node3D).global_position
				spawn_position.y += 0.5
			else:
				spawn_position = instigator_3d.global_position
				spawn_position.y += 0.5
		else:
			spawn_position = instigator_3d.global_position
			spawn_position.y += 0.5
	else:
		spawn_position = Vector3.ZERO
	
	return _build_transform_from_direction(spawn_position, facing_direction)

## 获取面朝方向
func _get_facing_direction(instigator: Node, context: Dictionary) -> Vector3:
	if context.has("facing_direction") and context["facing_direction"] is Vector3:
		return (context["facing_direction"] as Vector3).normalized()
	
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		if instigator_3d.has_node("Visuals"):
			var visuals = instigator_3d.get_node("Visuals")
			if visuals is Node3D:
				var visuals_3d = visuals as Node3D
				var angle = visuals_3d.rotation.y
				var direction = Vector3(-sin(angle), 0.0, -cos(angle))
				if direction.length_squared() > 0.01:
					return direction.normalized()
		return -instigator_3d.global_transform.basis.z
	
	return Vector3.FORWARD

## 从位置和方向构建变换
func _build_transform_from_direction(position: Vector3, direction: Vector3) -> Transform3D:
	var dir = direction.normalized()
	var up = Vector3.UP
	var right = dir.cross(up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	up = right.cross(dir).normalized()
	var basis = Basis(right, up, -dir)
	return Transform3D(basis, position)
