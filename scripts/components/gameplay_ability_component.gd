extends Node
class_name GameplayAbilityComponent

## 技能组件（采用鸭子类型设计，不继承基类）
## 管理实体的技能、法力、冷却等

@export var initial_abilities: Array[GameplayAbility] = []  ## 初始技能列表

@export var _status_comp: GameplayStatusComponent = null  ## 状态组件
@export var _attribute_comp: GameplayVitalAttributeComponent = null  ## 属性组件

var _cooldown_timers: Dictionary[StringName, Timer] = {}  ## 冷却计时器
var _learned_abilities: Dictionary[StringName, GameplayAbility] = {}  ## 已学会的技能
## 当前正在执行的技能ID（用于后摇可取消机制）
var _current_casting_ability_id: StringName = &""
## 是否允许中断当前攻击（用于后摇取消机制）
var can_interrupt_current: bool = false

signal ability_learned(ability_id: StringName)				## 技能学会信号
signal ability_forgotten(ability_id: StringName)			## 技能遗忘信号
signal ability_cast(ability_id: StringName)					## 技能施放信号
signal ability_activated(ability_id: StringName)			## 技能生效信号
signal cooldown_ready(ability_id: StringName)				## 冷却就绪信号

func _ready() -> void:
	# 学习初始技能
	for ability_data in initial_abilities:
		learn_ability(ability_data)
	# 启用 process 以更新连击计时器
	set_process(true)

## 每帧更新（更新所有技能的内部状态）
func _process(delta: float) -> void:
	# 统一调用所有技能的 update 方法（符合开闭原则）
	for ability_id in _learned_abilities:
		var ability_data = _learned_abilities[ability_id]
		if is_instance_valid(ability_data):
			ability_data.update(delta)

## 学习技能
## [param] ability_data: GameplayAbility 技能数据
func learn_ability(ability_data: GameplayAbility) -> void:
	if not is_instance_valid(ability_data):
		return
	
	var ability_id := ability_data.ability_id
	if _learned_abilities.has(ability_id):
		# 已经学会
		return
	
	_learned_abilities[ability_id] = ability_data.duplicate()
	
	# 创建冷却计时器
	var timer = _create_cooldown_timer(ability_id)
	if is_instance_valid(timer):
		_cooldown_timers[ability_id] = timer
	
	# 检查并应用被动技能
	if is_instance_valid(_status_comp):
		ability_data.on_learned(self, _status_comp)
	
	ability_learned.emit(ability_id)
	# 触发统一游戏事件：ability_learned
	AbilityEventBus.trigger_game_event(&"ability_learned", {
		"entity": get_parent(),
		"ability_id": ability_id
	})
	
	# 同时发送细粒度事件（向后兼容）
	#AbilityEventBus.emit_ability_learned(get_parent(), ability_id)

## 遗忘技能
## [param] ability_id: StringName 技能ID
func forget_ability(ability_id: StringName) -> void:
	if not _learned_abilities.has(ability_id):
		return
	
	var ability_data = _learned_abilities[ability_id]
	_learned_abilities.erase(ability_id)
	
	# 移除冷却计时器
	if _cooldown_timers.has(ability_id):
		var timer = _cooldown_timers[ability_id]
		if is_instance_valid(timer):
			timer.queue_free()
		_cooldown_timers.erase(ability_id)
	
	# 移除被动技能效果
	if is_instance_valid(ability_data) and is_instance_valid(_status_comp):
		ability_data.on_forgotten(self, _status_comp)
	
	ability_forgotten.emit(ability_id)
		# 触发统一游戏事件：ability_forgotten
	AbilityEventBus.trigger_game_event(&"ability_forgotten", {
		"entity": get_parent(),
		"ability_id": ability_id
	})
	
	# 同时发送细粒度事件（向后兼容）
	#AbilityEventBus.emit_ability_forgotten(get_parent(), ability_id)

## 检查冷却是否就绪
## [param] ability_id: StringName 技能ID
func is_cooldown_ready(ability_id: StringName) -> bool:
	if not _cooldown_timers.has(ability_id):
		return true  # 没有冷却计时器，认为冷却就绪
	var timer = _cooldown_timers[ability_id]
	if not is_instance_valid(timer):
		return true
	return timer.time_left <= 0.0

## 获取冷却进度（0.0-1.0，0.0 表示冷却完成，1.0 表示刚开始冷却）
## [param] ability_id: StringName 技能ID
## [return] float 冷却进度
func get_cooldown_progress(ability_id: StringName) -> float:
	if not _cooldown_timers.has(ability_id):
		return 0.0  # 没有冷却，进度为 0
	
	var timer = _cooldown_timers[ability_id]
	if not is_instance_valid(timer):
		return 0.0
	
	if timer.wait_time <= 0.0:
		return 0.0
	
	return timer.time_left / timer.wait_time

## 开始冷却
## [param] ability_id: StringName 技能ID
## [param] duration: float 冷却持续时间
func start_cooldown(ability_id: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	
	if not _cooldown_timers.has(ability_id):
		# 创建新的冷却计时器
		var timer = _create_cooldown_timer(ability_id)
		if not is_instance_valid(timer):
			return
		_cooldown_timers[ability_id] = timer
	
	var timer = _cooldown_timers[ability_id]
	if is_instance_valid(timer):
		timer.wait_time = duration
		timer.start()

## 检查是否可以施法
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息
func can_cast(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		push_error("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return false  # 没学会
	if ability_data.disabled:
		print("GameplayAbilityComponent: Ability %s is disabled." % ability_id)
		return false  # 技能禁用
	if not is_cooldown_ready(ability_id):
		return false  # 技能冷却中
	return ability_data.can_cast(self, target, context)

## 获取技能数据
## [param] ability_id: StringName 技能ID
func get_ability_data(ability_id: StringName) -> GameplayAbility:
	if not _learned_abilities.has(ability_id):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return null
	return _learned_abilities[ability_id]

## 禁用技能
## [param] ability_id: StringName 技能ID
func disable_ability(ability_id: StringName) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	ability_data.disabled = true

## 启用技能
## [param] ability_id: StringName 技能ID
func enable_ability(ability_id: StringName) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	ability_data.disabled = false

## 获取所有技能
func get_all_abilities() -> Array[GameplayAbility]:
	return _learned_abilities.values()

## 获取所有已学会的技能字典
## [return] Dictionary[StringName, GameplayAbility] 技能字典
func get_all_learned_abilities() -> Dictionary:
	return _learned_abilities.duplicate()

## 检查是否正在自动施法
## [param] ability_id: StringName 技能ID
func is_autocast_active(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return false
	return ability_data.is_autocast()

## 检查是否可以自动施法
## [param] ability_id: StringName 技能ID
func can_autocast(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return false
	return ability_data.can_autocast()

## 切换自动施法状态
## [param] ability_id: StringName 技能ID
func toggle_autocast(ability_id: StringName) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	ability_data.toggle_autocast()

## 提交施法（消耗资源，让技能进入冷却）
## [param] ability_id: StringName 技能ID
func commit_cast(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		push_error("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return false
	
	if not ability_data.commit_cast(self):
		push_error("GameplayAbilityComponent: Ability %s commit cast failed." % ability_id)
		return false

	if not is_cooldown_ready(ability_id):
		return false
	
	# 获取冷却时间（使用方法，支持 CombatAbility 重写）
	var cooldown = ability_data.get_cooldown_duration()
	if cooldown > 0.0:
		start_cooldown(ability_id, cooldown)

	# 设置当前正在执行的技能
	_current_casting_ability_id = ability_id
	can_interrupt_current = false  # 技能刚开始，不可中断（前摇锁死）
	
	ability_cast.emit(ability_id)
	# 触发统一游戏事件：ability_cast
	AbilityEventBus.trigger_game_event(&"ability_cast", {
		"entity": get_parent(),
		"ability_id": ability_id,
	})
	print("AbilityComponent: ability commit casted: ", ability_id)
	return true

## 应用技能效果
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息
func apply_ability_effect(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		push_error("GameplayAbilityComponent: Ability data is not valid")
		return
	
	ability_data.cast(self, target, context)
	
	# 技能效果已应用，进入后摇阶段，允许中断
	if _current_casting_ability_id == ability_id:
		can_interrupt_current = true
	
	ability_activated.emit(ability_id)
	# 触发统一游戏事件：ability_activated
	AbilityEventBus.trigger_game_event(&"ability_activated", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 清除技能效果
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
func clear_ability_effect(ability_id: StringName, target: Node) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		return
	
	ability_data.clear_cast(self, target)

## 创建冷却计时器
func _create_cooldown_timer(ability_id: StringName) -> Timer:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return null
	
	# 使用 get_cooldown_duration() 方法获取冷却时间（支持 CombatAbility 重写）
	var cooldown = ability_data.get_cooldown_duration()
	if cooldown <= 0.0:
		return null
	
	var timer = Timer.new()
	timer.name = "CooldownTimer_%s" % ability_id
	timer.one_shot = true
	timer.timeout.connect(_on_cooldown_timeout.bind(ability_id))
	add_child(timer)
	return timer

## 冷却时间到期
func _on_cooldown_timeout(ability_id: StringName) -> void:
	cooldown_ready.emit(ability_id)
	# 触发统一游戏事件：ability_cooldown_ready
	AbilityEventBus.trigger_game_event(&"ability_cooldown_ready", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 设置是否允许中断当前攻击（由 VisualAdapter 调用）
## [param] can_interrupt: bool 是否允许中断
func set_can_interrupt(can_interrupt: bool) -> void:
	can_interrupt_current = can_interrupt

## 检查是否可以中断当前攻击
## [return] bool 是否可以中断
func can_interrupt() -> bool:
	return can_interrupt_current

## 获取当前正在执行的技能ID
## [return] StringName 当前执行的技能ID，如果为空则表示没有正在执行的技能
func get_current_casting_ability_id() -> StringName:
	return _current_casting_ability_id

## 检查是否有正在执行的技能
## [return] bool 是否有正在执行的技能
func has_casting_ability() -> bool:
	return not _current_casting_ability_id.is_empty()

## 清除当前正在执行的技能（在技能完全结束时调用）
func clear_current_casting_ability() -> void:
	_current_casting_ability_id = &""
	can_interrupt_current = false
