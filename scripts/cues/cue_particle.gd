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
	target.get_tree().current_scene.add_child(particle)
	
	# 设置位置
	particle.global_position = location
	# 应用缩放随机性
	if scale_randomness > 0.0:
		var scale_factor = 1.0 + randf_range(-scale_randomness, scale_randomness)
		particle.scale *= scale_factor

	# 处理生命周期：如果粒子有 finished 信号，连接自动销毁
	if particle.has_signal("finished"):
		particle.finished.connect(particle.queue_free)
