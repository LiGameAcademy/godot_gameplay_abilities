@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现_apply和_remove方法

@export var period: float = 0.0 						## 周期性效果的周期时间，如果为0，则不周期性触发
@export var event_to_listen: StringName = &"" 		## 监听的事件，如果为空，则不监听事件
@export var filters: Array[GameplayFilterData] = [] 	## 过滤器，如果为空，则不过滤

@export var effects : Array[GameplayEffect] = [] 	## 子效果，支持效果组合

@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当效果应用成功时，会执行此 Cue 来播放表现（特效、音效、飘字等）
@export var cue: GameplayCue = null

## 应用效果
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not _check_filters(target, instigator, context):
		return
	
	# 应用效果
	_apply(target, instigator, context)
	
	# 执行 Cue（逻辑与表现分离）
	_execute_cue(target, context)
	
	# 递归应用子效果
	for effect in effects:
		effect.apply(target, instigator, context)

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
func _apply(_target: Node, _instigator: Node, _context: Dictionary) -> void: 
	pass

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
