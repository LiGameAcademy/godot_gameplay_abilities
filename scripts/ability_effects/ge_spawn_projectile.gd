extends GameplayEffect
class_name GE_SpawnProjectile

## 通过 Effect 创建投射物的通用入口
## 用途：
## - 在效果层触发一次投射物（如某个状态周期性射出飞弹）
## - 或在命中/事件时动态生成投射物，而不依赖专门的 Ability

@export_group("Projectile")
## 投射物场景（根节点必须继承自 ProjectileBase）
@export var projectile_scene: PackedScene = null
## 投射物数据（用于注入速度/穿透/弹头等配置）
@export var projectile_data: ProjectileData = null

@export_group("Spawn")
## 是否使用 instigator 的 Transform 作为出生点（否则尝试使用 context["muzzle_transform"]）
@export var use_instigator_transform: bool = true

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(projectile_scene) or not is_instance_valid(projectile_data):
		return
	if not is_instance_valid(instigator):
		return
	
	var projectile_node := projectile_scene.instantiate()
	if not projectile_node is ProjectileBase:
		projectile_node.queue_free()
		push_error("GE_SpawnProjectile: projectile_scene root must inherit from ProjectileBase")
		return
	var projectile: ProjectileBase = projectile_node as ProjectileBase
	
	# 1. 决定出生 Transform
	var spawn_transform := Transform3D.IDENTITY
	
	if not use_instigator_transform and context.has("muzzle_transform") and context["muzzle_transform"] is Transform3D:
		spawn_transform = context["muzzle_transform"]
	elif instigator is Node3D:
		spawn_transform = (instigator as Node3D).global_transform
	
	# 2. 挂到场景
	var tree := instigator.get_tree()
	if tree == null or tree.current_scene == null:
		push_error("GE_SpawnProjectile: Cannot find current scene to add projectile")
		projectile.queue_free()
		return
	
	tree.current_scene.add_child(projectile)
	projectile.global_transform = spawn_transform
	
	# 3. 注入数据 + 施法者
	projectile.instigator = instigator
	projectile_data.apply_to_projectile(projectile)

func _get_description() -> String:
	return "Spawn a projectile using ProjectileData.\n"


