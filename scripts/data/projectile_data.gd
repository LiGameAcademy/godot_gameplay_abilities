extends Resource
class_name ProjectileData

## 投射物数据资源
## 用于配置投射物的所有参数，在 ProjectileAbility 中配置，传递给 ProjectileBase
##
## 设计目的：
## - 解耦配置和运行时逻辑
## - 让投射物数据可复用（多个技能可以共享同一个 ProjectileData）
## - 符合 Godot 的资源系统设计

@export_group("Movement")
## 飞行速度（单位/秒）
@export var speed: float = 20.0
## 最大生命周期（秒）
@export var max_lifetime: float = 5.0
## 追踪加速度（0 为直线，>0 为追踪）
## 值越大，转向越快
@export var homing_acceleration: float = 0.0

@export_group("Penetration")
## 是否穿透（穿透时不会在撞击后销毁）
@export var piercing: bool = false
## 最大穿透次数（-1 为无限）
@export var max_pierce_count: int = -1

@export_group("Strategy")
## 移动策略实例
## 业务层可以在编辑器中创建 .tres 资源文件并配置
@export var movement_strategy: ProjectileMovementStrategy = null

@export_group("Scene")
## 投射物场景（必须继承自 ProjectileBase）
## 场景是投射物的核心定义，属于数据配置的一部分
@export var projectile_scene: PackedScene = null
## 携带的状态列表（弹头）
## 当目标进入区域或周期性触发时，会将此列表中的状态应用给目标
@export var payload_statuses: Array[GameplayStatusData] = []

## 应用数据到投射物实例
## [param] projectile: ProjectileBase 投射物实例
func apply_to_projectile(projectile: ProjectileBase) -> void:
	if not is_instance_valid(projectile):
		push_error("ProjectileData: Cannot apply to invalid projectile")
		return
	
	# 应用移动配置
	projectile.speed = speed
	projectile.max_lifetime = max_lifetime
	projectile.homing_acceleration = homing_acceleration
	
	# 应用穿透配置
	projectile.piercing = piercing
	projectile.max_pierce_count = max_pierce_count
	
	projectile.payload_statuses = payload_statuses

	# 应用移动策略（如果设置了）
	if is_instance_valid(movement_strategy):
		projectile.movement_strategy = movement_strategy.duplicate(true)
	else:
		print("ProjectileData: movement_strategy is not set, projectile will use linear movement with initial velocity")
	
	# 【关键】重新初始化速度向量，确保使用正确的 speed
	projectile.initialize_velocity()
