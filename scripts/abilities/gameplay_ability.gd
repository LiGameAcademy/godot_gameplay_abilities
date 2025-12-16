@abstract
extends Resource
class_name GameplayAbility

## 技能数据基类（抽象类）
## 定义技能的所有属性和行为

@export var ability_id: StringName                  	## 技能的唯一ID
@export var ability_name: String                    	## 技能名称
@export_multiline var description: String           	## 技能描述
@export var icon: Texture : get = _get_icon				## 技能图标
@export var tags: Array[StringName] = []            	## 技能标签
@export var disabled: bool = false                  	## 技能是否禁用
@export var targeting_scorer: TargetingScorer = null   	## 目标评分器

@export_group("Level System")
## 最大等级
@export var max_level: int = 10
## 当前等级（运行时）
var current_level: int = 1

@export_group("Status")
## 技能应用的状态列表（新架构）
## Status 系统会处理目标检测、筛选和应用效果
## 每个 Status 可以通过 target_mode 决定应用到自己、检测到的目标，或两者
## 适用：所有效果（瞬时、周期性、永久）
@export var statuses: Array[GameplayStatusData] = []

## 冷却剩余时间（秒，由技能自己管理）
var _cooldown_remaining: float = 0.0

## 技能完成信号
## 当所有 Status 完成时，会发出此信号
## Component 会订阅此信号来判断技能是否完成
signal ability_completed(ability: GameplayAbility)

## 冷却就绪信号
## 当冷却时间完成时，会发出此信号
## Component 会订阅此信号并转发
signal cooldown_ready(ability: GameplayAbility)

## 处理技能学习事件
## 当技能被学习时，由 GameplayAbilityComponent 调用此方法
func handle_learned(ability_comp: Node, status_comp: Node) -> void:
	_on_learned(ability_comp, status_comp)

## 处理技能遗忘事件
## 当技能被遗忘时，由 GameplayAbilityComponent 调用此方法
func handle_forgotten(ability_comp: Node, status_comp: Node) -> void:
	_on_forgotten(ability_comp, status_comp)

## 检查是否可以施法
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func can_cast(ability_comp: Node, target: Node, context: Variant = {}) -> bool:
	var ctx = ContextUtils.to_context(context)
	return _can_cast(ability_comp, target, ctx)

## 提交施法（消耗资源、开始冷却等）
## [param] ability_comp: Node 技能组件
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容，可包含 skip_cost 等标志）
func commit_cast(ability_comp: Node, context: Variant = {}) -> bool:
	var ctx = ContextUtils.to_context(context)
	return _commit_cast(ability_comp, ctx)

## 施放技能（应用效果）
## [param] ability_comp: Node 技能组件
## [param] target: Node 目标节点
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func cast(ability_comp: Node, target: Node, context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	_on_cast(ability_comp, target, ctx)

## [子类可重写] 每帧更新（用于需要持续更新的技能，如连击计时器、引导技能）
## [param] delta: float 帧时间
func update(delta: float) -> void:
	# 更新冷却时间
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			# 冷却完成，发出信号
			cooldown_ready.emit(self)

## [子类可重写] 技能被取消时的处理
## 当技能被主动取消时（如被打断、资源不足等），由 GameplayAbilityComponent 调用此方法
## [param] ability_comp: Node 技能组件
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
func handle_cancel(ability_comp: Node, context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	_on_cancel(ability_comp, ctx)

## 获取效果描述
func get_effects_description() -> String:
	return ""

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_costs_description() -> String:
	# 由子类实现
	return ""

## 清除施法效果
func clear_cast(ability_comp: Node, target: Node) -> void:
	_clear_cast(ability_comp, target)

## 获取施法前摇时间
func get_cast_point() -> float:
	return 0.0

## 获取施法距离
func get_cast_range() -> float:
	return 0.0

## 获取冷却时间
func get_cooldown_duration() -> float:
	return 0.0

func get_animation_name() -> StringName:
	return &""

## 是否为可切换技能（默认否，供外部避免类型判断）
func is_toggleable() -> bool:
	return false

## 检查冷却是否就绪
## [return] bool 冷却是否就绪
func is_cooldown_ready() -> bool:
	return _cooldown_remaining <= 0.0

## 开始冷却
## [param] duration: float 冷却持续时间（秒）
func start_cooldown(duration: float) -> void:
	if duration > 0.0:
		_cooldown_remaining = duration

## 获取冷却剩余时间
## [return] float 冷却剩余时间（秒）
func get_cooldown_remaining() -> float:
	return _cooldown_remaining

## 获取冷却进度（0.0-1.0，0.0 表示冷却完成，1.0 表示刚开始冷却）
## [return] float 冷却进度
func get_cooldown_progress() -> float:
	var total_cooldown = get_cooldown_duration()
	if total_cooldown <= 0.0:
		return 0.0
	return _cooldown_remaining / total_cooldown

## 设置技能等级
## [param] level: int 等级值
func set_level(level: int) -> void:
	current_level = clamp(level, 1, max_level)
	_on_level_changed()

## 等级改变时的回调（子类可重写）
## 当技能等级改变时，会调用此方法
## 子类可以重写此方法来实现等级相关的逻辑（如重新计算冷却、消耗等）
func _on_level_changed() -> void:
	pass

## 检查技能是否完成
func _check_ability_completion() -> void:
	# 发出技能完成信号
	ability_completed.emit(self)

## 应用状态到目标列表（私有辅助方法）
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（用于策略解析）
## [param] context: AbilityContext 上下文信息
## [param] targeting_strategy: TargetingStrategy 可选的目标获取策略（如果为 null，则应用到 instigator）
func _apply_statuses_to_targets(instigator: Node, input_target: Node, context: AbilityContext, targeting_strategy: TargetingStrategy = null) -> void:
	if not is_instance_valid(instigator) or statuses.is_empty():
		return
	
	# 准备状态上下文（复制上下文）
	var status_context = context.duplicate()
	status_context.input_target = input_target
	status_context.ability_id = ability_id
	
	# 获取目标列表（需要将 AbilityContext 转换为 Dictionary 传递给策略）
	var targets: Array[Node] = []
	if is_instance_valid(targeting_strategy):
		# 策略可能仍使用 Dictionary，转换后传递
		var strategy_context = status_context.to_dict()
		targets = targeting_strategy.resolve_targets(instigator, input_target, strategy_context)
	else:
		# 默认：只应用到施法者
		targets = [instigator]
	
	if targets.is_empty():
		return
	
	# 为所有目标应用状态
	for status_data in statuses:
		if not is_instance_valid(status_data):
			continue
		
		for target in targets:
			if not is_instance_valid(target):
				continue
			
			_apply_status_to_target(target, status_data, instigator, status_context)

## 应用单个状态到指定目标（私有辅助方法）
## [param] target: Node 目标实体
## [param] status_data: GameplayStatusData 状态数据
## [param] instigator: Node 施法者
## [param] context: AbilityContext 上下文信息
func _apply_status_to_target(target: Node, status_data: GameplayStatusData, instigator: Node, context: AbilityContext) -> void:
	if not is_instance_valid(status_data) or not is_instance_valid(target):
		return
	
	# 获取目标的状态组件
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		push_warning("GameplayAbility: Target %s has no GameplayStatusComponent, cannot apply status %s" % [target.name, status_data.status_id])
		return
	
	# 应用状态（状态组件可能仍使用 Dictionary，转换后传递）
	var status_dict = context.to_dict()
	status_comp.apply_status(status_data, instigator, 1, status_dict)

## 移除技能应用的所有状态（私有辅助方法）
## [param] entity: Node 实体（状态持有者）
## [param] status_comp: Node 状态组件
func _remove_all_statuses_from_entity(entity: Node, status_comp: Node) -> void:
	if not is_instance_valid(entity) or not is_instance_valid(status_comp):
		return
	
	if not status_comp.has_method("remove_status"):
		return
	
	# 遍历技能配置的所有状态，移除它们
	for status_data in statuses:
		if not is_instance_valid(status_data):
			continue
		var sid: StringName = status_data.status_id
		if not sid.is_empty():
			status_comp.remove_status(sid)

## 获取技能图标
## [param] ability_comp: Node 技能组件（可选，用于动态图标）
## [return] Texture 技能图标
func _get_icon() -> Texture:
	return icon

## [子类必须重写] 施放技能（应用效果）
## 这是技能系统的核心方法，所有子类都必须实现
## [param] context: AbilityContext 上下文信息
@abstract func _on_cast(ability_comp: Node, target: Node, context: AbilityContext) -> void

## [子类可重写] 技能学习时的处理
## 默认实现为空，子类可按需重写（如 PassiveAbility 需要应用状态）
func _on_learned(_ability_comp: Node, _status_comp: Node) -> void: pass

## [子类可重写] 技能遗忘时的处理
## 默认实现为空，子类可按需重写（如 PassiveAbility 需要移除状态）
func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void: pass

## [子类可重写] 检查是否可以施法
## 默认返回 true，子类应重写此方法以实现具体的施法条件检查
## [param] context: AbilityContext 上下文信息
func _can_cast(_ability_comp: Node, _target: Node, _context: Variant = {}) -> bool: return true

## [子类可重写] 提交施法（消耗资源、开始冷却等）
## 默认返回 true，子类应重写此方法以实现具体的资源消耗逻辑
## [param] context: AbilityContext 上下文信息
func _commit_cast(_ability_comp: Node, _context: AbilityContext) -> bool: return true

## [子类可重写] 清除施法效果
## 默认实现为空，子类可按需重写（如需要移除持续效果）
func _clear_cast(_ability_comp: Node, _target: Node) -> void: pass

## [子类可重写] 技能被取消时的处理
## 默认实现：清理 Status 订阅和移除技能应用的状态
## 子类可按需重写（如需要清理持续效果、停止计时器等），但应调用 super._on_cancel()
## [param] context: AbilityContext 上下文信息
func _on_cancel(ability_comp: Node, context: AbilityContext) -> void:
	# 移除由该技能应用的所有状态（新架构：技能通过 Status 系统应用效果）
	if is_instance_valid(ability_comp):
		var instigator = ability_comp.get_parent()
		if is_instance_valid(instigator):
			var status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
			if is_instance_valid(status_comp):
				_remove_all_statuses_from_entity(instigator, status_comp)
