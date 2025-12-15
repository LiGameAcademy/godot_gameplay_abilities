extends Resource
class_name ProjectileImpactStrategy

## 投射物撞击策略基类（策略模式）
## 用于扩展 ProjectileBase 在命中目标时的行为：
## - 默认行为：应用 Payload（状态/效果），然后处理穿透和销毁（由 ProjectileBase 内部实现）
## - 自定义行为：如链式传导（闪电链、治疗链）、分裂弹、反弹等
##
## 注意：
## - 具体策略应实现 on_impact，并返回是否应消耗（销毁）当前投射物

func on_impact(
		projectile: Node,
		target: Node,
		hit_position: Vector3,
		hit_direction: Vector3) -> bool:
	## [默认实现] 不做任何处理，由 ProjectileBase 使用内置逻辑。
	## 返回 true 表示建议销毁投射物，false 表示保留（如用于自定义穿透等）。
	return true


