extends ProjectileMovementStrategy
class_name HomingMovementStrategy

## 追踪移动策略
## 投射物会追踪目标，使用加速度控制转向速度

func _process_movement(projectile: ProjectileBase, delta: float) -> Vector3:
	# 如果没有目标或加速度为0，回退到直线飞行
	if not is_instance_valid(projectile.target_reference) or projectile.homing_acceleration <= 0.0:
		return projectile.velocity
	
	# 计算到目标的方向
	var direction_to_target = (projectile.target_reference.global_position - projectile.global_position).normalized()
	
	# 当前方向
	var current_dir = projectile.velocity.normalized()
	
	# 转向插值（使用加速度控制转向速度）
	var new_dir = current_dir.lerp(direction_to_target, projectile.homing_acceleration * delta).normalized()
	
	# 返回新速度
	return new_dir * projectile.speed
