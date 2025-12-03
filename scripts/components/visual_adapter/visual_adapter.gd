@abstract
extends Node
class_name VisualAdapter

## 视觉适配器基类（抽象类）
## 连接业务层和技能组件，处理动画相关逻辑
## 职责：
## 1. 监听技能组件的技能释放信号
## 2. 处理动画播放
## 3. 在动画触发关键帧时应用技能效果

## 能力组件引用
@export var _ability_component: GameplayAbilityComponent = null
@export var _ability_event_name: StringName = "ability_activated"
## 角色实体引用（用于获取面朝方向等上下文信息）
var _character: Node = null
## 当前正在执行的能力ID（用于动画事件触发）
var _current_ability_id: StringName = &""

func _ready() -> void:
	# 获取父节点（应该是角色实体）
	_character = get_parent()
	if not is_instance_valid(_character):
		push_error("VisualAdapter: Parent node is not valid")
		return
	
	# 尝试获取能力组件
	if not is_instance_valid(_ability_component):
		# 尝试通过接口获取
		_ability_component = GameplayAbilitySystem.get_component_by_interface(_character, "GameplayAbilityComponent")
	
	if is_instance_valid(_ability_component):
		_ability_component.ability_cast.connect(_on_ability_cast)
		_ability_component.ability_activated.connect(_on_ability_activated)
		_initialize_adapter()
	else:
		push_warning("VisualAdapter: Ability component not found, animation adapter will not work")

## 初始化适配器（子类可重写）
func _initialize_adapter() -> void:
	pass

## 动画事件回调（由动画系统触发，供动画的 Method Call 轨道调用）
## 注意：在动画编辑器中，Method Call 轨道应该调用此方法
## [param] event_name: String 事件名称（例如 "ability_activated"）
## [param] _data: Variant 事件数据（可选）
func on_animation_event(event_name: String, data: Dictionary = {}) -> void:
	_on_animation_event(event_name, data)

func play_animation(anim_name: StringName, speed: float = 1.0) -> void:
	_play_animation(anim_name, speed)

## 播放动画（子类必须实现）
## [param] anim_name: StringName 动画名称
@abstract func _play_animation(anim_name: StringName, speed: float = 1.0) -> void

## 动画事件回调（内部实现）
## [param] event_name: String 事件名称
## [param] _data: Variant 事件数据
func _on_animation_event(event_name: StringName, data: Dictionary = {}) -> void:
	# 如果事件名是技能生效点，则执行技能效果
	if event_name != _ability_event_name:
		return
	
	if _current_ability_id.is_empty():
		return
	
	if not is_instance_valid(_ability_component):
		push_warning("VisualAdapter: Cannot apply ability effect, _ability_component is not valid")
		_current_ability_id = &""
		return
	
	# 构建上下文，包含角色面朝方向
	var context: Dictionary = data
	context["facing_angle"] = _get_facing_angle()
	
	_ability_component.apply_ability_effect(_current_ability_id, null, context)

	#TODO 如果你的连招系统（Animation State Machine）允许快速切换，_current_ability_id 可能会在动画还没结束时就被覆盖。
	#TODO 建议在 commit_cast 时将 ID 存入一个队列，或者确保动画状态机锁定（不可打断）直到生效点结束。
	_current_ability_id = &""
	print("VisualAdapter: Ability effect applied: %s on animation event: %s" % [_current_ability_id, event_name])

## 获取角色面朝角度（子类可重写）
## [return] float 面朝角度（弧度）
func _get_facing_angle() -> float:
	if not is_instance_valid(_character):
		return 0.0
	
	# 尝试从 visuals 子节点获取
	var visuals = _character.get_node_or_null("Visuals")
	if is_instance_valid(visuals) and visuals is Node3D:
		return (visuals as Node3D).rotation.y
	
	# 如果没有 visuals，尝试从角色自身获取
	if _character is Node3D:
		var char_3d = _character as Node3D
		if char_3d.rotation.y != 0.0:
			return char_3d.rotation.y
		
		# 从 transform 计算
		var forward = -char_3d.global_transform.basis.z
		return atan2(forward.x, forward.z)
	
	return 0.0

## 能力施放时的回调（由能力组件信号触发）
func _on_ability_cast(ability_id: StringName) -> void:
	if not is_instance_valid(_ability_component):
		return
	
	var ability_data = _ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		push_error("VisualAdapter: Ability data is not valid for ability_id: %s" % ability_id)
		return
	
	if ability_data is ActiveAbility:
		var active_ability = ability_data as ActiveAbility
		_play_animation(active_ability.animation_name)
		_current_ability_id = ability_id
	
	print("VisualAdapter: Ability casted: ", ability_id)

## 能力激活时的回调（由能力组件信号触发）
func _on_ability_activated(_ability_id: StringName) -> void:
	print("VisualAdapter: Ability activated: ", _ability_id)
