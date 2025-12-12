extends GameplayEffect
class_name GE_PhysicsMotion

## 物理位移效果（持续效果，已弃用）
## [已弃用] 建议使用 GE_SingleFrameMotion + Status 周期性效果替代
## 
## 新架构推荐：
## 1. 创建 Status，配置 period（如 0.05 秒）
## 2. Status 的 effects 包含 GE_SingleFrameMotion
## 3. Status 会周期性触发位移效果，实现平滑的持续位移
## 
## 优势：
## - Effect 只负责单次动作，更简单
## - Status 统一管理持续状态，更符合三层架构
## - 更灵活：可以通过 Status 的 duration、period 等配置控制
## 
## 保留此效果以保持向后兼容，但新代码应使用新架构

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

# 运行时状态（本效果实例内，不再跨实例共享）
var _tween: Tween = null
var _state: Dictionary = {}
var _target_body: CharacterBody3D = null
var _instigator_ref: Node = null

func _init() -> void:
	# 这是一个持续效果，技能需要等待它完成
	# 注意：现在所有效果都会 emit 完成信号，不再需要 blocks_ability_completion
	pass


func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	# 标记为异步效果，信号由子类自己处理
	_signal_handled_by_subclass = true
	
	# 1. 守卫：必须是物理实体
	var body = target as CharacterBody3D
	if not body:
		push_warning("GE_PhysicsMotion: Target is not CharacterBody3D")
		# 如果目标无效，立即通知完成
		effect_completed.emit(self)
		return
	
	# 2. 计算方向（这是冲锋瞬间锁定的，过程不可变）
	var move_dir = _resolve_direction(body, context)
	if move_dir == Vector3.ZERO:
		push_warning("GE_PhysicsMotion: Cannot resolve direction")
		# 如果方向无效，立即通知完成
		effect_completed.emit(self)
		return
	
	# 4. 准备 Tween（必须在 Physics Process 运行以保证碰撞稳定）
	_tween = body.create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_LINEAR)  # 线性时间，曲线逻辑我们在回调里自己算
	
	# 5. 状态闭包：用于在回调中记录上一帧走到哪了
	_state = {
		"accumulated_dist": 0.0,
		"body": body,
		"direction": move_dir
	}
	
	# 6. 缓存目标与施法者
	_target_body = body
	_instigator_ref = instigator
	
	# 7. 启动驱动器：0.0 -> 1.0
	_tween.tween_method(
		_physics_process_step.bind(_state),
		0.0, 1.0, duration
	)
	
	# 8. 完成回调（在 Tween 完成时 emit 信号）
	_tween.finished.connect(func():
		_on_motion_finished()
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

## 获取角色的面朝方向（统一方法）
## [param] body: Node3D 目标节点
## [param] context: Dictionary 上下文信息
## [return] Vector3 面朝方向向量（已归一化，-Z 为默认前方）
func _get_facing_direction(body: Node3D, context: Dictionary) -> Vector3:
	if not context.has("facing_angle"):
		push_error("GE_PhysicsMotion: facing_angle not found in context")
		return body.global_transform.basis.z.normalized()
	
	var facing_angle : float = context.get("facing_angle")
	return Vector3(-sin(facing_angle), 0.0, -cos(facing_angle)).normalized()

## 方向解析
## [param] body: Node3D 目标节点
## [param] context: Dictionary 上下文信息
## [return] Vector3 方向向量（已归一化）
func _resolve_direction(body: Node3D, context: Dictionary) -> Vector3:
	var dir: Vector3 = Vector3.ZERO
	
	match direction_type:
		DirectionType.FORWARD:
			# 向面朝方向（-Z 为默认前方）
			dir = _get_facing_direction(body, context)
		
		DirectionType.INPUT:
			# 获取输入向量
			var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if input.length() > 0.1:
				# 转换到相机空间
				var cam = body.get_viewport().get_camera_3d()
				if is_instance_valid(cam):
					var cam_basis = cam.global_transform.basis
					# 相机空间：使用相机的 X 和 Z 轴
					dir = (cam_basis.x * input.x + cam_basis.z * input.y).normalized()
				else:
					# 如果没有相机，使用世界空间
					# 注意：与 player.gd 的移动方向保持一致
					# player.gd 使用 Vector3(input_dir.x, 0, -input_dir.y)（-Z 为前方）
					dir = Vector3(input.x, 0, -input.y).normalized()
			else:
				# 如果没有输入，使用面朝方向
				dir = _get_facing_direction(body, context)
		
		DirectionType.MOUSE:
			# 向鼠标方向
			if context.has("mouse_direction") and context["mouse_direction"] is Vector3:
				dir = (context["mouse_direction"] as Vector3).normalized()
				# 确保方向在 XZ 平面上（忽略 Y 轴）
				dir.y = 0.0
				dir = dir.normalized()
			else:
				# 如果没有鼠标方向，回退到面朝方向
				push_warning("GE_PhysicsMotion: MOUSE_DIR mode requires 'mouse_direction' in context, falling back to FORWARD")
				dir = _get_facing_direction(body, context)
		
		DirectionType.CUSTOM:
			# 自定义方向
			if context.has("direction") and context["direction"] is Vector3:
				dir = (context["direction"] as Vector3).normalized()
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
func _on_motion_finished() -> void:
	# 通知 Effect 完成（信号驱动模式）
	effect_completed.emit(self)
	
	if is_instance_valid(_target_body) and is_instance_valid(_instigator_ref):
		remove(_target_body, _instigator_ref)

func _remove(target: Node, instigator: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	
	# 停止 Tween
	if is_instance_valid(_tween):
		_tween.kill()
	
	# 通知 Effect 完成（被取消时也需要通知，避免技能卡死）
	effect_completed.emit(self)
	
	# 清理运行时状态
	_tween = null
	_state.clear()
	_target_body = null
	_instigator_ref = null

func _get_description() -> String:
	var dir_name = DirectionType.keys()[direction_type]
	var curve_info = "（使用曲线）" if speed_curve else "（线性）"
	return "物理位移: 向 %s 方向移动 %.1f 米 (%.2f秒)%s" % [dir_name, distance, duration, curve_info]
