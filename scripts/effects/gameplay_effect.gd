@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现_apply方法
## 如果需要移除逻辑，可以重写_remove方法

@export var filters: Array[GameplayFilterData] = [] 	## 过滤器，如果为空，则不过滤

## 子效果，支持效果组合
## 注意：
## - 常规 Effect（Primitive Effect）通常不使用此属性，保持单一职责
## - Meta Effect（元效果）使用此属性来协调其他 Effect 的执行
## - 如果 _should_auto_apply_sub_effects() 返回 true，基类会自动应用子效果到同一个 target
## - 如果返回 false，子类需要自己控制子效果的应用（如应用到不同目标）
@export var sub_effects : Array[GameplayEffect] = []
@export var auto_apply_sub_effects: bool = true

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

## 应用效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
## 注意：此方法期望接收的是已经克隆的 Effect 实例
## Effect 的克隆和订阅逻辑由 Ability 负责（见 ActiveAbility._apply_single_effect_to_target）
## 
## 注意：在新三层架构下，Effect 只执行单次动作（同步完成）
## 延迟执行应该由 Status 系统管理（通过 Status 的 period 或事件触发）
func apply(target: Node, instigator: Node, context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	if not _check_filters(target, instigator, ctx):
		return
	
	# 1. 执行具体逻辑（子类实现）
	_apply(target, instigator, ctx)
	
	# 2. 执行 Cue（逻辑与表现分离）
	_execute_cue(target, ctx)
	
	# 3. 递归应用子效果（每个子效果会自己 emit 信号）
	# 注意：
	# - 常规 Effect 通常不使用 sub_effects，保持单一职责
	if auto_apply_sub_effects:
		_apply_sub_effects(target, instigator, ctx)

## 移除效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Variant 可以是 Dictionary 或 AbilityContext（向后兼容）
## 注意：Effect 保持无状态特性，移除逻辑通过 context 中的信息（如 source_id）来识别要移除的内容
## 子类可以重写 _remove 方法来实现具体的移除逻辑
func remove(target: Node, instigator: Node, context: Variant = {}) -> void:
	var ctx = ContextUtils.to_context(context)
	
	# 1. 执行具体移除逻辑（子类实现，默认空实现）
	_remove(target, instigator, ctx)
	
	# 2. 递归移除子效果
	if auto_apply_sub_effects:
		_remove_sub_effects(target, instigator, ctx)

## 获取效果描述
func get_description() -> String:
	var description = _get_description()
	for effect in sub_effects:
		description += effect.get_description() + "\n"
	return description

## [子类重写] 应用效果的具体实现
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: AbilityContext 上下文信息
@abstract func _apply(target: Node, instigator: Node, context: AbilityContext) -> void

## [子类重写] 移除效果的具体实现
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: AbilityContext 上下文信息
## 注意：Effect 保持无状态特性，移除逻辑应该通过 context 中的信息（如 source_id）来识别要移除的内容
## 默认空实现，子类根据需要重写
func _remove(target: Node, instigator: Node, context: AbilityContext) -> void:
	# 默认空实现，大多数效果不需要移除逻辑
	pass

## 应用子效果（内部方法，供基类和子类使用）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: AbilityContext 上下文信息
func _apply_sub_effects(target: Node, instigator: Node, context: AbilityContext) -> void:
	# 注意：子效果也需要克隆，避免运行时状态共享
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		sub_effect_inst.apply(target, instigator, context)

## 移除子效果（内部方法，供基类和子类使用）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: AbilityContext 上下文信息
func _remove_sub_effects(target: Node, instigator: Node, context: AbilityContext) -> void:
	# 注意：子效果也需要克隆，避免运行时状态共享
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		sub_effect_inst.remove(target, instigator, context)

## 检查过滤器
## [param] target: Node 目标
## [param] instigator: Node 施法者
## [param] context: AbilityContext 上下文
func _check_filters(target: Node, instigator: Node, context: AbilityContext) -> bool:
	# 1. 检查传统过滤器（过滤器可能仍使用 Dictionary，转换后传递）
	var filter_dict = context.to_dict()
	for filter in filters:
		if not filter.check(target, instigator, filter_dict):
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
## [param] context: AbilityContext 上下文信息
func _execute_cue(target: Node, context: AbilityContext) -> void:
	if not is_instance_valid(cue):
		return
	
	# 执行 Cue（Manager 可能仍使用 Dictionary，转换后传递）
	var cue_dict = context.to_dict()
	GameplayCueManager.execute_cue(cue, target, cue_dict)
