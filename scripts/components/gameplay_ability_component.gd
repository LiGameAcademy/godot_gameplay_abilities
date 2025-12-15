extends Node
class_name GameplayAbilityComponent

## 技能组件（采用鸭子类型设计，不继承基类）
## 
## 职责：
## - 管理实体的技能列表（学习、遗忘、启用、禁用）
## - 处理技能施放流程（检查、提交、执行、取消）
## - 管理技能状态（冷却、执行中、可中断）
## - 提供技能查询接口
##
## 设计原则：
## - 公共API清晰、有限，便于外部系统调用
## - 私有方法以下划线开头，明确内部实现细节
## - 使用信号和事件总线进行解耦通信

#region ========== 信号定义 ==========
signal ability_learned(ability_id: StringName)				## 技能学会信号
signal ability_forgotten(ability_id: StringName)			## 技能遗忘信号
signal ability_cast(ability_id: StringName)				## 技能施放信号
signal ability_completed(ability_id: StringName)			## 技能完成信号（所有逻辑执行完毕，进入后摇阶段）
signal cooldown_ready(ability_id: StringName)				## 冷却就绪信号
#endregion

#region ========== 属性定义 ==========
@export_group("Initialization")
## 初始技能列表（在 _ready 时自动学习）
@export var _initial_abilities: Array[GameplayAbility] = []

@export_group("Components")
## 状态组件（用于应用/移除被动技能效果）
@export var _status_comp: GameplayStatusComponent = null
## 属性组件（预留，用于未来扩展）
@export var _attribute_comp: GameplayVitalAttributeComponent = null

## 已学会的技能字典（运行时数据）
var _learned_abilities: Dictionary[StringName, GameplayAbility] = {}

## 当前正在执行的技能ID（用于后摇可取消机制）
var _current_casting_ability_id: StringName = &"":
	set(value):
		_current_casting_ability_id = value

## 是否允许中断当前攻击（用于后摇取消机制）
var can_interrupt_current: bool = false

## 施法前摇计时器（逻辑驱动）
var _cast_point_timers: Dictionary[StringName, SceneTreeTimer] = {}
## 存储施法上下文（target, context）
var _cast_contexts: Dictionary[StringName, Dictionary] = {}
#endregion

#region ========== 生命周期 ==========
func _ready() -> void:
	# 学习初始技能
	for ability_data in _initial_abilities:
		learn_ability(ability_data)
	# 启用 process 以更新技能内部状态（冷却、连击计时器等）
	set_process(true)

func _process(delta: float) -> void:
	# 统一调用所有技能的 update 方法（符合开闭原则）
	# 技能会在自己的 update 中管理冷却时间，并在冷却完成时发出信号
	for ability_id in _learned_abilities:
		var ability_data = _learned_abilities[ability_id]
		if is_instance_valid(ability_data):
			ability_data.update(delta)
#endregion

#region ========== 公共API - 技能管理 ==========
## 学习技能
## [param] ability_data: GameplayAbility 技能数据
func learn_ability(ability_data: GameplayAbility) -> void:
	if not is_instance_valid(ability_data):
		return
	
	var ability_id := ability_data.ability_id
	if _learned_abilities.has(ability_id):
		# 已经学会
		return
	
	var learned_ability = ability_data.duplicate()
	_learned_abilities[ability_id] = learned_ability
	
	# 订阅技能完成信号
	if not learned_ability.ability_completed.is_connected(_on_ability_completed):
		learned_ability.ability_completed.connect(_on_ability_completed)
	
	# 订阅技能冷却就绪信号
	if not learned_ability.cooldown_ready.is_connected(_on_ability_cooldown_ready):
		learned_ability.cooldown_ready.connect(_on_ability_cooldown_ready)
	
	# 检查并应用被动技能效果
	if is_instance_valid(_status_comp):
		learned_ability.handle_learned(self, _status_comp)
	
	ability_learned.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_learned", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 遗忘技能
## [param] ability_id: StringName 技能ID
func forget_ability(ability_id: StringName) -> void:
	if not _learned_abilities.has(ability_id):
		return
	
	var ability_data = _learned_abilities[ability_id]
	_learned_abilities.erase(ability_id)
	
	# 取消订阅信号
	if is_instance_valid(ability_data):
		if ability_data.ability_completed.is_connected(_on_ability_completed):
			ability_data.ability_completed.disconnect(_on_ability_completed)
		if ability_data.cooldown_ready.is_connected(_on_ability_cooldown_ready):
			ability_data.cooldown_ready.disconnect(_on_ability_cooldown_ready)
		
		# 移除被动技能效果
		if is_instance_valid(_status_comp):
			ability_data.handle_forgotten(self, _status_comp)
	
	ability_forgotten.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_forgotten", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 禁用技能
## [param] ability_id: StringName 技能ID
func disable_ability(ability_id: StringName) -> void:
	var ability_data = get_ability_data(ability_id)
	if is_instance_valid(ability_data):
		ability_data.disabled = true

## 启用技能
## [param] ability_id: StringName 技能ID
func enable_ability(ability_id: StringName) -> void:
	var ability_data = get_ability_data(ability_id)
	if is_instance_valid(ability_data):
		ability_data.disabled = false
#endregion

#region ========== 公共API - 技能执行 ==========
## 检查是否可以施法
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息
## [return] bool 是否可以施法
func can_cast(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		push_error("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return false
	
	if ability_data.disabled:
		return false
	
	# 【关键】如果技能正在执行，让技能自己判断是否可以继续/关闭（符合开闭原则）
	# 这适用于所有技能类型：
	# - ToggleAbility：会在 can_cast 中处理切换逻辑
	# - CombatAbility：会在 can_cast 中检查连击窗口，决定是否可以继续连击
	# - ChannelingAbility：会在 can_cast 中处理切换逻辑
	if _current_casting_ability_id == ability_id:
		return ability_data.can_cast(self, target, context)
	
	if not is_cooldown_ready(ability_id):
		return false
	
	return ability_data.can_cast(self, target, context)

## 提交施法（消耗资源，让技能进入冷却）
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息
## [return] bool 是否成功提交
func commit_cast(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		push_error("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return false
	
	# 处理连击技能的特殊逻辑
	if ability_data is CombatAbility:
		var combat_ability = ability_data as CombatAbility
		# 检查连击窗口是否还在有效期内
		if combat_ability._combo_reset_timer >= combat_ability._combo_reset_time:
			# 连击窗口已超时，重置连击索引
			combat_ability._reset_combo()
		# 连击窗口检查通过，继续执行后续逻辑（检查消耗、冷却等）
		# 注意：不检查 _current_casting_ability_id，因为连击系统不占用该变量
	else:
		# 非连击技能：检查是否正在执行
		if ability_id == _current_casting_ability_id:
			# 检查是否是可切换技能
			if ability_data.is_toggleable():
				# 可切换技能：交由技能自身处理切换逻辑
				var result = ability_data.commit_cast(self, context)
				if not result:
					push_warning("GameplayAbilityComponent: Ability %s toggle-off rejected." % ability_id)
				return result
			else:
				# 非可切换技能：直接拒绝重复施放
				push_warning("GameplayAbilityComponent: Ability %s is already executing, cannot cast again." % ability_id)
				return false
		
		# 检查可切换技能是否已经开启（即使 _current_casting_ability_id 被清除）
		if ability_data.is_toggleable():
			if ability_data.has_method("is_toggled_on") and ability_data.is_toggled_on():
				# 可切换技能已经开启，交由技能自身处理切换逻辑
				var result = ability_data.commit_cast(self, context)
				if not result:
					push_warning("GameplayAbilityComponent: Ability %s toggle-off rejected." % ability_id)
				return result
	
	# 【Modifier 钩子】施法前通知
	var modifier_comp: GameplayModifierComponent = GameplayAbilitySystem.get_component_by_interface(
		get_parent(),
		"GameplayModifierComponent"
	)
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_before_ability_cast(self, ability_data, context)
	
	# 正常执行技能：检查消耗
	if not ability_data.commit_cast(self, context):
		push_error("GameplayAbilityComponent: Ability %s commit cast failed." % ability_id)
		return false
	
	# 【Modifier 钩子】施法成功后通知
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_after_ability_commit(self, ability_data, context)
	
	# 检查是否跳过冷却（用于技能链式调用）
	if not context.get("skip_cooldown", false):
		if not ability_data.is_cooldown_ready():
			return false
		
		# 获取冷却时间（使用方法，支持 CombatAbility 重写）
		var cooldown = ability_data.get_cooldown_duration()
		
		# 应用冷却缩减（如果 Modifier 提供了）
		var cooldown_reduction = context.get("cooldown_reduction", 0.0)
		if cooldown_reduction > 0.0:
			cooldown = cooldown * (1.0 - cooldown_reduction)
			cooldown = max(0.0, cooldown)  # 确保冷却时间不为负
		
		if cooldown > 0.0:
			ability_data.start_cooldown(cooldown)
	
	# 设置当前正在执行的技能
	_current_casting_ability_id = ability_id
	can_interrupt_current = false  # 技能刚开始，不可中断（前摇锁死）
	
	# 触发表现层（播放动画）
	ability_cast.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_cast", {
		"entity": get_parent(),
		"ability_id": ability_id,
	})
	
	# 获取前摇时间（cast_point）
	var cast_point_time = ability_data.get_cast_point()
	
	# 分支：瞬发 vs 延迟生效
	# 检查是否跳过逻辑计时器（用于引导技能等自己管理生命周期的技能）
	if context.get("skip_cast_point_timer", false):
		# 跳过计时器，直接应用效果（引导技能自己管理生命周期）
		_apply_ability_effect(ability_id, target, context)
	elif cast_point_time <= 0.001:
		# 瞬发：直接生效
		_apply_ability_effect(ability_id, target, context)
	else:
		# 延迟生效：启动逻辑计时器
		_start_cast_point_timer(ability_id, cast_point_time, target, context)
	
	return true

## 强制中断当前技能
## [param] ability_id: StringName 技能ID（可选，如果不提供则取消当前执行的技能）
## [param] context: Dictionary 上下文信息（可选，传递给技能的 on_cancel 方法）
func cancel_ability(ability_id: StringName = &"", context: Dictionary = {}) -> void:
	var target_id = ability_id
	if target_id.is_empty():
		target_id = _current_casting_ability_id
	
	if target_id.is_empty():
		return
	
	# 【关键】只要被打断，立即销毁计时器 -> 伤害永远不会打出来！
	_cancel_cast_timer(target_id)
	
	var ability_data = get_ability_data(target_id)
	if not is_instance_valid(ability_data):
		return
	
	# 调用技能的取消方法（允许技能自己处理清理逻辑，包括状态移除）
	ability_data.handle_cancel(self, context)
	
	# 强制重置状态
	if _current_casting_ability_id == target_id:
		_clear_current_casting_ability()
	
	AbilityEventBus.trigger_game_event(&"ability_cancelled", {"ability_id": target_id})
#endregion

#region ========== 公共API - 技能查询 ==========
## 获取技能数据
## [param] ability_id: StringName 技能ID
## [return] GameplayAbility 技能数据，如果不存在则返回 null
func get_ability_data(ability_id: StringName) -> GameplayAbility:
	if not _learned_abilities.has(ability_id):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return null
	return _learned_abilities[ability_id]

## 获取所有已学会的技能
## [return] Array[GameplayAbility] 技能数组
func get_all_abilities() -> Array[GameplayAbility]:
	return _learned_abilities.values()

## 获取所有已学会的技能字典
## [return] Dictionary[StringName, GameplayAbility] 技能字典
func get_all_learned_abilities() -> Dictionary:
	return _learned_abilities.duplicate()
#endregion

#region ========== 公共API - 技能状态 ==========
## 检查冷却是否就绪
## [param] ability_id: StringName 技能ID
## [return] bool 是否冷却就绪
func is_cooldown_ready(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return true
	return ability_data.is_cooldown_ready()

## 获取冷却进度（0.0-1.0，0.0 表示冷却完成，1.0 表示刚开始冷却）
## [param] ability_id: StringName 技能ID
## [return] float 冷却进度
func get_cooldown_progress(ability_id: StringName) -> float:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return 0.0
	return ability_data.get_cooldown_progress()

## 获取当前正在执行的技能ID
## [return] StringName 当前执行的技能ID，如果为空则表示没有正在执行的技能
func get_current_casting_ability_id() -> StringName:
	return _current_casting_ability_id

## 检查是否有正在执行的技能
## [return] bool 是否有正在执行的技能
func has_casting_ability() -> bool:
	return not _current_casting_ability_id.is_empty()

## 设置是否允许中断当前攻击（由 VisualAdapter 调用）
## [param] can_interrupt: bool 是否允许中断
func set_can_interrupt(can_interrupt: bool) -> void:
	can_interrupt_current = can_interrupt

## 检查是否可以中断当前攻击
## [return] bool 是否可以中断
func can_interrupt() -> bool:
	return can_interrupt_current

## 检查是否正在自动施法
## [param] ability_id: StringName 技能ID
## [return] bool 是否正在自动施法
func is_autocast_active(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return false
	return ability_data.is_autocast()

## 检查是否可以自动施法
## [param] ability_id: StringName 技能ID
## [return] bool 是否可以自动施法
func can_autocast(ability_id: StringName) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return false
	return ability_data.can_autocast()
#endregion

#region ========== 内部方法（供技能系统内部使用） ==========
## 应用技能效果（内部方法，供 commit_cast 和计时器回调使用）
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息
func _apply_ability_effect(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		push_error("GameplayAbilityComponent: Ability data is not valid")
		return
	
	# 【Modifier 钩子】技能真正生效前通知（修改参数的最佳时机）
	var modifier_comp: GameplayModifierComponent = GameplayAbilitySystem.get_component_by_interface(
		get_parent(),
		"GameplayModifierComponent"
	)
	
	# 将 ability 和 ability_comp 添加到 context，供 Modifier 使用（如 DamageMultiplierModifier）
	context["ability"] = ability_data
	context["ability_comp"] = self
	
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_before_apply_ability(self, ability_data, target, context)
	
	# 订阅技能完成信号（如果尚未订阅）
	if not ability_data.ability_completed.is_connected(_on_ability_completed):
		ability_data.ability_completed.connect(_on_ability_completed)
	
	# 执行技能
	ability_data.cast(self, target, context)

## 清除当前正在执行的技能（在技能完全结束时调用）
func _clear_current_casting_ability() -> void:
	_current_casting_ability_id = &""
	can_interrupt_current = false
#endregion

#region ========== 私有方法 - 计时器管理 ==========
## 启动前摇计时器（逻辑驱动）
## [param] ability_id: StringName 技能ID
## [param] time: float 前摇时间
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息
func _start_cast_point_timer(ability_id: StringName, time: float, target: Node, context: Dictionary) -> void:
	# 先清理旧的（防止快速连点）
	_cancel_cast_timer(ability_id)
	
	# 存储上下文（供计时器回调使用）
	_cast_contexts[ability_id] = {
		"target": target,
		"context": context
	}
	
	# 创建计时器
	var timer = get_tree().create_timer(time)
	_cast_point_timers[ability_id] = timer
	
	# 计时结束 -> 触发效果
	timer.timeout.connect(func() -> void:
		# 双重检查：确保没有被取消
		if _cast_point_timers.has(ability_id) and _cast_point_timers[ability_id] == timer:
			var saved_context = _cast_contexts.get(ability_id, {})
			var saved_target = saved_context.get("target", null)
			var saved_context_dict = saved_context.get("context", {})
			
			# 应用技能效果
			_apply_ability_effect(ability_id, saved_target, saved_context_dict)
			
			# 清理
			_cast_point_timers.erase(ability_id)
			_cast_contexts.erase(ability_id)
	)

## 取消施法计时器
## [param] ability_id: StringName 技能ID
func _cancel_cast_timer(ability_id: StringName) -> void:
	if _cast_point_timers.has(ability_id):
		# SceneTreeTimer 无法手动 stop，但我们可以从字典移除它
		# timeout 回调里的 check 会让它失效
		_cast_point_timers.erase(ability_id)
		_cast_contexts.erase(ability_id)
#endregion

#region ========== 私有方法 - 事件回调 ==========
## 处理技能完成信号（由 Ability 发出）
## [param] ability: GameplayAbility 完成的技能实例
func _on_ability_completed(ability: GameplayAbility) -> void:
	if not is_instance_valid(ability):
		return
	
	var ability_id = ability.ability_id
	
	# 检查是否是临时订阅（链式调用未学习的技能）
	# 如果是临时订阅，需要断开连接
	var is_learned = _learned_abilities.has(ability_id)
	if not is_learned:
		if ability.ability_completed.is_connected(_on_ability_completed):
			ability.ability_completed.disconnect(_on_ability_completed)
		if ability.cooldown_ready.is_connected(_on_ability_cooldown_ready):
			ability.cooldown_ready.disconnect(_on_ability_cooldown_ready)
	
	# 只有当前正在执行的技能才需要结束
	if _current_casting_ability_id != ability_id:
		return
	
	# 结束技能
	if _current_casting_ability_id == ability_id:
		# 技能逻辑完成，进入后摇阶段，允许中断
		can_interrupt_current = true
		
		ability_completed.emit(ability_id)
		AbilityEventBus.trigger_game_event(&"ability_completed", {
			"entity": get_parent(),
			"ability_id": ability_id
		})
		
		# 【关键】连击系统与 _current_casting_ability_id 解耦
		# 连击技能的子技能完成后会立即清理 _current_casting_ability_id
		# 连击窗口通过 CombatAbility 自己的状态（_current_combo_index 和 _combo_reset_timer）管理
		# 所有技能完成后都立即清理占用标记
		_clear_current_casting_ability()

## 处理技能冷却就绪信号（由 Ability 发出）
## [param] ability: GameplayAbility 冷却完成的技能实例
func _on_ability_cooldown_ready(ability: GameplayAbility) -> void:
	if not is_instance_valid(ability):
		return
	
	var ability_id = ability.ability_id
	
	# 转发冷却就绪信号
	cooldown_ready.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_cooldown_ready", {
		"entity": get_parent(),
		"ability_id": ability_id
	})
#endregion
