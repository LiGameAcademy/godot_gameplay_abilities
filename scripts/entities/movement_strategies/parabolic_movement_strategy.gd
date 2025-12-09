extends ProjectileMovementStrategy
class_name ParabolicMovementStrategy

## 抛物线移动策略
## 投射物受重力影响，形成抛物线轨迹

## 重力加速度（单位/秒²）
var gravity: float = 9.8

func _process_movement(projectile: ProjectileBase, delta: float) -> Vector3:
	# 获取当前速度
	var velocity = projectile.velocity
	
	# 应用重力（向下加速）
	velocity.y -= gravity * delta
	
	# 返回新速度
	return velocity
