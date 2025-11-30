extends Node

## 效果执行器（单例）
## 负责执行GameplayEffect，提供统一的执行接口

## 执行效果
## [param] effect: GameplayEffect 要执行的效果
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
func execute_effect(effect: GameplayEffect, target: Node, instigator: Node, context: Dictionary = {}) -> void:
	if not is_instance_valid(effect):
		push_error("EffectExecutor: Effect is not valid!")
		return
	
	if not is_instance_valid(target):
		push_error("EffectExecutor: Target is not valid!")
		return
	
	# 执行效果
	effect.apply(target, instigator, context)

## 移除效果（用于状态型效果）
## [param] effect: GameplayEffect 要移除的效果
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
func remove_effect(effect: GameplayEffect, target: Node, instigator: Node) -> void:
	if not is_instance_valid(effect):
		push_error("EffectExecutor: Effect is not valid!")
		return
	
	if not is_instance_valid(target):
		push_error("EffectExecutor: Target is not valid!")
		return
	
	# 移除效果
	effect.remove(target, instigator)

## 批量执行效果
## [param] effects: Array[GameplayEffect] 效果数组
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: Dictionary 上下文信息（可选）
func execute_effects(effects: Array[GameplayEffect], target: Node, instigator: Node, context: Dictionary = {}) -> void:
	for effect in effects:
		if is_instance_valid(effect):
			execute_effect(effect, target, instigator, context)

