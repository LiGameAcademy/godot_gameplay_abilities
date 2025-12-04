extends GameplayEffect
class_name GE_Teleport

## 传送/位移效果
## 将目标传送到指定位置，或向指定方向位移

@export_group("Teleport Settings")
## 位移距离（米）
@export var distance: float = 5.0
## 位移方向类型
enum TeleportDirection {
	FORWARD,      ## 向面朝方向
	BACKWARD,     ## 向后
	LEFT,         ## 向左
	RIGHT,        ## 向右
	TARGET_POS,   ## 传送到目标位置（需要 context 中有 target_position）
	CUSTOM        ## 自定义方向（需要 context 中有 direction）
}
@export var direction_type: TeleportDirection = TeleportDirection.FORWARD
## 是否忽略碰撞（如果为 true，会穿透障碍物）
@export var ignore_collision: bool = false

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		push_warning("GE_Teleport: Target is not a valid Node3D")
		return
	
	var target_3d = target as Node3D
	var direction: Vector3 = Vector3.ZERO
	
	# 从上下文获取面朝方向（优先使用传入的值）
	var facing_angle: float = 0.0
	if context.has("facing_angle"):
		# 直接使用传入的角度（弧度）
		facing_angle = context["facing_angle"]
	elif context.has("facing_direction"):
		# 从方向向量计算角度
		var facing_dir = context["facing_direction"] as Vector3
		if facing_dir != Vector3.ZERO:
			facing_angle = atan2(facing_dir.x, facing_dir.z)
	else:
		# 如果没有传入，尝试从目标节点的 transform 计算
		# 优先从 Visuals 子节点获取（玩家角色通常使用这种方式）
		var visuals = target_3d.get_node_or_null("Visuals")
		if is_instance_valid(visuals) and visuals is Node3D:
			facing_angle = (visuals as Node3D).rotation.y
		else:
			# 从目标节点自身获取
			facing_angle = target_3d.rotation.y
			if facing_angle == 0.0:
				# 如果 rotation.y 为 0，从 transform 计算
				var forward = -target_3d.global_transform.basis.z
				facing_angle = atan2(forward.x, forward.z)
	
	# 构建旋转矩阵（Y轴旋转）
	var rotation_basis = Basis.from_euler(Vector3(0, facing_angle, 0))
	
	# 根据方向类型计算位移方向
	match direction_type:
		TeleportDirection.FORWARD:
			# 向面朝方向
			direction = -rotation_basis.z
		TeleportDirection.BACKWARD:
			# 向后
			direction = rotation_basis.z
		TeleportDirection.LEFT:
			# 向左
			direction = -rotation_basis.x
		TeleportDirection.RIGHT:
			# 向右
			direction = rotation_basis.x
		TeleportDirection.TARGET_POS:
			# 传送到目标位置
			if context.has("target_position"):
				var target_pos = context["target_position"]
				if target_pos is Vector3:
					target_3d.global_position = target_pos
					return
			else:
				push_warning("GE_Teleport: TARGET_POS mode requires 'target_position' in context")
				return
		TeleportDirection.CUSTOM:
			# 自定义方向
			if context.has("direction"):
				var custom_dir = context["direction"]
				if custom_dir is Vector3:
					direction = custom_dir.normalized()
			else:
				push_warning("GE_Teleport: CUSTOM mode requires 'direction' in context")
				return
	
	# 计算目标位置
	var target_position = target_3d.global_position + direction * distance
	
	# 如果忽略碰撞，直接传送
	if ignore_collision:
		target_3d.global_position = target_position
	else:
		# 使用射线检测，避免传送到墙内
		var space_state = target_3d.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			target_3d.global_position,
			target_position
		)
		query.exclude = [target_3d.get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result:
			# 如果碰撞，传送到碰撞点前一点
			var hit_position = result.position
			var safe_distance = 0.5  # 安全距离
			var safe_position = hit_position - direction * safe_distance
			target_3d.global_position = safe_position
		else:
			# 没有碰撞，直接传送
			target_3d.global_position = target_position

func _get_description() -> String:
	var dir_name = TeleportDirection.keys()[direction_type]
	return "传送: 向 %s 方向位移 %.1f 米" % [dir_name, distance]
