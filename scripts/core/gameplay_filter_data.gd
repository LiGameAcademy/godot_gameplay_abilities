@abstract
extends Resource
class_name GameplayFilterData

## 游戏过滤器基类（抽象类）
## 用于过滤效果的目标，所有具体过滤器都继承此类

## 检查此过滤器是否通过
## [param] target: Node 效果施加的目标
## [param] instigator: Node 效果的来源
## [param] context: Dictionary 事件的上下文
func check(target: Node, instigator: Node, context: Dictionary) -> bool:
	return _check(target, instigator, context)

## [子类重写] 内部虚方法
func _check(_target: Node, _instigator: Node, _context: Dictionary) -> bool:
	# 默认总是通过
	return true
