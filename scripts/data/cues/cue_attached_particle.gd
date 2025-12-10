extends GameplayCueBase
class_name CueAttachedParticle

## 附加粒子特效 Cue
## 用于播放附加到目标节点的持续特效（如光环、Buff 特效等）
## 特效会跟随目标移动，并在目标被销毁时自动清理

@export_group("Attached Particle Settings")
## 粒子特效场景（.tscn）
@export var particle_scene: PackedScene = null
## 是否附加到目标节点（true 时特效会跟随目标，false 时只设置初始位置）
@export var attach_to_target: bool = true
## 特效缩放随机性（0.0-1.0），用于避免重复感
@export_range(0.0, 1.0) var scale_randomness: float = 0.0

## 存储已附加的特效实例（用于停止时清理）
var _attached_instances: Dictionary = {}  ## Dictionary[Node, Node3D] 目标节点 -> 特效实例

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	if not is_instance_valid(particle_scene):
		return
	
	# 如果已经附加了特效，不重复创建
	if _attached_instances.has(target):
		var existing_instance = _attached_instances[target]
		if is_instance_valid(existing_instance):
			return
	
	var particle = particle_scene.instantiate()
	if not is_instance_valid(particle):
		return
	
	# 如果附加到目标，添加到目标节点；否则添加到场景根节点
	if attach_to_target and is_instance_valid(target):
		# 尝试找到合适的父节点（优先使用 Visuals 节点，如果没有则使用目标本身）
		var parent_node = target.get_node_or_null("Visuals")
		if not is_instance_valid(parent_node):
			parent_node = target
		
		# 确保父节点是 Node3D
		if parent_node is Node3D:
			parent_node.add_child(particle)
			# 设置本地位置（相对于父节点）
			particle.position = Vector3.ZERO
			# 应用偏移量（相对于父节点）
			if offset != Vector3.ZERO:
				particle.position += offset
		else:
			# 如果父节点不是 Node3D，添加到场景根节点并使用世界坐标
			var root = Engine.get_main_loop().root
			if is_instance_valid(root):
				root.add_child(particle)
				if particle is Node3D:
					particle.global_position = location
			else:
				push_warning("CueAttachedParticle: Cannot spawn particle, no valid root node")
				particle.queue_free()
				return
	else:
		# 不附加，添加到场景根节点
		var root = Engine.get_main_loop().root
		if not is_instance_valid(root):
			push_warning("CueAttachedParticle: Cannot spawn particle, no valid root node")
			particle.queue_free()
			return
		
		root.add_child(particle)
		# 设置位置
		if particle is Node3D:
			particle.global_position = location
	
	# 应用缩放随机性
	if particle is Node3D and scale_randomness > 0.0:
		var scale_factor = 1.0 + randf_range(-scale_randomness, scale_randomness)
		particle.scale *= scale_factor
	
	# 如果附加到目标，记录实例以便后续清理
	if attach_to_target and is_instance_valid(target):
		_attached_instances[target] = particle
		
		# 监听目标销毁，自动清理特效
		if target.has_signal("tree_exiting"):
			if not target.tree_exiting.is_connected(_on_target_tree_exiting):
				target.tree_exiting.connect(_on_target_tree_exiting.bind(target))
		elif target.has_method("tree_exiting"):
			# 使用定时器定期检查目标是否有效
			var check_timer = Timer.new()
			check_timer.wait_time = 0.1
			check_timer.timeout.connect(_check_target_validity.bind(target, particle))
			particle.add_child(check_timer)
			check_timer.start()

## 停止 Cue（清理附加的特效）
## [param] target: Node 目标节点（可选，如果不提供则清理所有实例）
func _stop(target: Node = null) -> void:
	if target == null:
		# 清理所有实例
		for instance in _attached_instances.values():
			if is_instance_valid(instance):
				instance.queue_free()
		_attached_instances.clear()
		return
	
	# 清理指定目标的实例
	if not _attached_instances.has(target):
		return
	
	var instance = _attached_instances[target]
	if is_instance_valid(instance):
		instance.queue_free()
	
	_attached_instances.erase(target)

## 目标退出场景树时的回调
func _on_target_tree_exiting(target: Node) -> void:
	_stop(target)

## 检查目标有效性（用于没有 tree_exiting 信号的情况）
func _check_target_validity(target: Node, particle: Node3D) -> void:
	if not is_instance_valid(target):
		_stop(target)
		return
	
	# 如果目标已经不在场景树中，清理特效
	if not target.is_inside_tree():
		_stop(target)

