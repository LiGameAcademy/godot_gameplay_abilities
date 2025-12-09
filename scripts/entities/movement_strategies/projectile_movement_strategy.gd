@abstract
extends Resource
class_name ProjectileMovementStrategy

## 投射物移动策略基类（抽象类）
## 使用策略模式，符合开闭原则
## 子类需要实现 process_movement 方法来定义具体的移动逻辑

## 处理移动逻辑
## [param] projectile: ProjectileBase 投射物实例
## [param] delta: float 帧时间
## [return] Vector3 新的速度向量
func process_movement(projectile: ProjectileBase, delta: float) -> Vector3:
	return _process_movement(projectile, delta)

## [子类重写] 处理移动逻辑的具体实现
## [param] projectile: ProjectileBase 投射物实例
## [param] delta: float 帧时间
## [return] Vector3 新的速度向量
func _process_movement(_projectile: ProjectileBase, _delta: float) -> Vector3:
	push_error("ProjectileMovementStrategy: _process_movement must be implemented by subclass")
	return Vector3.ZERO
