@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现_apply和_remove方法

@export var filters: Array[GameplayFilterData] = [] 	## 过滤器，如果为空，则不过滤

## 子效果，支持效果组合
## 注意：
## - 常规 Effect（Primitive Effect）通常不使用此属性，保持单一职责
## - Meta Effect（元效果）使用此属性来协调其他 Effect 的执行
## - 如果 _should_auto_apply_sub_effects() 返回 true，基类会自动应用子效果到同一个 target
## - 如果返回 false，子类需要自己控制子效果的应用（如应用到不同目标）
@export var sub_effects : Array[GameplayEffect] = []

@export_group("Tag Requirements")
## 目标必须拥有的标签（效果生效的前置条件）
## 如果目标没有所有必需的标签，效果不会生效
@export var target_required_tags: Array[StringName] = []
## 目标不能拥有的标签（效果生效的阻止条件，如免疫）
## 如果目标拥有任意一个阻止标签，效果不会生效
@export var target_blocked_tags: Array[StringName] = []

@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当效果应用成功时，会执行此 Cue 来播放表现（特效、音效、飘字等）
@export var cue: GameplayCue = null

# 标记是否已由子类处理信号发射（异步效果使用）
var _signal_handled_by_subclass: bool = false

## 效果完成信号
## 所有效果完成时都会发出此信号
## Ability 会订阅此信号来判断技能是否完成
signal effect_completed(effect: GameplayEffect)

## 应用效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
## 注意：此方法期望接收的是已经克隆的 Effect 实例
## Effect 的克隆和订阅逻辑由 Ability 负责（见 ActiveAbility._apply_single_effect_to_target）
## 
## 注意：在新三层架构下，Effect 只执行单次动作（同步完成）
## 延迟执行应该由 Status 系统管理（通过 Status 的 period 或事件触发）
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not _check_filters(target, instigator, context):
		# 如果被过滤器过滤掉，仍然发出完成信号（避免技能卡死）
		# 因为 Ability 已经订阅了这个 Effect 的信号，需要通知它已完成
		effect_completed.emit(self)
		return
	
	# 重置信号处理标志
	_signal_handled_by_subclass = false
	
	# 1. 执行具体逻辑（子类实现）
	_apply(target, instigator, context)
	
	# 2. 执行 Cue（逻辑与表现分离）
	_execute_cue(target, context)
	
	# 3. 通知完成（信号驱动模式）
	# 如果子类已经处理了信号发射（异步效果），则不再发射
	# 否则（同步效果），立即 emit 信号
	if not _signal_handled_by_subclass:
		effect_completed.emit(self)
	
	# 4. 递归应用子效果（每个子效果会自己 emit 信号）
	# 注意：
	# - 常规 Effect 通常不使用 sub_effects，保持单一职责
	# - 如果 _should_auto_apply_sub_effects() 返回 true，基类会自动应用子效果到同一个 target
	# - Meta Effect 应该返回 false，自己控制子效果的应用（如应用到不同目标）
	if _should_auto_apply_sub_effects():
		_apply_sub_effects(target, instigator, context)


## 移除效果（用于状态型效果）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
func remove(target: Node, instigator: Node) -> void: 
	_remove(target, instigator)
	# 停止持续 Cue（如拖尾、持续特效等）
	_stop_cue(target)
	# 如果被移除的效果还未完成，emit 信号（避免技能卡死）
	effect_completed.emit(self)
	# 递归移除子效果（只有自动应用的子效果才需要移除）
	if _should_auto_apply_sub_effects():
		for effect in sub_effects:
			effect.remove(target, instigator)

## 获取效果描述
func get_description() -> String:
	var description = _get_description()
	for effect in sub_effects:
		description += effect.get_description() + "\n"
	return description

## [子类重写] 应用效果的具体实现
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息
@abstract func _apply(target: Node, instigator: Node, context: Dictionary) -> void


## [子类重写] 移除效果的具体实现
func _remove(_target: Node, _instigator: Node) -> void: 
	pass

## [子类重写] 是否自动应用子效果
## 
## 设计原则：
## - 常规 Effect（Primitive Effect）应该返回 true（默认），不使用 sub_effects，保持单一职责
## - Meta Effect（元效果）应该返回 false，自己控制子效果的应用（如应用到不同目标）
##
## 返回 true：基类会自动应用 sub_effects 到同一个 target（常规 Effect 的默认行为）
## 返回 false：子类需要自己控制子效果的应用（Meta Effect 应该返回 false）
## 
## 默认返回 true，保持向后兼容
func _should_auto_apply_sub_effects() -> bool:
	return true

## 应用子效果（内部方法，供基类和子类使用）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息
func _apply_sub_effects(target: Node, instigator: Node, context: Dictionary) -> void:
	# 注意：子效果也需要克隆，避免运行时状态共享
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		sub_effect_inst.apply(target, instigator, context)

## 检查过滤器
## [param] target: Node 目标
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
func _check_filters(target: Node, instigator: Node, context: Dictionary) -> bool:
	# 1. 检查传统过滤器
	for filter in filters:
		if not filter.check(target, instigator, context):
			return false
	
	# 2. 检查标签要求（标签系统集成）
	# 检查阻止标签（免疫检查）
	if not target_blocked_tags.is_empty():
		if TagManager.has_any_tag(target, target_blocked_tags):
			print("GameplayEffect: Target blocked tags found for effect %s" % get_path())
			return false
	
	# 检查必须标签（连携检查）
	if not target_required_tags.is_empty():
		if not TagManager.has_all_tags(target, target_required_tags):
			print("GameplayEffect: Target required tags not found for effect %s" % get_path())
			return false
	
	return true

## [子类重写] 获取效果描述
func _get_description() -> String:
	return "No description available."

## 执行 Cue（逻辑与表现分离）
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息
func _execute_cue(target: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(cue):
		return
	
	# 执行 Cue（Manager 会处理挂点计算）
	GameplayCueManager.execute_cue(cue, target, context)

## 停止 Cue（用于持续效果）
## [param] target: Node 目标节点
func _stop_cue(target: Node) -> void:
	if not is_instance_valid(cue):
		return
	
	# 遍历所有 Cue 组件并停止持续效果
	for cue_component in cue.cues:
		if not is_instance_valid(cue_component):
			continue
		
		# 如果 Cue 组件实现了 stop 方法，调用它
		if cue_component.has_method("stop"):
			cue_component.stop(target)
