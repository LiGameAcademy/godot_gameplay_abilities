extends Node
class_name GameplayAbilityComponent

## 技能组件（采用鸭子类型设计，不继承基类）
## 管理实体的技能、法力、冷却等

@export var initial_abilities: Array[GameplayAbility] = []  ## 初始技能列表

var _status_comp: Node = null  ## 状态组件（采用鸭子类型）
var _mana_comp: Node = null  ## 法力组件（采用鸭子类型）
var _cooldown_timers: Dictionary[StringName, Timer] = {}  ## 冷却计时器
var _learned_abilities: Dictionary[StringName, GameplayAbility] = {}  ## 已学会的技能

signal ability_learned(ability_id: StringName)
signal ability_forgotten(ability_id: StringName)
signal ability_cast(ability_id: StringName, target: Node)
signal cooldown_ready(ability_id: StringName)

func _ready() -> void:
	# 使用鸭子类型查询组件
	_status_comp = GameplayAbilitySystem.get_component_by_interface(get_parent(), "GameplayStatusComponent")
	_mana_comp = GameplayAbilitySystem.get_component_by_interface(get_parent(), "ManaComponent")
	
	# 学习初始技能
	for ability_data in initial_abilities:
		learn_ability(ability_data)

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
		AbilityEventBus.emit_ability_learned(get_parent(), ability_id)

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
		AbilityEventBus.emit_ability_forgotten(get_parent(), ability_id)

## 检查冷却是否就绪
## [param] ability_id: StringName 技能ID
func is_cooldown_ready(ability_id: StringName) -> bool:
	if not _cooldown_timers.has(ability_id):
		return true  # 没有冷却计时器，认为冷却就绪
	var timer = _cooldown_timers[ability_id]
	if not is_instance_valid(timer):
		return true
	return timer.time_left <= 0.0

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
func can_cast(ability_id: StringName, target: Node, context: Dictionary = {}) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return false  # 没学会
	if ability_data.disabled:
		return false  # 技能禁用
	
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

## 获取当前法力值
func get_mana() -> float:
	if not is_instance_valid(_mana_comp):
		return 0.0
	if _mana_comp.has_method("get_current_value"):
		return _mana_comp.get_current_value()
	return 0.0

## 尝试消耗法力
## [param] amount: float 消耗量
func try_spend_mana(amount: float) -> bool:
	if not is_instance_valid(_mana_comp):
		return false
	if _mana_comp.has_method("try_spend_mana"):
		return _mana_comp.try_spend_mana(amount)
	return false

## 提交施法（消耗资源，让技能进入冷却）
## [param] ability_id: StringName 技能ID
func commit_cast(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		return false
	
	if not ability_data.commit_cast(self):
		return false
	return true

## 应用技能效果
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息
func apply_ability_effect(ability_id: StringName, target: Node, context: Dictionary = {}) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		return
	
	ability_data.cast(self, target, context)
	ability_cast.emit(ability_id, target)
		# 触发统一游戏事件：ability_activated
		AbilityEventBus.trigger_game_event(&"ability_activated", {
			"entity": get_parent(),
			"ability_id": ability_id
		})
		
		# 同时发送细粒度事件（向后兼容）
		AbilityEventBus.emit_ability_activated(get_parent(), ability_id)

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
	
	# 对于主动技能，检查冷却时间
	if ability_data is ActiveAbility:
		var active_ability = ability_data as ActiveAbility
		if active_ability.cooldown_duration <= 0.0:
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
		
		# 同时发送细粒度事件（向后兼容）
		AbilityEventBus.emit_ability_cooldown_ready(get_parent(), ability_id)
