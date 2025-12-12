extends GameplayCueBase
class_name CueParticle

## 粒子特效 Cue
## 用于播放粒子特效

@export_group("Particle Settings")
## 粒子特效场景（.tscn）
@export var particle_scene: PackedScene = null
## 特效缩放随机性（0.0-1.0），用于避免重复感
@export_range(0.0, 1.0) var scale_randomness: float = 0.2

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	if not is_instance_valid(particle_scene):
		return
	
	var particle = particle_scene.instantiate()
	if not is_instance_valid(particle):
		return
	
	# 添加到场景树
	var root = Engine.get_main_loop().root
	if not is_instance_valid(root):
		push_warning("CueParticle: Cannot spawn particle, no valid root node")
		particle.queue_free()
		return
	
	root.add_child(particle)
	
	# 设置位置
	if particle is Node3D:
		particle.global_position = location
		
		# 应用缩放随机性
		if scale_randomness > 0.0:
			var scale_factor = 1.0 + randf_range(-scale_randomness, scale_randomness)
			particle.scale *= scale_factor
	
	# 处理生命周期：如果粒子有 finished 信号，连接自动销毁
	if particle.has_signal("finished"):
		particle.finished.connect(particle.queue_free)
	else:
		# 如果没有 finished 信号，使用定时器自动销毁（5秒后）
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(particle.queue_free)
		particle.add_child(timer)
		timer.start()

