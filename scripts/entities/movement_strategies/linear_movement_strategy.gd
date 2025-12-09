extends ProjectileMovementStrategy
class_name LinearMovementStrategy

## 直线移动策略
## 投射物以恒定速度沿初始方向直线飞行

func _process_movement(projectile: ProjectileBase, _delta: float) -> Vector3:
	# 直线飞行：速度保持不变，方向不变
	# 速度在 _ready 中已经设置，这里不需要修改
	return projectile.velocity
