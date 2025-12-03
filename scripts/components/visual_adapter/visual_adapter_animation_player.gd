extends VisualAdapter
class_name AnimationPlayerVisualAdapter

## 基于 AnimationPlayer 的视觉适配器
## 适用于使用 AnimationPlayer 的角色

@export_group("Animation Player")
## 动画播放器节点路径
@export var _animation_player: AnimationPlayer = null

## 初始化动画播放器
func _initialize_adapter() -> void:
	super()
	_init_animation_player()

func _init_animation_player() -> void:
	if not is_instance_valid(_character):
		return
	
	if not is_instance_valid(_animation_player):
		push_warning("AnimationPlayerVisualAdapter: AnimationPlayer not found")
		return

	# 连接动画完成信号（可选）
	if not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)

## 播放动画（重写基类方法）
func _play_animation(anim_name: StringName, speed: float = 1.0) -> void:
	if not is_instance_valid(_animation_player):
		push_warning("AnimationPlayerVisualAdapter: Cannot play animation '%s', _animation_player is invalid" % anim_name)
		return
	
	# 检查动画是否存在
	if not _animation_player.has_animation(anim_name):
		push_warning("AnimationPlayerVisualAdapter: Animation '%s' not found" % anim_name)
		return
	
	_animation_player.play(anim_name, speed)

## 获取动画播放器
func get_animation_player() -> AnimationPlayer:
	return _animation_player

## 设置动画播放速度
## [param] speed: float 播放速度（1.0 为正常速度）
func set_animation_speed(speed: float) -> void:
	if is_instance_valid(_animation_player):
		_animation_player.speed_scale = speed

## 动画完成回调
func _on_animation_finished(anim_name: StringName) -> void:
	# 可以在这里处理动画完成逻辑
	pass
