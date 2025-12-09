extends Area3D
class_name AoEBase

## 范围效果实体基类
## 职责：在指定位置生成，检测范围内的目标，并应用效果
##
## 设计原则：
## - 利用 Godot 的物理引擎（Area3D）处理范围检测
## - 支持瞬间爆炸和周期性魔法阵
## - 通过 GAS 系统应用效果，保持架构一致性

enum AoEType {
	INSTANT,  ## 瞬间爆炸（如火球爆炸）
	PERIODIC  ## 周期性魔法阵（如暴风雪、治疗图腾）
}

@export_group("AoE Settings")
## AoE 类型
@export var aoe_type: AoEType = AoEType.INSTANT

@export_group("Effects")
## 要应用的效果列表（从技能处传过来，或者自身配置）
@export var effects_to_apply: Array[GameplayEffect] = []

@export_group("Periodic Settings")
## 周期时间（秒，仅周期性 AoE 使用）
@export var period: float = 1.0
## 持续时间（秒，仅周期性 AoE 使用，-1 为永久）
@export var duration: float = 5.0

# ========== 运行时数据（由生成者注入）==========
## 施法者（用于过滤目标和应用效果）
var instigator: Node = null
## 生成时的上下文信息（会传递给效果）
var spawn_context: Dictionary = {}

# ========== 内部状态 ==========
var _timer: Timer = null
var _duration_timer: SceneTreeTimer = null

func _ready() -> void:
	# 确保监测逻辑只对有效目标触发（通过 collision_mask 配置）
	# 注意：需要在场景中配置 CollisionShape3D 和 collision_mask
	
	if aoe_type == AoEType.INSTANT:
		# 瞬间爆炸：等一帧让物理引擎检测碰撞，然后执行
		await get_tree().process_frame
		_explode_and_die()
	elif aoe_type == AoEType.PERIODIC:
		# 周期性魔法阵：启动计时器
		_start_periodic_logic()
		# 并在持续时间结束后销毁（如果设置了持续时间）
		if duration > 0:
			_duration_timer = get_tree().create_timer(duration)
			_duration_timer.timeout.connect(queue_free)

## 瞬间爆炸逻辑
func _explode_and_die() -> void:
	# 获取当前区域内的所有目标
	var targets = _get_overlapping_targets()
	_apply_effects_to_targets(targets)
	
	# 播放完特效后销毁自己（这里简单处理直接销毁）
	# 如果需要播放特效，可以在销毁前等待特效完成
	queue_free()

## 周期性逻辑
func _start_periodic_logic() -> void:
	_timer = Timer.new()
	_timer.wait_time = period
	_timer.autostart = true
	_timer.timeout.connect(_on_periodic_tick)
	add_child(_timer)
	# 立即触发第一次
	_on_periodic_tick()

func _on_periodic_tick() -> void:
	var targets = _get_overlapping_targets()
	_apply_effects_to_targets(targets)

## 获取范围内的所有目标
## [return] Array[Node] 目标列表
func _get_overlapping_targets() -> Array[Node]:
	var targets: Array[Node] = []
	
	# 获取所有重叠的 Body3D
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if not is_instance_valid(body):
			continue
		
		# 转换为实体根节点（通过工具函数）
		var entity = CombatUtils.get_entity_from_collider(body)
		if is_instance_valid(entity):
			targets.append(entity)
	
	# 获取所有重叠的 Area3D（用于 Hitbox 等）
	var areas = get_overlapping_areas()
	for area in areas:
		if not is_instance_valid(area):
			continue
		
		# 通常 Area 的 owner 是实际的实体
		var owner = area.owner if area.owner else area
		if is_instance_valid(owner):
			# 转换为实体根节点
			var entity = CombatUtils.get_entity_from_node(owner)
			if is_instance_valid(entity) and entity not in targets:
				targets.append(entity)
	
	return targets

## 核心：应用效果到目标列表
## [param] targets: Array[Node] 目标列表
func _apply_effects_to_targets(targets: Array[Node]) -> void:
	if effects_to_apply.is_empty():
		return
	
	if not is_instance_valid(instigator):
		push_warning("AoEBase: Cannot apply effects, instigator is not valid")
		return
	
	# 准备上下文（可以加上 AoE 中心点等信息）
	var execution_context = spawn_context.duplicate()
	execution_context["aoe_center"] = global_position
	execution_context["aoe_type"] = aoe_type
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# 过滤检查：忽略施法者自己
		if target == instigator:
			continue
		
		# 可以在这里加阵营判断（Team Check）
		# if not is_enemy(instigator, target): continue
		
		# 循环应用所有效果
		for effect in effects_to_apply:
			if not is_instance_valid(effect):
				continue
			
			# 【关键】让 Effect 系统去处理具体的应用逻辑
			# 注意：Effect 会自动处理克隆（避免共享状态）
			effect.apply(target, instigator, execution_context)

## 清理资源
func _exit_tree() -> void:
	if is_instance_valid(_timer):
		_timer.queue_free()
	_timer = null
	_duration_timer = null
	effects_to_apply.clear()
	spawn_context.clear()
	instigator = null
