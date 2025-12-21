extends BTAction
class_name AbilityNodeFaceTarget

## 转向目标节点
## 职责：让施法者转向目标（瞬间或平滑转向）
##
## 原理：
## - 从黑板或 Context 获取目标
## - 计算朝向目标的方向
## - 调用 Agent 的转向方法（如果存在）或直接设置朝向

@export_group("Target Configuration")
## 目标来源 Key（从黑板获取目标）
## 可以是 "targets"（数组）或 "target"（单个节点）
@export var target_key: String = "targets"
## 如果目标是数组，使用第一个目标
@export var use_first_if_array: bool = true

@export_group("Rotation Settings")
## 是否瞬间转向（不插值）
@export var instant: bool = false
## 转向速度（弧度/秒，仅在非瞬间模式下有效）
@export var rotation_speed: float = 12.0
## 是否只考虑水平方向（忽略 Y 轴）
@export var horizontal_only: bool = true

func _tick(instance: BTInstance, delta: float) -> int:
	var agent = instance.agent
	if not is_instance_valid(agent) or not agent is Node3D:
		push_warning("AbilityNodeFaceTarget: Agent is not a valid Node3D")
		return Status.FAILURE
	
	var agent_3d = agent as Node3D
	
	# 1. 获取目标
	var target = _get_target(instance)
	if not is_instance_valid(target) or not target is Node3D:
		# 如果没有目标，尝试从 Context 获取 input_target
		var context = instance.blackboard.get_var("context")
		if is_instance_valid(context):
			if context is AbilityContext:
				target = context.input_target
			elif context is Dictionary and context.has("input_target"):
				target = context.get("input_target")
		
		if not is_instance_valid(target) or not target is Node3D:
			# 仍然没有目标，视为成功（允许空挥）
			return Status.SUCCESS
	
	var target_3d = target as Node3D
	
	# 2. 计算目标方向
	var direction = target_3d.global_position - agent_3d.global_position
	if horizontal_only:
		direction.y = 0.0
	
	if direction.length_squared() < 0.01:
		# 目标太近，无需转向
		return Status.SUCCESS
	
	direction = direction.normalized()
	
	# 3. 计算目标朝向（Godot 3D 中，-Z 是前方）
	var target_basis = Basis.looking_at(-direction, Vector3.UP)
	var target_transform = Transform3D(target_basis, agent_3d.global_position)
	
	# 4. 应用转向
	if instant:
		# 瞬间转向
		agent_3d.global_transform.basis = target_basis
		return Status.SUCCESS
	else:
		# 平滑转向（使用插值）
		var current_basis = agent_3d.global_transform.basis
		var current_forward = -current_basis.z
		var target_forward = -target_basis.z
		
		# 计算角度差
		var angle_diff = current_forward.angle_to(target_forward)
		if angle_diff < 0.01:
			# 已经朝向目标
			return Status.SUCCESS
		
		# 计算这一帧应该转动的角度
		var max_angle = rotation_speed * delta
		var t = min(1.0, max_angle / angle_diff)
		
		# 插值朝向
		var new_forward = current_forward.lerp(target_forward, t).normalized()
		var new_basis = Basis.looking_at(-new_forward, Vector3.UP)
		agent_3d.global_transform.basis = new_basis
		
		# 如果还没完全转向，继续运行
		if angle_diff > 0.01:
			return Status.RUNNING
		else:
			return Status.SUCCESS

## 获取目标节点
func _get_target(instance: BTInstance) -> Node:
	var blackboard = instance.blackboard
	var raw_target = blackboard.get_var(target_key)
	
	if raw_target == null:
		return null
	
	# 如果是数组，取第一个
	if raw_target is Array:
		var target_array = raw_target as Array
		if target_array.is_empty():
			return null
		if use_first_if_array:
			return target_array[0] as Node
		return null
	
	# 如果是单个节点
	if raw_target is Node:
		return raw_target as Node
	
	return null

