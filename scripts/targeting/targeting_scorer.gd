@abstract
extends Resource
class_name TargetingScorer

## 目标评分器基类（抽象类）
## 从已经筛选过的目标列表中，选择最佳目标

## 查找最佳目标
## [param] instigator: Node 施法者
## [param] valid_targets: Array[Node] 有效目标列表
## [returns] Node 最佳目标，如果没有则返回null
func find_best_target(instigator: Node, valid_targets: Array[Node]) -> Node:
	return _find_best_target(instigator, valid_targets)

## [子类重写] 查找最佳目标的具体实现
func _find_best_target(_instigator: Node, _valid_targets: Array[Node]) -> Node:
	# 默认返回第一个目标
	if _valid_targets.size() > 0:
		return _valid_targets[0]
	return null
