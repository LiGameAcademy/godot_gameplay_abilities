extends GameplayEffect
class_name GE_Motion

## 位移效果（使用 Tween 实现平滑移动）
## 将目标平滑移动到指定位置，或向指定方向位移

@export_group("Motion Settings")
## 位移距离（米）
@export var distance: float = 5.0
## 位移持续时间（秒）
@export var duration: float = 0.5
## 位移方向类型
enum MotionDirection {
	FORWARD,      ## 向面朝方向
	BACKWARD,     ## 向后
	LEFT,         ## 向左
	RIGHT,        ## 向右
	TARGET_POS,   ## 移动到目标位置（需要 context 中有 target_position）
	CUSTOM        ## 自定义方向（需要 context 中有 direction）
}
@export var direction_type: MotionDirection = MotionDirection.FORWARD
## 缓动类型
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
## 过渡类型
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
## 是否忽略碰撞（如果为 true，会穿透障碍物）
@export var ignore_collision: bool = false
## 是否强制位移（如果为 true，会覆盖角色的物理移动）
@export var force_motion: bool = true

# 存储每个目标节点对应的 Tween 引用
# 使用静态字典来管理，key 是目标节点的 RID，value 是 Tween
static var _active_tweens: Dictionary = {}

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		push_warning("GE_Motion: Target is not a valid Node3D")
		return
	
	var target_3d = target as Node3D
	var target_rid = target_3d.get_rid()
	
	# 如果已有正在运行的 Tween，先停止它
	if _active_tweens.has(target_rid):
		var old_tween = _active_tweens[target_rid]
		if is_instance_valid(old_tween):
			old_tween.kill()
		_active_tweens.erase(target_rid)
	
	var direction: Vector3 = Vector3.ZERO
	var target_position: Vector3
	
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
	
	# 根据方向类型计算位移方向和目标位置
	match direction_type:
		MotionDirection.FORWARD:
			# 向面朝方向
			direction = -rotation_basis.z
			target_position = target_3d.global_position + direction * distance
		MotionDirection.BACKWARD:
			# 向后
			direction = rotation_basis.z
			target_position = target_3d.global_position + direction * distance
		MotionDirection.LEFT:
			# 向左
			direction = -rotation_basis.x
			target_position = target_3d.global_position + direction * distance
		MotionDirection.RIGHT:
			# 向右
			direction = rotation_basis.x
			target_position = target_3d.global_position + direction * distance
		MotionDirection.TARGET_POS:
			# 移动到目标位置
			if context.has("target_position"):
				var target_pos = context["target_position"]
				if target_pos is Vector3:
					target_position = target_pos
					direction = (target_position - target_3d.global_position).normalized()
				else:
					push_warning("GE_Motion: TARGET_POS mode requires 'target_position' to be Vector3")
					return
			else:
				push_warning("GE_Motion: TARGET_POS mode requires 'target_position' in context")
				return
		MotionDirection.CUSTOM:
			# 自定义方向
			if context.has("direction"):
				var custom_dir = context["direction"]
				if custom_dir is Vector3:
					direction = custom_dir.normalized()
					target_position = target_3d.global_position + direction * distance
				else:
					push_warning("GE_Motion: CUSTOM mode requires 'direction' to be Vector3")
					return
			else:
				push_warning("GE_Motion: CUSTOM mode requires 'direction' in context")
				return
	
	# 碰撞检测（如果不忽略碰撞）
	if not ignore_collision:
		var space_state = target_3d.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			target_3d.global_position,
			target_position
		)
		query.exclude = [target_3d.get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result:
			# 如果碰撞，移动到碰撞点前一点
			var hit_position = result.position
			var safe_distance = 0.5  # 安全距离
			target_position = hit_position - direction * safe_distance
	
	# 如果是 CharacterBody3D 且需要强制位移，临时禁用物理处理
	var was_physics_enabled: bool = true
	if force_motion and target_3d is CharacterBody3D:
		var char_body = target_3d as CharacterBody3D
		was_physics_enabled = char_body.is_physics_processing()
		if was_physics_enabled:
			char_body.set_physics_process(false)
	
	# 创建 Tween 并开始移动
	var tween = target_3d.create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(transition_type)
	
	# 存储 Tween 引用
	_active_tweens[target_rid] = tween
	
	# 执行位移动画
	tween.tween_property(target_3d, "global_position", target_position, duration)
	
	# 动画完成后的回调
	tween.tween_callback(func():
		# 恢复物理处理（如果需要）
		if force_motion and target_3d is CharacterBody3D and was_physics_enabled:
			var char_body = target_3d as CharacterBody3D
			char_body.set_physics_process(true)
		
		# 清理 Tween 引用
		if _active_tweens.has(target_rid):
			_active_tweens.erase(target_rid)
	)

func _remove(target: Node, instigator: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	
	var target_3d = target as Node3D
	var target_rid = target_3d.get_rid()
	
	# 停止正在运行的 Tween
	if _active_tweens.has(target_rid):
		var tween = _active_tweens[target_rid]
		if is_instance_valid(tween):
			tween.kill()
		_active_tweens.erase(target_rid)
	
	# 恢复物理处理（如果需要）
	if force_motion and target_3d is CharacterBody3D:
		var char_body = target_3d as CharacterBody3D
		char_body.set_physics_process(true)

func _get_description() -> String:
	var dir_name = MotionDirection.keys()[direction_type]
	return "位移: 向 %s 方向平滑移动 %.1f 米 (%.2f秒)" % [dir_name, distance, duration]

