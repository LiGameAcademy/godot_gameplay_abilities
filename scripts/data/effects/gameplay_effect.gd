@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现_apply和_remove方法

@export var filters: Array[GameplayFilterData] = [] 	## 过滤器，如果为空，则不过滤

@export var sub_effects : Array[GameplayEffect] = [] 		## 子效果，支持效果组合

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

@export_group("Effect Lifecycle")
## 延迟执行时间（秒）
## 如果 > 0，效果会在延迟后执行，而不是立即执行
## 适用于：前摇时间、延迟伤害、延迟治疗等场景
@export var delay: float = 0.0

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
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not _check_filters(target, instigator, context):
		# 如果被过滤器过滤掉，仍然发出完成信号（避免技能卡死）
		# 因为 Ability 已经订阅了这个 Effect 的信号，需要通知它已完成
		effect_completed.emit(self)
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
	# 注意：子效果也需要克隆，避免运行时状态共享
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		sub_effect_inst.apply(target, instigator, context)

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
	
	# 1. 创建延迟计时器
	var timer = scene_tree.create_timer(delay)
	
	# 2. 延迟执行回调
	timer.timeout.connect(func() -> void:
		# 延迟执行前再次检查目标有效性
		if not is_instance_valid(target) or not is_instance_valid(instigator):
			# 如果目标或施法者已失效，emit 信号
			effect_completed.emit(self)
			return
		
		# 再次检查过滤器（延迟期间可能状态已改变）
		if not _check_filters(target, instigator, context):
			# 过滤器不通过，emit 信号
			effect_completed.emit(self)
			return
		
		# 重置信号处理标志
		_signal_handled_by_subclass = false
		
		# 执行具体逻辑（子类实现）
		_apply(target, instigator, context)
		
		# 执行 Cue（逻辑与表现分离）
		_execute_cue(target, context)
		
		# 通知完成（信号驱动模式）
		# 如果子类已经处理了信号发射（异步效果），则不再发射
		# 否则（同步效果），立即 emit 信号
		if not _signal_handled_by_subclass:
			effect_completed.emit(self)
		
		# 递归应用子效果（每个子效果会自己 emit 信号）
		# 注意：子效果也需要克隆，避免运行时状态共享
		for effect in sub_effects:
			if not is_instance_valid(effect):
				continue
			
			# 克隆子效果实例
			var sub_effect_inst = effect.duplicate(true) as GameplayEffect
			if not is_instance_valid(sub_effect_inst):
				continue
			
			sub_effect_inst.apply(target, instigator, context)
	)

## 移除效果（用于状态型效果）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
func remove(target: Node, instigator: Node) -> void: 
	_remove(target, instigator)
	# 停止持续 Cue（如拖尾、持续特效等）
	_stop_cue(target)
	# 如果被移除的效果还未完成，emit 信号（避免技能卡死）
	effect_completed.emit(self)
	# 递归移除子效果
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
