extends GameplayEffect
class_name GE_PhysicsMotion

## 物理位移效果（持续效果）
## 使用 move_and_collide 实现平滑物理移动，支持滑墙
## 适用于：冲锋 (Charge)、闪避 (Dash)、击退 (Knockback)、跳斩位移

@export_group("Motion Config")
## 位移总距离（米）
@export var distance: float = 6.0
## 位移总时间（秒）
@export var duration: float = 0.3
## 速度曲线（X轴为时间进度0-1，Y轴为距离权重0-1）
## 如果为 null，则线性移动
@export var speed_curve: Curve = null
## 是否忽略重力
## 地面冲锋建议 false（贴合斜坡），空中冲刺建议 true
@export var ignore_gravity: bool = false

## 位移方向类型
enum DirectionType {
	FORWARD,      ## 向面朝方向
	INPUT,        ## 键盘输入方向
	MOUSE,        ## 鼠标方向（需要 context 中有 mouse_direction）
	CUSTOM        ## 自定义方向（需要 context 中有 direction）
}
@export var direction_type: DirectionType = DirectionType.INPUT

## 缓动类型（当 speed_curve 为 null 时使用）
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
## 过渡类型（当 speed_curve 为 null 时使用）
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

# 存储每个目标节点对应的 Tween 和组件引用
# Key: 目标节点的 RID (String), Value: Dictionary {tween: Tween, ability_comp: GameplayAbilityComponent, ability_id: StringName, state: Dictionary}
var _active_instances: Dictionary = {}

func _init() -> void:
	# 这是一个持续效果，技能需要等待它完成
	blocks_ability_completion = true

func _is_asynchronous() -> bool:
	return true

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	# 1. 守卫：必须是物理实体
	var body = target as CharacterBody3D
	if not body:
		push_warning("GE_PhysicsMotion: Target is not CharacterBody3D")
		# 如果是阻塞效果但目标无效，需要注销阻塞任务
		var ability_comp = _find_ability_component(instigator)
		if is_instance_valid(ability_comp):
			var ability_id = ability_comp.get_current_casting_ability_id()
			if not ability_id.is_empty():
				ability_comp.unregister_blocking_task(ability_id)
		return
	
	var target_rid = str(body.get_rid())
	
	# 2. 获取 AbilityComponent 和当前技能ID（用于完成时注销）
	var ability_comp = _find_ability_component(instigator)
	var ability_id: StringName = &""
	if is_instance_valid(ability_comp):
		ability_id = ability_comp.get_current_casting_ability_id()
	
	# 3. 如果已有正在运行的实例，先停止它
	if _active_instances.has(target_rid):
		var old_instance = _active_instances[target_rid]
		if is_instance_valid(old_instance.get("tween")):
			old_instance.tween.kill()
		# 注销旧的阻塞任务
		var old_comp = old_instance.get("ability_comp") as GameplayAbilityComponent
		var old_id = old_instance.get("ability_id") as StringName
		if is_instance_valid(old_comp) and not old_id.is_empty():
			old_comp.unregister_blocking_task(old_id)
		_active_instances.erase(target_rid)
	
	# 4. 计算方向（这是冲锋瞬间锁定的，过程不可变）
	var move_dir = _resolve_direction(body, context)
	if move_dir == Vector3.ZERO:
		push_warning("GE_PhysicsMotion: Cannot resolve direction")
		# 注销阻塞任务
		if is_instance_valid(ability_comp) and not ability_id.is_empty():
			ability_comp.unregister_blocking_task(ability_id)
		return
	
	# 5. 准备 Tween（必须在 Physics Process 运行以保证碰撞稳定）
	var tween = body.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_LINEAR)  # 线性时间，曲线逻辑我们在回调里自己算
	
	# 6. 状态闭包：用于在回调中记录上一帧走到哪了
	var state = {
		"accumulated_dist": 0.0,
		"body": body,
		"direction": move_dir
	}
	
	# 7. 存储实例信息
	_active_instances[target_rid] = {
		"tween": tween,
		"ability_comp": ability_comp,
		"ability_id": ability_id,
		"state": state,
		"target": body
	}
	
	# 8. 启动驱动器：0.0 -> 1.0
	tween.tween_method(
		_physics_process_step.bind(state),
		0.0, 1.0, duration
	)
	
	# 9. 完成回调
	tween.finished.connect(func():
		_on_motion_finished(target_rid)
	)

## 物理步进回调（每物理帧调用）
## [param] progress: float 进度 0.0-1.0
## [param] state: Dictionary 状态字典
func _physics_process_step(progress: float, state: Dictionary) -> void:
	var body = state.get("body") as CharacterBody3D
	var dir = state.get("direction") as Vector3
	
	if not is_instance_valid(body) or dir == Vector3.ZERO:
		return
	
	# A. 采样曲线：获取当前进度对应的"距离百分比"
	var dist_percent: float
	if speed_curve:
		dist_percent = speed_curve.sample(progress)
	else:
		# 如果没有曲线，使用线性插值（简单实现）
		# 如果需要更复杂的缓动，建议使用 Curve 资源
		dist_percent = progress
	
	# B. 计算本帧目标位置（Total Target）
	var target_accum_dist = distance * dist_percent
	
	# C. 计算本帧增量（Delta Step）= 目标总量 - 已走总量
	var step_dist = target_accum_dist - state["accumulated_dist"]
	
	# 更新记录，供下一帧使用
	state["accumulated_dist"] = target_accum_dist
	
	# 如果这一帧位移极小，忽略（避免浮点抖动）
	if step_dist <= 0.001:
		return
	
	# D. 构建位移向量
	var velocity_vector = dir * step_dist
	
	# E. 简易重力处理（贴地逻辑）
	if not ignore_gravity and not body.is_on_floor():
		# 给一个固定的下压力，确保贴合斜坡
		velocity_vector.y -= 0.5
	
	# F. 【关键】物理执行与滑墙逻辑
	var collision = body.move_and_collide(velocity_vector)
	
	if collision:
		# 撞墙了！计算滑动向量
		var normal = collision.get_normal()
		var remainder = collision.get_remainder()  # 撞击后剩余没走完的距离
		
		# 沿着墙面法线滑动
		var slide_vector = remainder.slide(normal)
		
		# 如果滑动分量有效，再次移动
		if slide_vector.length() > 0.001:
			body.move_and_collide(slide_vector)

## 方向解析
## [param] body: Node3D 目标节点
## [param] context: Dictionary 上下文信息
## [return] Vector3 方向向量（已归一化）
func _resolve_direction(body: Node3D, context: Dictionary) -> Vector3:
	var dir: Vector3 = Vector3.ZERO
	
	match direction_type:
		DirectionType.FORWARD:
			# 向面朝方向
			var facing_angle: float = 0.0
			if context.has("facing_angle"):
				facing_angle = context["facing_angle"]
			elif context.has("facing_direction"):
				var facing_dir = context["facing_direction"] as Vector3
				if facing_dir != Vector3.ZERO:
					facing_angle = atan2(facing_dir.x, facing_dir.z)
			var rotation_basis = Basis.from_euler(Vector3(0, facing_angle, 0))
			dir = rotation_basis.z
		
		DirectionType.INPUT:
			# 获取输入向量
			var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if input.length() > 0.1:
				# 转换到相机空间
				var cam = body.get_viewport().get_camera_3d()
				if is_instance_valid(cam):
					var cam_basis = cam.global_transform.basis
					dir = (cam_basis.x * input.x + cam_basis.z * input.y).normalized()
				else:
					# 如果没有相机，使用世界空间
					dir = Vector3(input.x, 0, input.y).normalized()
			else:
				# 如果没有输入，使用面朝方向
				var visuals = body.get_node_or_null("Visuals")
				if is_instance_valid(visuals) and visuals is Node3D:
					var facing_angle = (visuals as Node3D).rotation.y
					var rotation_basis = Basis.from_euler(Vector3(0, facing_angle, 0))
					dir = rotation_basis.z
				else:
					var forward = body.global_transform.basis.z
					dir = Vector3(forward.x, 0, forward.z).normalized()
		
		DirectionType.MOUSE:
			# 向鼠标方向
			if context.has("mouse_direction"):
				var mouse_dir = context["mouse_direction"]
				if mouse_dir is Vector3:
					dir = mouse_dir.normalized()
					# 确保方向在 XZ 平面上（忽略 Y 轴）
					dir.y = 0.0
					dir = dir.normalized()
			else:
				# 如果没有鼠标方向，回退到面朝方向
				push_warning("GE_PhysicsMotion: MOUSE_DIR mode requires 'mouse_direction' in context, falling back to FORWARD")
				var visuals = body.get_node_or_null("Visuals")
				if is_instance_valid(visuals) and visuals is Node3D:
					var facing_angle = (visuals as Node3D).rotation.y
					var rotation_basis = Basis.from_euler(Vector3(0, facing_angle, 0))
					dir = rotation_basis.z
				else:
					var forward = body.global_transform.basis.z
					dir = Vector3(forward.x, 0, forward.z).normalized()
		
		DirectionType.CUSTOM:
			# 自定义方向
			if context.has("direction"):
				var custom_dir = context["direction"]
				if custom_dir is Vector3:
					dir = custom_dir.normalized()
					# 确保方向在 XZ 平面上
					dir.y = 0.0
					dir = dir.normalized()
			else:
				push_warning("GE_PhysicsMotion: CUSTOM mode requires 'direction' in context")
	
	# 强制水平移动（忽略 Y 轴）
	dir.y = 0.0
	return dir.normalized()

## 位移完成回调
## [param] instance_id: String 实例ID
func _on_motion_finished(instance_id: String) -> void:
	if not _active_instances.has(instance_id):
		return
	
	var instance = _active_instances[instance_id]
	_active_instances.erase(instance_id)
	
	# 注销阻塞任务，通知技能系统
	var ability_comp = instance.get("ability_comp") as GameplayAbilityComponent
	var ability_id = instance.get("ability_id") as StringName
	if is_instance_valid(ability_comp) and not ability_id.is_empty():
		ability_comp.unregister_blocking_task(ability_id)

func _remove(target: Node, instigator: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	
	var target_rid = str((target as Node3D).get_rid())
	
	if _active_instances.has(target_rid):
		var instance = _active_instances[target_rid]
		
		# 停止 Tween
		var tween = instance.get("tween")
		if is_instance_valid(tween):
			tween.kill()
		
		# 注销阻塞任务（被取消时也需要注销，避免技能卡死）
		var ability_comp = instance.get("ability_comp") as GameplayAbilityComponent
		var ability_id = instance.get("ability_id") as StringName
		if is_instance_valid(ability_comp) and not ability_id.is_empty():
			ability_comp.unregister_blocking_task(ability_id)
		
		# 清理实例
		_active_instances.erase(target_rid)

func _get_description() -> String:
	var dir_name = DirectionType.keys()[direction_type]
	var curve_info = "（使用曲线）" if speed_curve else "（线性）"
	return "物理位移: 向 %s 方向移动 %.1f 米 (%.2f秒)%s" % [dir_name, distance, duration, curve_info]

