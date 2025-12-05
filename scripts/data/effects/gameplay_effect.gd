@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现_apply和_remove方法

@export var filters: Array[GameplayFilterData] = [] 	## 过滤器，如果为空，则不过滤

@export var effects : Array[GameplayEffect] = [] 		## 子效果，支持效果组合

@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当效果应用成功时，会执行此 Cue 来播放表现（特效、音效、飘字等）
@export var cue: GameplayCue = null

@export_group("Effect Lifecycle")
## 决定该效果是否会阻塞技能的完成流程
## true: 技能会等待该效果执行完毕（调用 finished_callback）才算结束
## false: 技能施放即完成（Fire and Forget，即时效果）
@export var blocks_ability_completion: bool = false

## 应用效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not _check_filters(target, instigator, context):
		return
	
	# 1. 获取 AbilityComponent（用于注册/注销阻塞任务）
	var ability_comp = _find_ability_component(instigator)
	var current_ability_id: StringName = &""
	
	# 2. 如果是阻塞效果，立即向组件"举手"注册
	if blocks_ability_completion and is_instance_valid(ability_comp):
		current_ability_id = ability_comp.get_current_casting_ability_id()
		if not current_ability_id.is_empty():
			ability_comp.register_blocking_task(current_ability_id)
	
	# 3. 执行具体逻辑（子类实现）
	_apply(target, instigator, context)
	
	# 4. 执行 Cue（逻辑与表现分离）
	_execute_cue(target, context)
	
	# 5. 异步处理
	if blocks_ability_completion and is_instance_valid(ability_comp) and not current_ability_id.is_empty():
		if _is_asynchronous():
			# 如果是异步，等待子类自己在结束后调用 unregister
			# 子类需要在完成时调用：ability_comp.unregister_blocking_task(current_ability_id)
			pass
		else:
			# 如果是同步（即时），立即注销
			ability_comp.unregister_blocking_task(current_ability_id)
	
	# 6. 递归应用子效果（每个子效果会自己去 register/unregister）
	for effect in effects:
		if is_instance_valid(effect):
			effect.apply(target, instigator, context)

## 辅助查找组件
## [param] node: Node 节点
## [return] GameplayAbilityComponent 组件，如果不存在则返回 null
func _find_ability_component(node: Node) -> GameplayAbilityComponent:
	if not is_instance_valid(node):
		return null
	
	# 优先使用 GameplayAbilitySystem 查找
	var comp = GameplayAbilitySystem.get_component_by_interface(node, "GameplayAbilityComponent")
	if is_instance_valid(comp):
		return comp as GameplayAbilityComponent
	
	# 如果找不到，返回 null
	return null

## 移除效果（用于状态型效果）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
func remove(target: Node, instigator: Node) -> void: 
	_remove(target, instigator)
	# 递归移除子效果
	for effect in effects:
		effect.remove(target, instigator)

## 获取效果描述
func get_description() -> String:
	var description = _get_description()
	for effect in effects:
		description += effect.get_description() + "\n"
	return description

## [子类重写] 应用效果的具体实现
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息
func _apply(target: Node, instigator: Node, context: Dictionary) -> void: 
	pass

## [子类重写] 是否是异步执行？
## 如果子类有 Tween 或 Timer，返回 true，并负责手动调用 finished_callback
## 返回 false 时，基类会在 _apply 后立即调用 finished_callback（防止卡死）
func _is_asynchronous() -> bool:
	return false

## [子类重写] 移除效果的具体实现
func _remove(_target: Node, _instigator: Node) -> void: 
	pass

## 检查过滤器
## [param] target: Node 目标
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
func _check_filters(target: Node, instigator: Node, context: Dictionary) -> bool:
	for filter in filters:
		if not filter.check(target, instigator, context):
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
