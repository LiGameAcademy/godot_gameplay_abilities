extends Node
class_name GameplayAbilityComponent

## 技能组件 (GAS 核心容器)
## 
## 职责：
## 1. 充当技能实例的"容器"和"工厂"。
## 2. 调度 Update 循环，仅驱动活跃的技能。
## 3. 处理技能之间的互斥/打断逻辑 (通过 Tags 或简单 ID 互斥)。

#region ========== 属性定义 ==========
@export_group("Initialization")
## 初始技能列表（在 _ready 时自动学习）
@export var _initial_abilities: Array[GameplayAbilityDefinition] = []

@export_group("Components")
## 状态组件（用于应用/移除被动技能效果）
@export var _status_comp: GameplayStatusComponent = null

## 已学会的技能字典（运行时数据）
var _learned_abilities: Dictionary[StringName, GameplayAbilityInstance] = {}

## 当前正在执行的技能ID（用于后摇可取消机制）
var _current_casting_ability: GameplayAbilityInstance = null

#endregion

#region ========== 信号定义 ==========
signal ability_learned(ability: GameplayAbilityInstance)				## 技能学会信号
signal ability_forgotten(ability_id: StringName)						## 技能遗忘信号
signal ability_activated(ability: GameplayAbilityInstance)				## 技能激活信号
signal ability_completed(ability: GameplayAbilityInstance)				## 技能完成信号（所有逻辑执行完毕，进入后摇阶段）
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
	# 技能会在自己的 update 中管理冷却时间
	for ability_id in _learned_abilities:
		var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
		if not is_instance_valid(ability_instance):
			continue
	
		# 更新技能（包括冷却时间）
		ability_instance.update(delta)
	
#endregion

#region ========== 公共API - 技能管理 ==========
## 学习技能
## [param] ability_data: GameplayAbility 技能数据
func learn_ability(ability_data: GameplayAbilityDefinition) -> void:
	if not is_instance_valid(ability_data):
		push_error("GameplayAbilityComponent: Ability data is not valid")
		return
	
	var ability_id := ability_data.ability_id
	if _learned_abilities.has(ability_id):
		# 已经学会
		push_warning("GameplayAbilityComponent: Ability %s already learned." % ability_id)
		return
	
	var learned_ability : GameplayAbilityInstance = ability_data.create_instance(get_parent())
	if not is_instance_valid(learned_ability):
		push_error("GameplayAbilityComponent: Ability %s create instance failed." % ability_id)
		return
	_learned_abilities[ability_id] = learned_ability
	
	# 订阅技能完成信号
	if not learned_ability.ability_completed.is_connected(_on_ability_completed):
		learned_ability.ability_completed.connect(_on_ability_completed)
	
	# 检查并应用被动技能效果
	if is_instance_valid(_status_comp):
		learned_ability.handle_learned(self, _status_comp)
	else:
		push_warning("GameplayAbilityComponent: Status component is not valid, cannot apply passive skills.")
	
	ability_learned.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_learned", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 遗忘技能
## [param] ability_id: StringName 技能ID
func forget_ability(ability_id: StringName) -> void:
	if not _learned_abilities.has(ability_id):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return
	
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	
	# 取消订阅信号
	if is_instance_valid(ability_instance):
		if ability_instance.ability_completed.is_connected(_on_ability_completed):
			ability_instance.ability_completed.disconnect(_on_ability_completed)
		
		# 移除被动技能效果
		if is_instance_valid(_status_comp):
			ability_instance.handle_forgotten(self, _status_comp)
	else:
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return
	
	_learned_abilities.erase(ability_id)
	
	ability_forgotten.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_forgotten", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 禁用技能
## [param] ability_id: StringName 技能ID
func disable_ability(ability_id: StringName) -> void:
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	if is_instance_valid(ability_instance):
		ability_instance.disabled = true
	else:
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return

## 启用技能
## [param] ability_id: StringName 技能ID
func enable_ability(ability_id: StringName) -> void:
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	if is_instance_valid(ability_instance):
		ability_instance.disabled = false
	else:
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return

## 获取技能实例
## [param] ability_id: StringName 技能ID
## [return] GameplayAbilityInstance 技能实例，如果不存在则返回 null
func get_ability_instance(ability_id: StringName) -> GameplayAbilityInstance:
	return _learned_abilities[ability_id]

## 获取所有技能实例
## [return] Array[GameplayAbilityInstance] 技能实例数组
func get_all_ability_instances() -> Dictionary[StringName, GameplayAbilityInstance]:
	return _learned_abilities

#endregion

#region ========== 公共API - 技能执行 ==========
## 检查是否可以施法
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
## [return] bool 是否可以施法
func can_activate_ability(ability_id: StringName, context: Variant = {}) -> bool:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_error("GameplayAbilityComponent: Ability instance is not valid.")
		return false
	
	if ability_instance.disabled:
		return false
	
	context.ability_comp = self
	return ability_instance.can_activate(context)

## 提交施法（消耗资源等）
## 注意：冷却相关逻辑由 ActiveAbility 自己处理，Component 不涉及冷却
## [param] ability_id: StringName 技能ID
## [param] target: Node 目标节点
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
## [return] bool 是否成功提交
func try_activate_ability(ability_id: StringName, context: Variant = {}) -> bool:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_error("GameplayAbilityComponent: Ability instance is not valid.")
		return false
	
	var ctx = ContextUtils.to_context(context)
	
	# 设置上下文的基础信息
	ctx.ability = ability_instance
	ctx.ability_comp = self
	ctx.ability_id = ability_instance.get_definition().ability_id
	ctx.instigator = get_parent()
	ctx.input_target = ctx.input_target

	# 【Modifier 钩子】施法前通知
	var modifier_comp: GameplayModifierComponent = GameplayAbilitySystem.get_component_by_interface(
		get_parent(),
		"GameplayModifierComponent"
	)
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_before_ability_cast(self, ability_instance, ctx)
	
	# 正常执行技能：检查消耗和冷却（由 Ability 自己处理）
	# 注意：冷却检查、冷却时间计算、冷却缩减应用都由 ActiveAbility._commit_cast() 处理
	if not ability_instance.try_activate(ctx):
		push_error("GameplayAbilityComponent: Ability %s try activate failed." % ability_instance.get_definition().ability_id)
		return false
	
	# 【Modifier 钩子】施法成功后通知
	if is_instance_valid(modifier_comp):
		modifier_comp.notify_after_ability_commit(self, ability_instance, ctx)
	
	# 设置当前正在执行的技能
	_current_casting_ability = ability_instance
	
	# 触发表现层（播放动画）
	ability_activated.emit(ability_instance)
	AbilityEventBus.trigger_game_event(&"ability_activated", {
		"entity": get_parent(),
		"ability_id": ability_instance.get_definition().ability_id,
	})
	
	# 订阅技能完成信号（如果尚未订阅）
	if not ability_instance.ability_completed.is_connected(_on_ability_completed):
		ability_instance.ability_completed.connect(_on_ability_completed)
	
	return true

## 强制中断当前技能（任何阶段都可以中断）
## 注意：这与后摇取消（can_interrupt）不同，强制中断可以在前摇阶段执行
## 但需要技能允许强制中断（can_be_force_cancelled = true）
## [param] ability_id: StringName 技能ID（可选，如果不提供则取消当前执行的技能）
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func cancel_ability(ability_id: StringName = &"", context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	var target_id = ability_id
	if target_id.is_empty():
		target_id = _current_casting_ability
	
	if target_id.is_empty():
		return
	
	var ability_instance = get_ability_instance(target_id)
	if not is_instance_valid(ability_instance):
		return
	
	ability_instance.end_ability(BTNode.Status.FAILURE)
	
	AbilityEventBus.trigger_game_event(&"ability_cancelled", {"ability_id": ability_instance.get_definition().ability_id})
#endregion

#region ========== 私有方法 - 事件回调 ==========
## 处理技能完成信号（由 Ability 发出）
## [param] ability: GameplayAbility 完成的技能实例
func _on_ability_completed(ability: GameplayAbilityInstance) -> void:
	if not is_instance_valid(ability):
		return
	
	# 只有当前正在执行的技能才需要结束
	if _current_casting_ability != ability:
		return
	
	var ability_id = ability.get_definition().ability_id
	
	# 检查是否是临时订阅（链式调用未学习的技能）
	# 如果是临时订阅，需要断开连接
	var is_learned = _learned_abilities.has(ability.get_definition().ability_id)
	if not is_learned:
		if ability.ability_completed.is_connected(_on_ability_completed):
			ability.ability_completed.disconnect(_on_ability_completed)
	
	# 结束技能
	if _current_casting_ability == ability:
		ability_completed.emit(ability.get_definition().ability_id)
		AbilityEventBus.trigger_game_event(&"ability_completed", {
			"entity": get_parent(),
			"ability_id": ability.get_definition().ability_id
		})
#endregion
