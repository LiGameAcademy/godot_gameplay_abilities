extends Node
class_name GameplayAbilityComponent

## 技能组件（采用鸭子类型设计，不继承基类）
## 管理实体的技能、法力、冷却等

@export var _initial_abilities: Array[GameplayAbility] = []  ## 初始技能列表
@export var _status_comp: GameplayStatusComponent = null  ## 状态组件
@export var _attribute_comp: GameplayVitalAttributeComponent = null  ## 属性组件

## 冷却时间管理已移至技能自身的 update() 方法中，不再需要统一管理
var _cast_point_timers: Dictionary[StringName, SceneTreeTimer] = {}  ## 施法前摇计时器（逻辑驱动）
var _cast_contexts: Dictionary[StringName, Dictionary] = {}  ## 存储施法上下文（target, context）
var _learned_abilities: Dictionary[StringName, GameplayAbility] = {}  ## 已学会的技能
## 当前正在执行的技能ID（用于后摇可取消机制）
var _current_casting_ability_id: StringName = &""
## 是否允许中断当前攻击（用于后摇取消机制）
var can_interrupt_current: bool = false

signal ability_learned(ability_id: StringName)				## 技能学会信号
signal ability_forgotten(ability_id: StringName)			## 技能遗忘信号
signal ability_cast(ability_id: StringName)					## 技能施放信号
signal ability_completed(ability_id: StringName)			## 技能完成信号（所有逻辑执行完毕，进入后摇阶段）
signal cooldown_ready(ability_id: StringName)				## 冷却就绪信号

func _ready() -> void:
	# 学习初始技能
	for ability_data in _initial_abilities:
		learn_ability(ability_data)
	# 启用 process 以更新连击计时器
	set_process(true)

## 每帧更新（更新所有技能的内部状态）
func _process(delta: float) -> void:
	# 统一调用所有技能的 update 方法（符合开闭原则）
	# 技能会在自己的 update 中管理冷却时间，并在冷却完成时发出信号
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
	
	var learned_ability = ability_data.duplicate()
	_learned_abilities[ability_id] = learned_ability
	
	# 订阅技能完成信号
	if not learned_ability.ability_completed.is_connected(_on_ability_completed):
		learned_ability.ability_completed.connect(_on_ability_completed)
	
	# 订阅技能冷却就绪信号
	if not learned_ability.cooldown_ready.is_connected(_on_ability_cooldown_ready):
		learned_ability.cooldown_ready.connect(_on_ability_cooldown_ready)
	
	# 冷却时间管理已移至技能自身的 update() 方法中
	
	# 检查并应用被动技能
	if is_instance_valid(_status_comp):
		learned_ability.handle_learned(self, _status_comp)
	
	ability_learned.emit(ability_id)
	# 触发统一游戏事件：ability_learned
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
	
	# 取消订阅技能完成信号
	if is_instance_valid(ability_data) and ability_data.ability_completed.is_connected(_on_ability_completed):
		ability_data.ability_completed.disconnect(_on_ability_completed)
	
	# 取消订阅技能冷却就绪信号
	if is_instance_valid(ability_data) and ability_data.cooldown_ready.is_connected(_on_ability_cooldown_ready):
		ability_data.cooldown_ready.disconnect(_on_ability_cooldown_ready)
	
	# 冷却时间管理已移至技能自身，无需清理
	
	# 移除被动技能效果
	if is_instance_valid(ability_data) and is_instance_valid(_status_comp):
		ability_data.handle_forgotten(self, _status_comp)
	
	ability_forgotten.emit(ability_id)
		# 触发统一游戏事件：ability_forgotten
	AbilityEventBus.trigger_game_event(&"ability_forgotten", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

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
	
	# 如果技能正在执行，让技能自己判断是否可以关闭（符合开闭原则）
	# ToggleAbility 会在 can_cast 中处理切换逻辑
	if _current_casting_ability_id == ability_id:
		# 直接调用 can_cast，让技能自己判断（ToggleAbility 会返回 true 如果可以关闭）
		return ability_data.can_cast(self, target, context)
	
	if not is_cooldown_ready(ability_id):
		return false  # 技能冷却中
	return ability_data.can_cast(self, target, context)

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

## 提交施法（消耗资源，让技能进入冷却）
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息
func commit_cast(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> bool:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		push_error("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return false
	
	# 检查技能是否正在执行
	if _current_casting_ability_id == ability_id:
		# 可切换技能：交由技能自身处理切换逻辑
		if ability_data.is_toggleable():
			var result = ability_data.commit_cast(self, context)
			if not result:
				push_warning("GameplayAbilityComponent: Ability %s toggle-off rejected." % ability_id)
			return result
		
		# 非可切换技能：直接拒绝重复施放，避免连击/引导类重复进入
		push_warning("GameplayAbilityComponent: Ability %s is already executing, cannot cast again." % ability_id)
		return false
	
	# 正常执行技能：检查消耗
	if not ability_data.commit_cast(self, context):
		push_error("GameplayAbilityComponent: Ability %s commit cast failed." % ability_id)
		return false

	# 检查是否跳过冷却（用于技能链式调用）
	if not context.get("skip_cooldown", false):
		if not ability_data.is_cooldown_ready():
			return false
		
		# 获取冷却时间（使用方法，支持 CombatAbility 重写）
		var cooldown = ability_data.get_cooldown_duration()
		if cooldown > 0.0:
			ability_data.start_cooldown(cooldown)

	# 设置当前正在执行的技能
	_current_casting_ability_id = ability_id
	can_interrupt_current = false  # 技能刚开始，不可中断（前摇锁死）
	
	# 1. 触发表现层（播放动画）
	ability_cast.emit(ability_id)
	# 触发统一游戏事件：ability_cast
	AbilityEventBus.trigger_game_event(&"ability_cast", {
		"entity": get_parent(),
		"ability_id": ability_id,
	})
	
	# 2. 【逻辑驱动】获取前摇时间（cast_point）
	var cast_point_time = ability_data.get_cast_point()
	
	# 3. 【分支】瞬发 vs 延迟生效
	if cast_point_time <= 0.001:
		# 瞬发：直接生效
		apply_ability_effect(ability_id, target, context)
	else:
		# 延迟生效：启动逻辑计时器
		_start_cast_point_timer(ability_id, cast_point_time, target, context)
	
	print("AbilityComponent: ability commit casted: %s (cast_point: %.3f)" % [ability_id, cast_point_time])
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
	
	# 订阅技能完成信号
	if not ability_data.ability_completed.is_connected(_on_ability_completed):
		ability_data.ability_completed.connect(_on_ability_completed)
	
	# 执行技能（Effect 会通过信号通知完成，Ability 会自己管理并发出完成信号）
	# 注意：信号已在 learn_ability 时订阅，无需重复订阅
	ability_data.cast(self, target, context)

## 直接执行技能（不检查冷却、消耗，不触发信号）
## 用于技能链式调用（如投射物触发魔法阵）
## [param] ability_data: GameplayAbility 技能数据（可以是未学会的技能）
## [param] target: Node 目标
## [param] context: Dictionary 上下文信息（可包含 skip_cooldown、skip_cost 等标志）
func execute_ability_direct(ability_data: GameplayAbility, target: Node = null, context: Dictionary = {}) -> void:
	if not is_instance_valid(ability_data):
		push_error("GameplayAbilityComponent: Ability data is not valid")
		return
	
	# 直接执行技能效果，跳过 commit_cast（冷却、消耗已在 context 中标记跳过）
	# 注意：如果是已学习的技能，信号已在 learn_ability 时订阅
	# 如果是未学习的技能（链式调用），需要临时订阅，完成后在 _on_ability_completed 中判断并断开
	var needs_temp_subscription = not ability_data.ability_completed.is_connected(_on_ability_completed)
	if needs_temp_subscription:
		ability_data.ability_completed.connect(_on_ability_completed)
		# 标记为临时订阅，完成后断开
		context["_temp_signal_subscription"] = true
	
	ability_data.cast(self, target, context)

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
	
	# 调用技能的取消方法（允许技能自己处理清理逻辑）
	# 注意：已学习技能的信号连接不应断开，只有在 forget_ability 时才断开
	ability_data.handle_cancel(self, context)
	
	# 获取目标（假设是对自己释放，如果是对敌人需要记录目标）
	var instigator = get_parent()
	if not is_instance_valid(instigator):
		return
	
	# 调用所有效果的 remove 方法（这会触发持续效果的清理，如停止 Tween）
	for effect in ability_data.effects:
		if is_instance_valid(effect):
			effect.remove(instigator, instigator)
	
	# 强制重置状态
	if _current_casting_ability_id == target_id:
		clear_current_casting_ability()
	
	print("GameplayAbilityComponent: Ability cancelled: ", target_id)
	
	# 发送中断信号（如果组件有 gameplay_event 信号）
	if has_signal("gameplay_event"):
		emit_signal("gameplay_event", &"ability_cancelled", {"ability_id": target_id})

## 获取技能数据
## [param] ability_id: StringName 技能ID
func get_ability_data(ability_id: StringName) -> GameplayAbility:
	if not _learned_abilities.has(ability_id):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return null
	return _learned_abilities[ability_id]

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

## 清除技能效果
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
func clear_ability_effect(ability_id: StringName, target: Node) -> void:
	var ability_data = get_ability_data(ability_id)
	if not is_instance_valid(ability_data): 
		return
	
	ability_data.clear_cast(self, target)

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

## 检查冷却是否就绪
## [param] ability_id: StringName 技能ID
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

## 清除当前正在执行的技能（在技能完全结束时调用）
func clear_current_casting_ability() -> void:
	_current_casting_ability_id = &""
	can_interrupt_current = false

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
			apply_ability_effect(ability_id, saved_target, saved_context_dict)
			
			# 清理
			_cast_point_timers.erase(ability_id)
			_cast_contexts.erase(ability_id)
	)

## 冷却时间管理已移至技能自身的 update() 方法中，不再需要创建 Timer 节点

## 结束技能（内部方法）
## [param] ability_id: StringName 技能ID
func _end_ability(ability_id: StringName) -> void:
	if _current_casting_ability_id == ability_id:
		# 技能逻辑完成，进入后摇阶段，允许中断
		can_interrupt_current = true
		
		ability_completed.emit(ability_id)
		# 触发统一游戏事件：ability_completed
		AbilityEventBus.trigger_game_event(&"ability_completed", {
			"entity": get_parent(),
			"ability_id": ability_id
		})
		
		# 绝大多数主动技能在完成时应立即清理占用标记
		clear_current_casting_ability()

## 取消施法计时器
## [param] ability_id: StringName 技能ID
func _cancel_cast_timer(ability_id: StringName) -> void:
	if _cast_point_timers.has(ability_id):
		# SceneTreeTimer 无法手动 stop，但我们可以从字典移除它
		# timeout 回调里的 check 会让它失效
		_cast_point_timers.erase(ability_id)
		_cast_contexts.erase(ability_id)

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
	_end_ability(ability_id)

## 处理技能冷却就绪信号（由 Ability 发出）
## [param] ability: GameplayAbility 冷却完成的技能实例
func _on_ability_cooldown_ready(ability: GameplayAbility) -> void:
	if not is_instance_valid(ability):
		return
	
	var ability_id = ability.ability_id
	
	# 转发冷却就绪信号
	cooldown_ready.emit(ability_id)
	# 触发统一游戏事件：ability_cooldown_ready
	AbilityEventBus.trigger_game_event(&"ability_cooldown_ready", {
		"entity": get_parent(),
		"ability_id": ability_id
	})
