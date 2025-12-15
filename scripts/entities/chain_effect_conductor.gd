extends Node3D
class_name ChainEffectConductor

## 通用“链式传导”载具（不走传统飞行弹道，而是按目标链式跳跃）
## 设计目标：
## - 从第一个目标开始，在附近单位之间跳跃
## - 每跳一次可以有不同的倍率（衰减或自定义）
## - 自动寻找下一个合适目标（基于距离和可选过滤）
##
## 注意：
## - 这里只负责“过程”（找目标 + 调用效果），不直接做数值计算
## - 具体伤害/治疗等通过可配置的 GameplayEffect 实现

@export_group("Chain Settings")
@export_range(1, 32) var max_jumps: int = 3
@export var damage_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 0.8, 0.6])
@export var jump_radius: float = 8.0
@export_range(0.0, 1.0, 0.01) var jump_interval: float = 0.1

@export_group("Effects / Targeting")
## 每一跳对应的 GameplayEffect 列表（长度不足时，后续跳跃复用最后一个）
@export var jump_effects: Array[GameplayEffect] = []
## 目标筛选过滤器（可选，沿用 GameplayFilterData 体系）
@export var target_filters: Array[GameplayFilterData] = []

var instigator: Node = null

var _visited_targets: Array[Node] = []
var _current_jump_index: int = 0
var _is_running: bool = false

func start_chain(p_instigator: Node, first_target: Node) -> void:
	instigator = p_instigator
	if not is_instance_valid(first_target) or not is_instance_valid(instigator):
		queue_free()
		return
	_is_running = true
	_visited_targets.clear()
	_current_jump_index = 0
	_do_single_jump(first_target)

func _do_single_jump(target: Node) -> void:
	if not is_instance_valid(target):
		_finish_chain()
		return
	
	_visited_targets.append(target)
	
	if target is Node3D:
		global_position = (target as Node3D).global_position
	
	_apply_effect_to_target(target, _current_jump_index)
	
	_current_jump_index += 1
	if _current_jump_index >= max_jumps:
		_finish_chain()
		return
	
	var next_target: Node = _find_next_target(target)
	if not is_instance_valid(next_target):
		_finish_chain()
		return
	
	if jump_interval <= 0.0:
		_do_single_jump(next_target)
	else:
		var timer := get_tree().create_timer(jump_interval)
		timer.timeout.connect(func() -> void:
			if _is_running:
				_do_single_jump(next_target)
		)

func _apply_effect_to_target(target: Node, jump_index: int) -> void:
	if not is_instance_valid(target) or not is_instance_valid(instigator):
		return
	if jump_effects.is_empty():
		return
	
	var effect_template: GameplayEffect = null
	if jump_index < jump_effects.size():
		effect_template = jump_effects[jump_index]
	else:
		effect_template = jump_effects[jump_effects.size() - 1]
	if not is_instance_valid(effect_template):
		return
	
	var multiplier := _get_multiplier_for_jump(jump_index)
	var effect_inst := effect_template.duplicate(true) as GameplayEffect
	if not is_instance_valid(effect_inst):
		return
	
	var context: Dictionary = {
		"chain_jump_index": jump_index,
		"chain_multiplier": multiplier,
	}
	
	effect_inst.apply(target, instigator, context)

func _get_multiplier_for_jump(jump_index: int) -> float:
	if damage_multipliers.is_empty():
		return 1.0
	if jump_index < damage_multipliers.size():
		return damage_multipliers[jump_index]
	return damage_multipliers[damage_multipliers.size() - 1]

func _find_next_target(from_target: Node) -> Node:
	if not from_target is Node3D:
		return null
	
	var origin := (from_target as Node3D).global_position
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return null
	
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = jump_radius
	
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere_shape
	params.transform.origin = origin
	params.collide_with_areas = true
	params.collide_with_bodies = true
	
	var results := space_state.intersect_shape(params, 32)
	var candidates: Array[Node] = []
	
	for hit in results:
		var collider := hit.get("collider")
		if not is_instance_valid(collider):
			continue
		
		var entity: Node = collider
		if "owner" in collider and collider.owner is Node:
			entity = collider.owner
		
		if not is_instance_valid(entity):
			continue
		if entity == from_target or _visited_targets.has(entity):
			continue
		
		if not _passes_filters(entity):
			continue
		
		candidates.append(entity)
	
	if candidates.is_empty():
		return null
	
	candidates.shuffle()
	return candidates[0]

func _passes_filters(target: Node) -> bool:
	if target_filters.is_empty():
		return true
	for filter_data in target_filters:
		if not is_instance_valid(filter_data):
			continue
		if not filter_data.check(target, instigator, {}):
			return false
	return true

func _finish_chain() -> void:
	_is_running = false
	queue_free()


