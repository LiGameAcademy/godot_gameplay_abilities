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
## 延迟执行时间（秒）
## 如果 > 0，效果会在延迟后执行，而不是立即执行
## 适用于：前摇时间、延迟伤害、延迟治疗等场景
@export var delay: float = 0.0

## 应用效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not _check_filters(target, instigator, context):
		return
	
	# 检查是否有延迟
	if delay > 0:
		# 延迟执行：使用 SceneTreeTimer
		_apply_delayed(target, instigator, context)
	else:
		# 立即执行
		_apply_immediate(target, instigator, context)

## 立即应用效果（内部方法）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息
func _apply_immediate(target: Node, instigator: Node, context: Dictionary) -> void:
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

## 延迟应用效果（内部方法）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息
func _apply_delayed(target: Node, instigator: Node, context: Dictionary) -> void:
	# 获取 SceneTree（从 target 或 instigator）
	var scene_tree: SceneTree = null
	if is_instance_valid(target) and target.is_inside_tree():
		scene_tree = target.get_tree()
	elif is_instance_valid(instigator) and instigator.is_inside_tree():
		scene_tree = instigator.get_tree()
	
	if not is_instance_valid(scene_tree):
		push_warning("GameplayEffect: Cannot apply delayed effect, no valid SceneTree found")
		# 回退到立即执行
		_apply_immediate(target, instigator, context)
		return
	
	# 1. 获取 AbilityComponent（用于注册/注销阻塞任务）
	var ability_comp = _find_ability_component(instigator)
	var current_ability_id: StringName = &""
	
	# 2. 如果是阻塞效果，立即向组件"举手"注册（延迟期间也算阻塞）
	if blocks_ability_completion and is_instance_valid(ability_comp):
		current_ability_id = ability_comp.get_current_casting_ability_id()
		if not current_ability_id.is_empty():
			ability_comp.register_blocking_task(current_ability_id)
	
	# 3. 创建延迟计时器
	var timer = scene_tree.create_timer(delay)
	
	# 4. 延迟执行回调
	timer.timeout.connect(func() -> void:
		# 延迟执行前再次检查目标有效性
		if not is_instance_valid(target) or not is_instance_valid(instigator):
			# 如果目标或施法者已失效，注销阻塞任务
			if blocks_ability_completion and is_instance_valid(ability_comp) and not current_ability_id.is_empty():
				ability_comp.unregister_blocking_task(current_ability_id)
			return
		
		# 再次检查过滤器（延迟期间可能状态已改变）
		if not _check_filters(target, instigator, context):
			# 过滤器不通过，注销阻塞任务
			if blocks_ability_completion and is_instance_valid(ability_comp) and not current_ability_id.is_empty():
				ability_comp.unregister_blocking_task(current_ability_id)
			return
		
		# 执行具体逻辑（子类实现）
		_apply(target, instigator, context)
		
		# 执行 Cue（逻辑与表现分离）
		_execute_cue(target, context)
		
		# 异步处理
		if blocks_ability_completion and is_instance_valid(ability_comp) and not current_ability_id.is_empty():
			if _is_asynchronous():
				# 如果是异步，等待子类自己在结束后调用 unregister
				# 子类需要在完成时调用：ability_comp.unregister_blocking_task(current_ability_id)
				pass
			else:
				# 如果是同步（即时），立即注销
				ability_comp.unregister_blocking_task(current_ability_id)
		
		# 递归应用子效果（每个子效果会自己去 register/unregister）
		for effect in effects:
			if is_instance_valid(effect):
				effect.apply(target, instigator, context)
	)

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
	# 停止持续 Cue（如拖尾、持续特效等）
	_stop_cue(target)
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
@abstract func _apply(target: Node, instigator: Node, context: Dictionary) -> void

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
