extends GameplayCueBase
class_name CueAttachedParticle

## 附加粒子特效 Cue
## 用于播放附加到目标节点的持续特效（如光环、Buff 特效等）
## 特效会跟随目标移动，并在目标被销毁时自动清理（通过节点树自动清理）

@export_group("Attached Particle Settings")
## 粒子特效场景（.tscn）
@export var particle_scene: PackedScene = null
## 是否附加到目标节点（true 时特效会跟随目标，false 时只设置初始位置）
@export var attach_to_target: bool = true
## 获取挂点的方法名（目标节点必须实现此方法）
## 方法签名：func method_name(attachment_point: StringName) -> Node3D
## 如果目标没有提供此方法，会报错
@export var attachment_point_method_name: StringName = &"get_attachment_point"
## 是否允许重复创建（如果为 false，挂点节点下已有特效时不会重复创建）
@export var allow_duplicate: bool = false
## 特效缩放随机性（0.0-1.0），用于避免重复感
@export_range(0.0, 1.0) var scale_randomness: float = 0.0

## 存储已附加的特效实例（用于停止时清理）
## 格式：Dictionary[Node, Node] 目标节点 -> 特效节点
## 注意：一个挂点可以挂载多个不同的 Cue，所以需要记录每个 Cue 创建的特效
var _attached_particles: Dictionary = {}  ## Dictionary[Node, Node]

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	# 1. 验证并实例化粒子
	var particle = _validate_and_instantiate_particle()
	if not is_instance_valid(particle):
		return
	
	# 2. 根据配置决定附加方式（先设置位置，再传递上下文）
	if attach_to_target and is_instance_valid(target):
		_attach_to_target(particle, target, context)
	else:
		_spawn_at_location(particle, location, context)
	
	# 3. 【关键】如果特效场景实现了 setup_from_context 方法，传递上下文数据
	# 注意：在位置设置之后调用，确保动画在正确位置播放
	# 这样特效节点可以从 context 中读取关键数据（如伤害值、治疗值等）
	if particle.has_method("setup_from_context"):
		particle.setup_from_context(context)
	
	# 4. 应用缩放随机性（如果配置了）
	_apply_scale_randomness(particle)

## 验证并实例化粒子
## [return] Node 粒子节点，如果失败则返回 null
func _validate_and_instantiate_particle() -> Node:
	if not is_instance_valid(particle_scene):
		push_warning("CueAttachedParticle: particle_scene is not valid")
		return null
	
	var particle = particle_scene.instantiate()
	if not is_instance_valid(particle):
		push_warning("CueAttachedParticle: Failed to instantiate particle scene")
		return null
	
	return particle

## 附加特效到目标节点
## [param] particle: Node 粒子节点
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息（可选）
func _attach_to_target(particle: Node, target: Node, context: Dictionary = {}) -> void:
	# 获取挂点节点
	var attachment_node = _get_attachment_node(target)
	if not is_instance_valid(attachment_node):
		particle.queue_free()
		return
	
	# 检查是否允许重复创建（只检查同一个 Cue 实例是否重复创建）
	if not _check_duplicate(target, attachment_node, particle):
		return
	
	# 将特效添加到挂点节点下（作为子节点，会自动跟随和清理）
	attachment_node.add_child(particle)
	
	# 设置本地位置和偏移
	_setup_particle_position(particle, attachment_node, true)
	
	# 【关键】记录特效实例（用于停止时精确清理）
	# 注意：一个挂点可以挂载多个不同的 Cue，所以需要记录每个 Cue 创建的特效
	_attached_particles[target] = particle

## 在指定位置生成特效（不附加到目标）
## [param] particle: Node 粒子节点
## [param] location: Vector3 生成位置（世界坐标）
## [param] context: Dictionary 上下文信息（可选）
func _spawn_at_location(particle: Node, location: Vector3, context: Dictionary = {}) -> void:
	var root = Engine.get_main_loop().root
	if not is_instance_valid(root):
		push_warning("CueAttachedParticle: Cannot spawn particle, no valid root node")
		particle.queue_free()
		return
	
	root.add_child(particle)
	
	# 设置世界位置
	if particle is Node3D:
		(particle as Node3D).global_position = location
	
	# 设置自动清理（避免内存溢出）
	_setup_auto_cleanup(particle)

## 获取挂点节点（带完整的错误处理）
## [param] target: Node 目标节点
## [return] Node3D 挂点节点，如果失败则返回 null
func _get_attachment_node(target: Node) -> Node3D:
	# 检查目标是否实现了获取挂点的方法
	if not target.has_method(attachment_point_method_name):
		push_error("CueAttachedParticle: Target '%s' does not implement method '%s'. Method signature: func %s(attachment_point: StringName) -> Node3D" % [target.name, attachment_point_method_name, attachment_point_method_name])
		return null
	
	# 调用目标的方法获取挂点节点
	var attachment_node = target.call(attachment_point_method_name, attachment_point)
	if not is_instance_valid(attachment_node):
		push_error("CueAttachedParticle: Target '%s' method '%s' returned null for attachment_point '%s'. Make sure the attachment point is properly configured." % [target.name, attachment_point_method_name, attachment_point])
		return null
	
	if not attachment_node is Node3D:
		push_error("CueAttachedParticle: Target '%s' method '%s' returned non-Node3D for attachment_point '%s'. Expected Node3D, got %s." % [target.name, attachment_point_method_name, attachment_point, attachment_node.get_class()])
		return null
	
	return attachment_node as Node3D

## 检查是否允许重复创建（只检查同一个 Cue 实例是否重复创建）
## [param] target: Node 目标节点
## [param] attachment_node: Node3D 挂点节点
## [param] particle: Node 粒子节点
## [return] bool 如果允许创建返回 true，否则返回 false（并清理粒子）
func _check_duplicate(target: Node, attachment_node: Node3D, particle: Node) -> bool:
	if allow_duplicate:
		return true
	
	# 检查这个 Cue 实例是否已经为目标创建了特效
	# 注意：一个挂点可以挂载多个不同的 Cue，所以只检查当前 Cue 实例是否重复
	if _attached_particles.has(target):
		var existing_particle = _attached_particles[target]
		if is_instance_valid(existing_particle):
			# 已经有效果，不重复创建
			particle.queue_free()
			return false
	
	return true

## 设置粒子位置和偏移
## [param] particle: Node 粒子节点
## [param] parent: Node3D 父节点（挂点节点或场景根节点）
## [param] is_local: bool 是否使用本地坐标（true 为本地坐标，false 为世界坐标）
func _setup_particle_position(particle: Node, parent: Node3D, is_local: bool) -> void:
	if not particle is Node3D:
		return
	
	var particle_3d = particle as Node3D
	
	if is_local:
		# 本地坐标：相对于父节点
		particle_3d.position = Vector3.ZERO
		# 应用偏移量（相对于父节点）
		if offset != Vector3.ZERO:
			particle_3d.position += offset
	else:
		# 世界坐标：直接设置全局位置
		particle_3d.global_position = parent.global_position
		if offset != Vector3.ZERO:
			particle_3d.global_position += offset

## 应用缩放随机性
## [param] particle: Node 粒子节点
func _apply_scale_randomness(particle: Node) -> void:
	if not particle is Node3D:
		return
	
	if scale_randomness <= 0.0:
		return
	
	var scale_factor = 1.0 + randf_range(-scale_randomness, scale_randomness)
	(particle as Node3D).scale *= scale_factor

## 设置自动清理（用于不附加的特效）
## [param] particle: Node 特效节点
func _setup_auto_cleanup(particle: Node) -> void:
	# 如果粒子有 finished 信号，连接自动销毁
	if particle.has_signal("finished"):
		if not particle.finished.is_connected(particle.queue_free):
			particle.finished.connect(particle.queue_free)
	else:
		# 如果没有 finished 信号，使用定时器自动销毁（默认 5 秒后）
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(particle.queue_free)
		particle.add_child(timer)
		timer.start()

## 停止 Cue（从目标身上移除特效）
## [param] target: Node 目标节点
func _stop(target: Node = null) -> void:
	if not is_instance_valid(target):
		push_warning("CueAttachedParticle: Cannot stop cue, target is not valid")
		return
	
	# 只处理附加到目标的情况
	if not attach_to_target:
		# 不附加的特效由自动清理机制处理，不需要手动停止
		return
	
	# 【关键】直接使用记录的特效实例进行清理
	# 这样可以精确清理当前 Cue 实例创建的特效，不影响其他 Cue 创建的特效
	if not _attached_particles.has(target):
		# 没有记录的特效实例，可能已经被清理了，直接返回
		return
	
	var particle = _attached_particles[target]
	if not is_instance_valid(particle):
		# 特效实例已无效，清理记录
		_attached_particles.erase(target)
		return
	
	# 从父节点移除
	var parent = particle.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(particle)
	
	# 销毁节点
	particle.queue_free()
	
	# 清理记录
	_attached_particles.erase(target)
