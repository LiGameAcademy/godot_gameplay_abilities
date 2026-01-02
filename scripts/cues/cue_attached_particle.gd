extends GameplayCueBase
class_name CueAttachedParticle

## 附加粒子特效 Cue
## 用于播放附加到目标节点的持续特效（如光环、Buff 特效、飘字等）

@export var particle_scene: PackedScene = null  ## 粒子特效场景
@export var attach_to_target: bool = true  ## 是否附加到目标节点
## 是否允许重复创建（如果为 false，挂点节点下已有特效时不会重复创建）
@export var allow_duplicate: bool = false

## 存储已附加的特效实例（用于停止时清理）
## 格式：Dictionary[Node, Node] 目标节点 -> 特效节点
## 注意：一个挂点可以挂载多个不同的 Cue，所以需要记录每个 Cue 创建的特效
var _attached_particles: Dictionary = {}  ## Dictionary[Node, Node]

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	if not is_instance_valid(particle_scene):
		return

	# 检查是否允许重复创建
	if not allow_duplicate and _attached_particles.has(target):
		return

	var particle = particle_scene.instantiate()
	if not is_instance_valid(particle):
		return
	
	# 附加到目标节点（通过目标的 get_attachment_point 方法）
	if attach_to_target and is_instance_valid(target):
		if target.has_method("get_attachment_point"):
			var attachment_node = target.get_attachment_point(attachment_point)
			if is_instance_valid(attachment_node):
				attachment_node.add_child(particle)
				particle.position = offset  # 应用偏移量
				_attached_particles[target] = particle
			else:
				push_error("CueAttachedParticle：挂点无效！")
		else:
			push_error("CueAttachedParticle: 目标没有方法：get_attachment_point！")
	
	else:
		# 在指定位置生成（不附加）
		target.get_tree().current_scene.add_child(particle)
		particle.global_position = location
	
	if particle.has_method("setup_from_context"):
		particle.call("setup_from_context", context)

## 停止 Cue（从目标身上移除特效）
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
