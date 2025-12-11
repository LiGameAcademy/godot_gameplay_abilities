@abstract
extends Resource
class_name GameplayAbility

## 技能数据基类（抽象类）
## 定义技能的所有属性和行为

@export var ability_id: StringName                  ## 技能的唯一ID
@export var ability_name: String                    ## 技能名称
@export_multiline var description: String           ## 技能描述
@export var _icon: Texture                         	## 技能图标
@export var tags: Array[StringName] = []            ## 技能标签
@export var disabled: bool = false                  ## 技能是否禁用
@export var targeting_scorer: TargetingScorer = null   ## 目标评分器

@export_group("Effects")
## 技能直接应用的效果（组合模式）
## 这些效果会立即应用到目标，不需要通过状态
@export var effects: Array[GameplayEffect] = []

@export_group("Status (Optional)")
## 技能应用的状态（可选，用于需要持续时间的 Buff/Debuff）
## 如果同时设置了 effects 和 status_to_apply，两者都会生效
@export var status_to_apply: GameplayStatusData = null

## 运行时 Effect 列表（用于跟踪所有 Effect，等待它们完成）
## 格式：{effect_instance: true}
var _pending_effects: Dictionary = {}

## 技能完成信号
## 当所有 Effect 完成时，会发出此信号
## Component 会订阅此信号来判断技能是否完成
signal ability_completed(ability: GameplayAbility)

## 处理技能学习事件
## 当技能被学习时，由 GameplayAbilityComponent 调用此方法
func handle_learned(ability_comp: Node, status_comp: Node) -> void:
	_on_learned(ability_comp, status_comp)

## 处理技能遗忘事件
## 当技能被遗忘时，由 GameplayAbilityComponent 调用此方法
func handle_forgotten(ability_comp: Node, status_comp: Node) -> void:
	_on_forgotten(ability_comp, status_comp)

## 检查是否可以施法
func can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool:
	return _can_cast(ability_comp, target, context)

## 提交施法（消耗资源、开始冷却等）
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 上下文信息（可选，可包含 skip_cost 等标志）
func commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	return _commit_cast(ability_comp, context)

## 施放技能（应用效果）
## [param] ability_comp: Node 技能组件
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息（可选）
func cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void:
	# 清理之前的 Effect（防止重复）
	_clear_effects()
	_on_cast(ability_comp, target, context)

## [子类可重写] 每帧更新（用于需要持续更新的技能，如连击计时器、引导技能）
## [param] delta: float 帧时间
func update(_delta: float) -> void: pass

## [子类可重写] 技能被取消时的处理
## 当技能被主动取消时（如被打断、资源不足等），由 GameplayAbilityComponent 调用此方法
## [param] ability_comp: Node 技能组件
## [param] context: Dictionary 上下文信息（可选）
func handle_cancel(ability_comp: Node, context: Dictionary = {}) -> void:
	_on_cancel(ability_comp, context)

## 获取效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	for effect in effects:
		if is_instance_valid(effect):
			descriptions.append(effect.get_description())
	if is_instance_valid(status_to_apply):
		descriptions.append("Apply status: %s" % status_to_apply.status_display_name)
	return "\n".join(descriptions)

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_costs_description() -> String:
	# 由子类实现
	return ""

## 清除施法效果
func clear_cast(ability_comp: Node, target: Node) -> void:
	_clear_cast(ability_comp, target)

## 是否可以自动施法
func can_autocast() -> bool:
	return false

## 是否正在自动施法
func is_autocast() -> bool:
	return false

## 获取施法前摇时间
func get_cast_point() -> float:
	return 0.0

## 获取技能图标
## [param] ability_comp: Node 技能组件（可选，用于动态图标）
## [return] Texture 技能图标
func get_icon(ability_comp: Node = null) -> Texture:
	return _icon

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

## 订阅 Effect 完成信号（由 Ability 自己管理）
## [param] effect: GameplayEffect 要订阅的效果实例
func _subscribe_effect_completion(effect: GameplayEffect) -> void:
	if not is_instance_valid(effect):
		return
	
	# 如果已经订阅过，跳过
	if _pending_effects.has(effect):
		return
	
	# 添加到 Effect 列表
	_pending_effects[effect] = true
	
	# 订阅完成信号
	# 注意：信号已经传递了 effect 参数，不需要 bind
	if not effect.effect_completed.is_connected(_on_effect_completed):
		effect.effect_completed.connect(_on_effect_completed)

## 检查技能是否完成（所有 Effect 都完成时调用）
func _check_ability_completion() -> void:
	# 如果还有 Effect，不完成
	if not _pending_effects.is_empty():
		return
	
	# 发出技能完成信号
	ability_completed.emit(self)

## 清理所有 Effect 订阅（技能取消或结束时调用）
func _clear_effects() -> void:
	for effect in _pending_effects.keys():
		if is_instance_valid(effect) and effect.effect_completed.is_connected(_on_effect_completed):
			effect.effect_completed.disconnect(_on_effect_completed)
	_pending_effects.clear()

## [子类必须重写] 施放技能（应用效果）
## 这是技能系统的核心方法，所有子类都必须实现
@abstract func _on_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void

## [子类可重写] 技能学习时的处理
## 默认实现为空，子类可按需重写（如 PassiveAbility 需要应用状态）
func _on_learned(_ability_comp: Node, _status_comp: Node) -> void: pass

## [子类可重写] 技能遗忘时的处理
## 默认实现为空，子类可按需重写（如 PassiveAbility 需要移除状态）
func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void: pass

## [子类可重写] 检查是否可以施法
## 默认返回 true，子类应重写此方法以实现具体的施法条件检查
func _can_cast(_ability_comp: Node, _target: Node, _context: Dictionary = {}) -> bool: return true

## [子类可重写] 提交施法（消耗资源、开始冷却等）
## 默认返回 true，子类应重写此方法以实现具体的资源消耗逻辑
func _commit_cast(_ability_comp: Node, _context: Dictionary = {}) -> bool: return true

## [子类可重写] 清除施法效果
## 默认实现为空，子类可按需重写（如需要移除持续效果）
func _clear_cast(_ability_comp: Node, _target: Node) -> void: pass

## [子类可重写] 技能被取消时的处理
## 默认实现为空，子类可按需重写（如需要清理持续效果、停止计时器等）
func _on_cancel(ability_comp: Node, context: Dictionary = {}) -> void:
	# 清理 Effect 订阅
	_clear_effects()

## 处理 Effect 完成信号
## [param] effect: GameplayEffect 完成的效果实例
func _on_effect_completed(effect: GameplayEffect) -> void:
	if not _pending_effects.has(effect):
		return
	
	# 从 Effect 列表中移除
	_pending_effects.erase(effect)
	
	# 断开信号连接
	if is_instance_valid(effect) and effect.effect_completed.is_connected(_on_effect_completed):
		effect.effect_completed.disconnect(_on_effect_completed)
	
	# 检查是否所有 Effect 都完成了
	_check_ability_completion()
