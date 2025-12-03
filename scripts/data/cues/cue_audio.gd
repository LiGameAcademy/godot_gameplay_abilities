extends GameplayCueBase
class_name CueAudio

## 音效 Cue
## 用于播放音效

@export_group("Audio Settings")
## 音效文件
@export var audio_stream: AudioStream = null
## 音调随机性（0.0-1.0），用于避免听觉疲劳
@export_range(0.0, 1.0) var pitch_randomness: float = 0.1
## 音量（0.0-1.0）
@export_range(0.0, 1.0) var volume_db: float = 0.0

func _execute(target: Node, location: Vector3, context: Dictionary) -> void:
	if not is_instance_valid(audio_stream):
		return
	
	var player = AudioStreamPlayer3D.new()
	player.stream = audio_stream
	player.volume_db = volume_db
	
	# 应用音调随机性
	if pitch_randomness > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	
	# 添加到场景树
	var root = Engine.get_main_loop().root
	if not is_instance_valid(root):
		push_warning("CueAudio: Cannot play audio, no valid root node")
		player.queue_free()
		return
	
	root.add_child(player)
	
	# 设置位置
	player.global_position = location
	
	# 播放
	player.play()
	
	# 播放完成后自动销毁
	player.finished.connect(player.queue_free)

