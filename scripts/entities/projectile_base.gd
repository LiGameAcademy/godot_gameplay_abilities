extends Area3D
class_name ProjectileBase

## 投射物基类
## 职责：运动控制、碰撞检测、弹头传递
##
## 设计原则（载具-弹头模式）：
## - 投射物是"载具"（Carrier），负责运输"弹头"（Payload：Status/Effect）
## - 投射物不包含能力逻辑（如伤害计算），只负责将弹头传递给目标
## - 在碰撞时，投射物将携带的弹头应用给目标
## - 通过信号系统通知外部系统（如技能系统），用于处理穿透、销毁等逻辑

# ========== 运行时配置（由 ProjectileData 注入）==========
## 飞行速度（单位/秒）
var speed: float = 0.0
## 最大生命周期（秒）
var max_lifetime: float = 5.0
## 追踪加速度（0 为直线，>0 为追踪）
## 值越大，转向越快
var homing_acceleration: float = 0.0

## 是否穿透（穿透时不会在撞击后销毁）
var piercing: bool = false
## 最大穿透次数（-1 为无限）
var max_pierce_count: int = -1

## 移动策略实例（由 ProjectileData 注入）
var movement_strategy: ProjectileMovementStrategy = null

# ========== 运行时数据（由 Ability 注入）==========
## 施法者（用于过滤碰撞，避免击中自己，以及作为弹头的施加者）
var instigator: Node = null
## 追踪目标（如果设置了，会追踪此目标）
var target_reference: Node3D = null

# ========== 弹头舱（Payload Bay）==========
## 携带的状态列表（弹头）
## 当投射物击中目标时，会将此列表中的状态应用给目标
var payload_statuses: Array[GameplayStatusData] = []

# ========== 内部状态 ==========
## 当前速度向量（策略类需要访问）
var velocity: Vector3 = Vector3.ZERO
## 穿透次数（由外部系统管理，投射物只提供访问接口）
var pierce_count: int = 0
var _timer: float = 0.0

## 销毁时产生的魔法阵
var on_destory_magic_field_data : MagicFieldData
## 是否只在撞击时产生
var spawn_on_hit : bool = false
## 最近一次直接命中的目标（用于基于目标标签的反应/连携逻辑）
var _last_hit_target: Node = null
## 触发销毁魔法场生成所需的命中目标标签（由 ProjectileData 注入）
var required_trigger_target_tags: Array[StringName] = []

# ========== 信号系统 ==========
## 投射物撞击时触发
## [param] hit_position: Vector3 撞击位置
## [param] direct_hit_target: Node 直接命中的目标（可选）
## [param] context: Dictionary 上下文信息
signal impact_triggered(hit_position: Vector3, direct_hit_target: Node, context: Dictionary)

## 投射物超时时触发
## [param] position: Vector3 超时位置
## [param] context: Dictionary 上下文信息
signal timeout_triggered(position: Vector3, context: Dictionary)

func _ready() -> void:
	# 设置碰撞层（投射物本身不在任何层，只检测其他层）
	collision_layer = 0
	# 注意：collision_mask 应该在场景中配置，或在子类中通过 @export 设置
	
	# 碰撞监听
	area_entered.connect(_on_area_entered)
	
	# 调试：输出投射物生成信息
	print("ProjectileBase: _ready() - position: %s, instigator: %s" % [
		global_position,
		instigator.name if is_instance_valid(instigator) else "null"
	])
	
func _physics_process(delta: float) -> void:
	# 1. 生命周期检查
	_timer += delta
	if _timer >= max_lifetime:
		print("ProjectileBase: Lifetime expired (%.2f >= %.2f)" % [_timer, max_lifetime])
		# 发射超时信号，让外部系统（如技能系统）处理超时状态
		timeout_triggered.emit(global_position, {"projectile": self})
		# 投射物自己管理销毁
		destroy()
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

## 销毁投射物（公共方法，由外部系统调用）
## 投射物不自动销毁，必须由外部系统（如 ProjectileAbility）调用此方法
## [param] on_hit: bool 是否因撞击而销毁（用于判断是否生成撞击魔法场）
func destroy(on_hit: bool = false) -> void:
	# 生成销毁时的魔法场（如果配置了）
	if is_instance_valid(on_destory_magic_field_data) and is_instance_valid(instigator):
		if not spawn_on_hit or on_hit:
			# 检查是否满足生成魔法场的反应条件（如：命中带燃烧状态的目标才触发爆炸）
			if _can_spawn_impact_field():
				_spawn_impact_field(instigator, global_position, on_destory_magic_field_data, {})

	# 清理引用
	instigator = null
	target_reference = null
	movement_strategy = null
	payload_statuses.clear()
	
	# 销毁节点
	queue_free()

## 【核心】撞击结算
func _handle_impact(target: Node) -> void:
	# 1. 过滤检查
	if not _should_impact(target):
		print("ProjectileBase: Impact ignored for target: %s" % (target.name if target else "null"))
		return
	
	print("ProjectileBase: Impact detected - target: %s, position: %s" % [target.name if target else "null", global_position])
	
	# 2. 记录最近一次命中的目标（用于反应/连携逻辑）
	_last_hit_target = target
	
	# 3. 获取撞击位置和方向
	var hit_pos = global_position  # 或者更精确的碰撞点
	var hit_dir = velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.ZERO
	
	# 4. 传递弹头（Payload）：将携带的状态和效果应用给目标
	_deliver_payload(target, hit_pos, hit_dir)
	
	# 5. 处理穿透逻辑
	var should_consume = true  # 默认消耗（销毁）
	if piercing:
		# 检查穿透次数
		if max_pierce_count < 0 or pierce_count < max_pierce_count:
			# 可以继续穿透
			should_consume = false
			pierce_count += 1
			print("ProjectileBase: Piercing through (count: %d)" % pierce_count)
	
	# 6. 发射撞击信号，通知外部系统（如技能系统）
	# 注意：投射物已经自己处理了穿透逻辑和销毁决策
	impact_triggered.emit(hit_pos, target, {
		"hit_direction": hit_dir,
		"projectile": self,
		"consumed": should_consume  # 告知外部系统是否已销毁
	})
	
	# 7. 如果应该消耗，销毁投射物
	if should_consume:
		destroy(true)

## 检查是否可以生成撞击魔法场（用于元素反应/连携）
## 例如：只在命中带有特定标签（如燃烧）的目标时才生成爆炸魔法场
func _can_spawn_impact_field() -> bool:
	if not is_instance_valid(on_destory_magic_field_data):
		return false
	
	# 如果没有配置触发标签要求，则默认允许生成（保持向后兼容）
	if required_trigger_target_tags.is_empty():
		return true
	
	# 必须有最近一次命中的目标
	if not is_instance_valid(_last_hit_target):
		return false
	
	# 使用标签系统检查命中目标是否满足触发条件
	return TagManager.has_all_tags(_last_hit_target, required_trigger_target_tags)

## 传递弹头（Payload）：将携带的状态和效果应用给目标
## [param] target: Node 目标实体（直接命中的目标）
## [param] hit_position: Vector3 撞击位置
## [param] hit_direction: Vector3 撞击方向
func _deliver_payload(target: Node, hit_position: Vector3, hit_direction: Vector3) -> void:
	if not is_instance_valid(target) or not is_instance_valid(instigator):
		return
	
	# 准备上下文信息
	var context = {
		"hit_position": hit_position,
		"hit_direction": hit_direction,
		"projectile": self,
		"input_target": target  # 直接命中的目标
	}
	
	# 应用状态（弹头）
	# 注意：状态会应用到目标，不处理目标检测（Status 只应用到自己）
	for status_data in payload_statuses:
		if not is_instance_valid(status_data):
			continue
		
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 应用状态（状态只应用到自己）
			status_comp.apply_status(status_data, instigator, 1, context)
		else:
			push_warning("ProjectileBase: Target %s has no GameplayStatusComponent, cannot apply status %s" % [target.name, status_data.status_id])
	
## 检查是否应该撞击此目标
func _should_impact(target: Node) -> bool:
	if not is_instance_valid(target):
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
	
	return true

## 生成撞击魔法场（爆炸）
## 这个方法的逻辑实际上是复用了 MagicFieldAbility 的核心生成逻辑
## 但我们不需要依赖 MagicFieldAbility 类，只需要依赖 MagicFieldData 和 MagicFieldBase 即可
func _spawn_impact_field(
		instigator: Node, 
		spawn_position: Vector3, 
		data: MagicFieldData, 
		context: Dictionary) -> void:
			
	if not is_instance_valid(data) or not is_instance_valid(data.magic_field_scene):
		push_warning("ProjectileBase: Cannot spawn impact field, data or scene is invalid.")
		return
	
	if not is_instance_valid(instigator):
		push_warning("ProjectileBase: Cannot spawn impact field, instigator is invalid.")
		return

	# 1. 实例化载具
	var magic_field = data.magic_field_scene.instantiate()
	if not magic_field is MagicFieldBase:
		magic_field.queue_free()
		return
	var magic_field_base = magic_field as MagicFieldBase
	
	# 2. 添加到场景
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_warning("ProjectileBase: Cannot find current scene root, cannot spawn impact field.")
		magic_field_base.queue_free()
		return
	
	level_root.add_child(magic_field_base)
		
	# 3. 配置载具
	magic_field_base.global_position = spawn_position
	magic_field_base.instigator = instigator
	
	# 4. 装载弹头（应用数据配置）
	data.apply_to_magic_field(magic_field_base)
	
	# print("ProjectileAbility: Spawned impact field at %s" % spawn_position)

## 处理碰撞（Area）
func _on_area_entered(area: Area3D) -> void:
	# 处理 Hitbox 等逻辑
	# 通常 Area 的 owner 是实际的实体
	var target = area.owner if area.owner else area
	_handle_impact(target)
