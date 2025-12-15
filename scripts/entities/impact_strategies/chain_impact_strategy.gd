extends ProjectileImpactStrategy
class_name ChainImpactStrategy

## 链式传导撞击策略
## 用于在投射物命中第一个目标时，启动一个 ChainEffectConductor 进行链式传导。
## 注意：
## - 当前策略本身不复用投射物进行“弹射”，而是在首个命中点触发链式过程，然后消耗该投射物。
## - 这样可以复用 ChainEffectConductor，并保持投射物系统职责单一（负责命中触发）。

@export_group("Chain Settings")
@export_range(1, 32) var max_jumps: int = 3
@export var damage_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 0.8, 0.6])
@export var jump_radius: float = 8.0
@export_range(0.0, 1.0, 0.01) var jump_interval: float = 0.1

@export_group("Effects / Targeting")
@export var per_jump_effects: Array[GameplayEffect] = []
@export var target_filters: Array[GameplayFilterData] = []

@export_group("Visual")
@export var conductor_scene: PackedScene = null

func on_impact(
		projectile: Node,
		target: Node,
		_hit_position: Vector3,
		_hit_direction: Vector3) -> bool:
	if not projectile is ProjectileBase:
		return true
	var p: ProjectileBase = projectile as ProjectileBase
	if not is_instance_valid(target) or not is_instance_valid(p.instigator):
		return true
	if per_jump_effects.is_empty():
		return true
	
	var conductor := _spawn_conductor(p.instigator)
	if not is_instance_valid(conductor):
		return true
	
	conductor.max_jumps = max_jumps
	conductor.damage_multipliers = damage_multipliers
	conductor.jump_radius = jump_radius
	conductor.jump_interval = jump_interval
	conductor.jump_effects = per_jump_effects.duplicate()
	conductor.target_filters = target_filters.duplicate()
	
	conductor.start_chain(p.instigator, target)
	
	# 链条已经启动，本投射物可以被消耗
	return true

func _spawn_conductor(instigator: Node) -> ChainEffectConductor:
	var conductor: ChainEffectConductor = null
	
	if is_instance_valid(conductor_scene):
		var node := conductor_scene.instantiate()
		if not node is ChainEffectConductor:
			node.queue_free()
			push_error("ChainImpactStrategy: conductor_scene root must inherit from ChainEffectConductor")
			return null
		conductor = node as ChainEffectConductor
	else:
		conductor = ChainEffectConductor.new()
	
	var tree := instigator.get_tree()
	if tree == null or tree.current_scene == null:
		push_error("ChainImpactStrategy: Cannot find current scene to add conductor")
		conductor.queue_free()
		return null
	
	tree.current_scene.add_child(conductor)
	return conductor


