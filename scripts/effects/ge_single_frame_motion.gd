extends GameplayEffect
class_name GE_SingleFrameMotion

## 位移方向类型
enum DirectionType {
	FORWARD,      ## 向面朝方向
	INPUT,        ## 键盘输入方向
	MOUSE,        ## 鼠标方向（需要 context 中有 mouse_direction）
	CUSTOM        ## 自定义方向（需要 context 中有 direction）
}

@export var direction_type: DirectionType = DirectionType.FORWARD
## 注意：这是单帧的位移距离，实际总距离 = distance * (duration / period)
## 例如：distance = 0.3, duration = 0.3, period = 0.05 → 总距离 = 0.3 * 6 = 1.8 米
@export var distance: float = 0.3  ## 单次位移距离（米）
## 地面冲刺建议 false（贴合斜坡），空中冲刺建议 true
@export var ignore_gravity: bool = false  ## 是否忽略重力

var _cached_direction: Vector3 = Vector3.ZERO
var _direction_cached: bool = false

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var body = target as CharacterBody3D
	if not body:
		push_warning("GE_SingleFrameMotion: Target is not CharacterBody3D")
		return

	# 1. 检查标签：如果目标有 state.rooted 或 state.stunned 标签，且方向类型是 INPUT，则不执行移动
	# 注意：这允许状态效果中的移动（如冲刺），但阻止玩家通过输入控制移动
	if direction_type == DirectionType.INPUT:
		if TagManager.has_tag(target, &"state.rooted") or TagManager.has_tag(target, &"state.stunned"):
			# 有定身/眩晕标签，且方向类型是 INPUT，则不执行移动
			# 但如果是其他方向类型（如 FORWARD），仍然允许移动（因为这是状态效果本身）
			return

	# 2. 计算方向（首次调用时缓存，后续使用缓存的方向）
	# 注意：对于周期性效果，通常希望方向在状态应用时锁定，而不是每帧重新计算
	if not _direction_cached or direction_type == DirectionType.INPUT:
		# INPUT 类型每帧重新计算（因为输入可能改变）
		# 其他类型只在首次计算
		var move_dir = _resolve_direction(body, context)
		if move_dir == Vector3.ZERO:
			push_warning("GE_SingleFrameMotion: Cannot resolve direction")
			return
		
		_cached_direction = move_dir
		_direction_cached = true

	# 3. 构建位移向量
	var velocity_vector = _cached_direction * distance

	# 4. 简易重力处理（贴地逻辑）
	if not ignore_gravity and not body.is_on_floor():
		# 给一个固定的下压力，确保贴合斜坡
		velocity_vector.y -= 0.5

	# 5. 物理执行与滑墙逻辑
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

## 
func _resolve_direction(body: Node3D, context: Dictionary) -> Vector3:
	var dir: Vector3 = Vector3.ZERO

	match direction_type:
		DirectionType.FORWARD:
			# 向面朝方向（-Z 为默认前方）
			dir = _get_facing_direction(body, context)
		DirectionType.INPUT:
			# 获取输入向量（每帧重新计算）
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
					dir = Vector3(input.x, 0, -input.y).normalized()
			else:
				# 如果没有输入，使用面朝方向
				dir = _get_facing_direction(body, context)
		DirectionType.MOUSE:
			# 向鼠标方向（首次计算时锁定）
			if context.has("mouse_direction") and context["mouse_direction"] is Vector3:
				dir = (context["mouse_direction"] as Vector3).normalized()
				# 确保方向在 XZ 平面上（忽略 Y 轴）
				dir.y = 0.0
				dir = dir.normalized()
			else:
				# 如果没有鼠标方向，回退到面朝方向
				push_warning("GE_SingleFrameMotion: MOUSE_DIR mode requires 'mouse_direction' in context, falling back to FORWARD")
				dir = _get_facing_direction(body, context)
		DirectionType.CUSTOM:
			# 自定义方向（首次计算时锁定）
			if context.has("direction") and context["direction"] is Vector3:
				dir = (context["direction"] as Vector3).normalized()
				# 确保方向在 XZ 平面上
				dir.y = 0.0
				dir = dir.normalized()
			else:
				push_warning("GE_SingleFrameMotion: CUSTOM mode requires 'direction' in context")

	# 强制水平移动（忽略 Y 轴）
	dir.y = 0.0
	return dir.normalized()

## 获取角色的面朝方向（统一方法）
## [param] body: Node3D 目标节点
## [param] context: Dictionary 上下文信息
## [return] Vector3 面朝方向向量（已归一化，-Z 为默认前方）
func _get_facing_direction(body: Node3D, context: Dictionary) -> Vector3:
	if context.has("facing_angle") and context["facing_angle"] is float:
		var facing_angle: float = context["facing_angle"]
		#return Vector3(sin(facing_angle), 0.0, cos(facing_angle)).normalized()
		return Basis.from_euler(Vector3(0, facing_angle, 0)) * Vector3.FORWARD

	return body.global_transform.basis.z.normalized()
