extends Area3D
class_name MagicCircleBase

## 魔法阵实体基类
## 职责：在指定位置生成，检测范围内的目标，并应用效果
##
## 设计原则：
## - 利用 Godot 的物理引擎（Area3D）处理范围检测
## - 支持瞬间爆炸和周期性魔法阵
## - 通过 GAS 系统应用效果，保持架构一致性

enum MagicCircleType {
	INSTANT,  ## 瞬间爆炸（如火球爆炸）
	PERIODIC  ## 周期性魔法阵（如暴风雪、治疗图腾）
}

@export_group("Magic Circle Settings")
## 魔法阵类型
@export var circle_type: MagicCircleType = MagicCircleType.INSTANT

@export_group("Periodic Settings")
## 周期时间（秒，仅周期性魔法阵使用）
@export var period: float = 1.0
## 持续时间（秒，仅周期性魔法阵使用，-1 为永久）
@export var duration: float = 5.0

# ========== 信号 ==========
## 目标检测信号（用于外部系统应用效果或进一步处理）
## [param] targets: Array[Node] 检测到的目标列表
## [param] context: Dictionary 上下文信息（含中心、类型、施法者等）
signal targets_detected(targets: Array, context: Dictionary)

# ========== 运行时数据（由生成者注入）==========
## 施法者（用于过滤目标和应用效果）
var instigator: Node = null
## 生成时的上下文信息（会传递给效果）
var spawn_context: Dictionary = {}
## 要应用的效果列表（从 Ability 处传过来）
var effects_to_apply: Array[GameplayEffect] = []
## 目标筛选策略（从 Ability 处传过来）
var targeting_strategy: TargetingStrategy = null

# ========== 内部状态 ==========
var _timer: Timer = null
var _duration_timer: SceneTreeTimer = null

func _ready() -> void:
	# 确保监测逻辑只对有效目标触发（通过 collision_mask 配置）
	# 注意：需要在场景中配置 CollisionShape3D 和 collision_mask
	
	if circle_type == MagicCircleType.INSTANT:
		# 瞬间爆炸：等一帧让物理引擎检测碰撞，然后执行
		await get_tree().process_frame
		_explode_and_die()
	elif circle_type == MagicCircleType.PERIODIC:
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
	_process_targets(targets)
	
	# 等待特效播放完成后再销毁
	# 查找所有粒子系统和动画播放器，等待它们完成
	var max_lifetime: float = 0.0
	
	# 检查 GPUParticles3D
	for child in get_children():
		if child is GPUParticles3D:
			var particles = child as GPUParticles3D
			if particles.emitting:
				max_lifetime = max(max_lifetime, particles.lifetime)
		elif child is AnimationPlayer:
			var anim_player = child as AnimationPlayer
			if anim_player.is_playing():
				var current_anim = anim_player.current_animation
				if current_anim != "":
					var anim_length = anim_player.get_animation(current_anim).length
					max_lifetime = max(max_lifetime, anim_length)
	
	# 如果找到了特效，等待它们完成；否则立即销毁
	if max_lifetime > 0.0:
		await get_tree().create_timer(max_lifetime).timeout
	
	#queue_free()

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
	_process_targets(targets)

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

## 核心：处理检测到的目标（发信号，必要时本地应用效果作为后备）
## [param] targets: Array[Node] 目标列表
func _process_targets(targets: Array[Node]) -> void:
	if not is_instance_valid(instigator):
		push_warning("MagicCircleBase: Cannot process targets, instigator is not valid")
		return
	
	# 准备上下文（中心、类型、施法者等）
	var execution_context = spawn_context.duplicate()
	execution_context["magic_circle_center"] = global_position
	execution_context["magic_circle_type"] = circle_type
	execution_context["instigator"] = instigator
	
	# 发射信号，交由外部系统处理
	targets_detected.emit(targets, execution_context)
	

## 清理资源
func _exit_tree() -> void:
	if is_instance_valid(_timer):
		_timer.queue_free()
	_timer = null
	_duration_timer = null
	effects_to_apply.clear()
	spawn_context.clear()
	instigator = null
	targeting_strategy = null
