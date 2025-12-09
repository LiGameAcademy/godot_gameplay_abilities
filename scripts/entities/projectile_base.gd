extends Area3D
class_name ProjectileBase

## 投射物基类
## 职责：运动控制、碰撞检测、效果传递
##
## 设计原则：
## - 投射物是"载具"（Carrier），负责把"弹头"（Effect）运送到目标
## - 投射物不关心伤害公式，只关心飞行和碰撞
## - 撞击时，将携带的 Effect 应用给目标

# ========== 运行时配置（由 ProjectileData 或 Ability 注入）==========
## 飞行速度（单位/秒）
var speed: float = 20.0
## 最大生命周期（秒）
var max_lifetime: float = 5.0
## 追踪加速度（0 为直线，>0 为追踪）
## 值越大，转向越快
var homing_acceleration: float = 0.0

## 是否穿透（穿透时不会在撞击后销毁）
var piercing: bool = false
## 最大穿透次数（-1 为无限）
var max_pierce_count: int = -1

# ========== 运行时数据（由 Ability 注入）==========
## 施法者（用于过滤碰撞，避免击中自己）
var instigator: Node = null
## 携带的弹头（Effect 列表）
var payload_effects: Array[GameplayEffect] = []
## 追踪目标（如果设置了，会追踪此目标）
var target_reference: Node3D = null
## 移动策略实例（由 ProjectileData 注入）
var movement_strategy: ProjectileMovementStrategy = null
## 撞击时的上下文信息（会传递给 Effect）
var impact_context: Dictionary = {}
## 撞击时生成的 AoE 场景（如果设置了，会生成 AoE 实体而不是直接应用效果）
var impact_aoe_scene: PackedScene = null

# ========== 内部状态 ==========
## 当前速度向量（策略类需要访问）
var velocity: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _pierce_count: int = 0

func _ready() -> void:
	# 设置碰撞层（投射物本身不在任何层，只检测其他层）
	collision_layer = 0
	# 注意：collision_mask 应该在场景中配置，或在子类中通过 @export 设置
	
	# 碰撞监听
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 调试：输出投射物生成信息
	print("ProjectileBase: _ready() - position: %s, instigator: %s" % [
		global_position,
		instigator.name if is_instance_valid(instigator) else "null"
	])
	
	# 注意：速度初始化延迟到 apply_to_projectile() 之后
	# 因为 speed 可能在 _ready() 之后才被设置
	# 如果 speed 已经设置，则立即初始化
	if speed > 0.0:
		initialize_velocity()

func _physics_process(delta: float) -> void:
	# 1. 生命周期检查
	_timer += delta
	if _timer >= max_lifetime:
		print("ProjectileBase: Lifetime expired (%.2f >= %.2f)" % [_timer, max_lifetime])
		_destroy_projectile()
		return
	
	# 2. 运动逻辑（策略模式）
	# 如果有策略，使用策略计算速度；否则保持初始速度（直线移动）
	if is_instance_valid(movement_strategy):
		var old_velocity = velocity
		velocity = movement_strategy.process_movement(self, delta)
		# 调试：如果速度异常，输出警告
		if velocity.length_squared() < 0.01 and old_velocity.length_squared() > 0.01:
			push_warning("ProjectileBase: Movement strategy returned zero velocity!")
	# 注意：如果没有策略，velocity 保持 initialize_velocity() 设置的初始值
	
	# 3. 应用位移
	global_position += velocity * delta
	
	# 4. 更新朝向（可选，让箭矢始终头朝前）
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

## 处理碰撞（Body）
func _on_body_entered(body: Node3D) -> void:
	_handle_impact(body)

## 处理碰撞（Area）
func _on_area_entered(area: Area3D) -> void:
	# 处理 Hitbox 等逻辑
	# 通常 Area 的 owner 是实际的实体
	var target = area.owner if area.owner else area
	_handle_impact(target)

## 【核心】撞击结算
func _handle_impact(target: Node) -> void:
	# 1. 过滤检查
	if not _should_impact(target):
		print("ProjectileBase: Impact ignored for target: %s" % (target.name if target else "null"))
		return
	
	print("ProjectileBase: Impact detected - target: %s, position: %s" % [target.name if target else "null", global_position])
	
	# 2. 获取撞击位置
	var hit_pos = global_position  # 或者更精确的碰撞点
	
	# 3. 处理 AoE 或单体效果
	if is_instance_valid(impact_aoe_scene):
		# A. 如果配置了 AoE，就生成 AoE 实体
		_spawn_aoe_entity(hit_pos)
	else:
		# B. 如果没配置 AoE，就退化为单体攻击（旧逻辑）
		_deliver_payload(target)
	
	# 4. 处理穿透
	if piercing and (max_pierce_count < 0 or _pierce_count < max_pierce_count):
		_pierce_count += 1
		print("ProjectileBase: Piercing through (count: %d)" % _pierce_count)
		# 穿透时继续飞行，不销毁
		return
	
	# 5. 销毁投射物
	print("ProjectileBase: Destroying projectile after impact")
	_destroy_projectile()

## 检查是否应该撞击此目标
func _should_impact(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	
	# 忽略地面和静态环境（GridMap、StaticBody3D 等）
	var target_name = target.name if target else ""
	if target_name.contains("Floor") or target_name.contains("Ground") or target_name.contains("Wall") or target_name.contains("GridMap"):
		# 只忽略静态环境，不忽略可交互的物体
		# 如果需要更精确的控制，可以通过碰撞层/遮罩来实现
		return false
	
	# 忽略施法者及其所有子节点
	if is_instance_valid(instigator):
		# 直接比较
		if target == instigator:
			return false
		
		# 检查是否是施法者的子节点
		var parent = target.get_parent()
		while is_instance_valid(parent):
			if parent == instigator:
				return false
			parent = parent.get_parent()
		
		# 检查是否是施法者的子节点（通过 owner）
		if target.has_method("get") and target.get("owner") == instigator:
			return false
	
	# 调试：输出碰撞信息（只在非静态环境时输出）
	if not (target_name.contains("Floor") or target_name.contains("Ground") or target_name.contains("Wall") or target_name.contains("GridMap")):
		print("ProjectileBase: Impact check - target: %s, instigator: %s" % [target_name, instigator.name if is_instance_valid(instigator) else "null"])
	
	# 可以在这里添加阵营检查、过滤器等
	# 例如：
	# if not is_enemy(instigator, target):
	#     return false
	
	return true

## 传递弹头（应用 Effect）
func _deliver_payload(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# 构建撞击上下文
	var context = impact_context.duplicate()
	context["hit_position"] = global_position
	context["hit_direction"] = velocity.normalized()
	context["projectile"] = self
	
	# 应用所有携带的效果
	for effect in payload_effects:
		if not is_instance_valid(effect):
			continue
		
		# 【关键】将 Effect 应用给目标
		# Effect 会自己处理伤害、状态等逻辑
		effect.apply(target, instigator, context)

## 初始化速度向量
## 应该在 apply_to_projectile() 之后调用，确保 speed 已正确设置
func initialize_velocity() -> void:
	# 初始化方向（使用 -Z 轴作为前进方向，Godot 默认）
	var forward = -global_transform.basis.z
	velocity = forward * speed
	
	# 调试日志
	print("ProjectileBase: Initialized velocity - speed: %.1f, direction: %s, velocity: %s" % [
		speed,
		forward,
		velocity
	])
	
	if speed <= 0.0:
		push_warning("ProjectileBase: speed is %f, projectile may not move" % speed)

## 生成 AoE 实体
## [param] hit_pos: Vector3 撞击位置
func _spawn_aoe_entity(hit_pos: Vector3) -> void:
	if not is_instance_valid(impact_aoe_scene):
		push_warning("ProjectileBase: impact_aoe_scene is not valid")
		return
	
	# 实例化 AoE 场景
	var aoe_instance = impact_aoe_scene.instantiate()
	if not aoe_instance is AoEBase:
		push_error("ProjectileBase: impact_aoe_scene must be an AoEBase, got: %s" % aoe_instance.get_class())
		aoe_instance.queue_free()
		return
	
	var aoe_base = aoe_instance as AoEBase
	
	# 添加到场景（通常加到当前关卡的独立容器中）
	var level_root = get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("ProjectileBase: Cannot find current scene root")
		aoe_base.queue_free()
		return
	
	level_root.add_child(aoe_base)
	
	# 设置位置
	aoe_base.global_position = hit_pos
	
	# 注入数据
	aoe_base.instigator = instigator
	# 把投射物携带的弹头转交给 AoE（深拷贝，避免引用问题）
	aoe_base.effects_to_apply = payload_effects.duplicate(true)
	# 传递上下文
	var aoe_context = impact_context.duplicate()
	aoe_context["hit_position"] = hit_pos
	aoe_context["hit_direction"] = velocity.normalized()
	aoe_context["projectile"] = self
	aoe_base.spawn_context = aoe_context
	
	print("ProjectileBase: Spawned AoE entity at position: %s" % hit_pos)

## 销毁投射物
func _destroy_projectile() -> void:
	# 可以在这里播放爆炸特效、音效等
	# 或者生成另一个特效对象
	
	# 清理引用
	instigator = null
	target_reference = null
	movement_strategy = null
	payload_effects.clear()
	impact_context.clear()
	impact_aoe_scene = null
	
	# 销毁节点
	queue_free()
