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
@export var _idle_animation_name: StringName = "movement"
@export var _ability_event_name: StringName = "ability_activated"
## 角色实体引用（用于获取面朝方向等上下文信息）
var _character: Node = null
## 当前正在执行的能力ID（用于动画事件触发）
var _current_ability_id: StringName = &""
## 是否允许中断（后摇阶段）
var can_interrupt: bool = false

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

func _on_animation_ability_activated(data: Dictionary = {}) -> void:
	
	if _current_ability_id.is_empty():
		return
	
	if not is_instance_valid(_ability_component):
		push_warning("VisualAdapter: Cannot apply ability effect, _ability_component is not valid")
		_current_ability_id = &""
		return
	
	# 构建上下文，包含角色面朝方向
	var context: Dictionary = data
	context["facing_angle"] = _get_facing_angle()
	
	# 应用技能效果（技能系统内部会处理完成回调）
	_ability_component.apply_ability_effect(_current_ability_id, null, context)
	
	var applied_ability_id = _current_ability_id
	_current_ability_id = &""
	
	# 技能效果已应用，清除当前执行的技能标记
	if is_instance_valid(_ability_component) and _ability_component.has_method("clear_current_casting_ability"):
		_ability_component.clear_current_casting_ability()
	
	print("VisualAdapter: Ability effect applied: %s on animation event: ability_activated" % applied_ability_id)

## 动画事件回调（内部实现）
## [param] event_name: String 事件名称
## [param] _data: Variant 事件数据
func _on_animation_event(event_name: StringName, data: Dictionary = {}) -> void:
	# 如果事件名是技能生效点，则执行技能效果
	if event_name != _ability_event_name:
		return

	_on_animation_ability_activated(data)

## 获取角色面朝角度（公共方法，供外部调用）
## [return] float 面朝角度（弧度）
func get_facing_angle() -> float:
	return _get_facing_angle()

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
		# 统一处理：获取动画名称并播放（由技能自己决定动画名称）
	var anim_name: StringName = ability_data.get_animation_name()
	if anim_name != &"":
		# 【简化设计】每次技能开始时，先切换到 movement 状态
		# 这样可以简化动画状态机的配置，只需要 movement -> attack 和 attack -> movement 的过渡
		# 不需要复杂的 attack -> attack 过渡
		_play_animation(_idle_animation_name)
		# 等待一帧，确保状态切换完成
		await get_tree().process_frame
		
		# 新动作开始，先锁死（前摇锁死）
		can_interrupt = false
		# 通知能力组件（解耦设计：通过能力组件作为中介）
		if is_instance_valid(_ability_component) and _ability_component.has_method("set_can_interrupt"):
			_ability_component.set_can_interrupt(false)
		_play_animation(anim_name)
		_current_ability_id = ability_id
		print("VisualAdapter: Ability casted: %s (animation: %s)" % [ability_id, anim_name])
	else:
		
		# 【立即生效技能】如果没有动画，直接应用效果并完成
		_ability_component.apply_ability_effect(ability_id, null, {})
		# 立即清除当前执行技能标记（因为已经完成）
		if is_instance_valid(_ability_component) and _ability_component.has_method("clear_current_casting_ability"):
			_ability_component.clear_current_casting_ability()
		print("VisualAdapter: Instant cast ability applied: %s" % ability_id)
	

## 能力激活时的回调（由能力组件信号触发）
## 技能激活 = 伤害判定完成 = 进入后摇阶段 = 可以中断
## 注意：此时技能效果已应用，但动画可能还在播放后摇部分
func _on_ability_activated(_ability_id: StringName) -> void:
	print("VisualAdapter: Ability activated: ", _ability_id)
	# 技能激活时，进入后摇阶段，允许中断
	can_interrupt = true
	# 通知能力组件（解耦设计：通过能力组件作为中介）
	if is_instance_valid(_ability_component) and _ability_component.has_method("set_can_interrupt"):
		_ability_component.set_can_interrupt(true)

## 检查是否可以中断当前攻击
## [return] bool 是否可以中断
func can_cancel_attack() -> bool:
	return can_interrupt
