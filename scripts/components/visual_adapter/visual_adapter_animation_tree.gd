extends VisualAdapter
class_name AnimationTreeVisualAdapter

## 基于 AnimationTree 的视觉适配器
## 适用于使用 AnimationTree 和状态机的角色

@export_group("Animation Tree")
## 动画树节点路径
@export var _animation_tree : AnimationTree = null
@export var _animation_state_machine_path : String = "StateMachine/playback"
@export var _animation_speed_scale_path : String = "TimeScale"
var _animation_state_machine: AnimationNodeStateMachinePlayback = null

## 初始化动画树
func _initialize_adapter() -> void:
	super()
	_init_animation_tree()

func _init_animation_tree() -> void:
	if not is_instance_valid(_character):
		return
	
	# 获取动画树状态机
	_animation_state_machine = _animation_tree.get("parameters/" + _animation_state_machine_path)
	if not is_instance_valid(_animation_state_machine):
		push_warning("AnimationTreeVisualAdapter: AnimationNodeStateMachinePlayback not found")
		return
	
	# 连接动画事件（通过 AnimationPlayer）
	_connect_animation_events()

## 获取动画树
func get_animation_tree() -> AnimationTree:
	return _animation_tree

## 获取动画状态机
func get_animation_state_machine() -> AnimationNodeStateMachinePlayback:
	return _animation_state_machine

## 设置混合参数（用于移动动画等）
## [param] parameter_name: String 参数名称
## [param] value: Variant 参数值
func set_blend_parameter(parameter_name: String, value: Variant) -> void:
	if not is_instance_valid(_animation_tree):
		return
	_animation_tree.set("parameters/" + parameter_name, value)

## 连接动画事件（通过 AnimationPlayer）
func _connect_animation_events() -> void:
	if not is_instance_valid(_animation_tree):
		return

## 播放动画（重写基类方法）
func _play_animation(anim_name: StringName, speed: float = 1.0) -> void:
	if not is_instance_valid(_animation_state_machine):
		# 尝试重新获取
		if is_instance_valid(_animation_tree):
			_animation_state_machine = _animation_tree.get("parameters/" + _animation_state_machine_path)
	
	if not is_instance_valid(_animation_state_machine):
		push_warning("AnimationTreeVisualAdapter: Cannot play animation '%s', animation_state_machine is invalid" % anim_name)
		return
	
	_animation_tree.set("parameters/" + _animation_speed_scale_path, speed)
	_animation_state_machine.travel(anim_name)
