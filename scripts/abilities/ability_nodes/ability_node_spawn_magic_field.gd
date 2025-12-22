extends BTAction
class_name AbilityNodeSpawnMagicField

## 生成魔法阵节点
## 职责：在行为树中生成魔法阵

@export_group("Magic Field Config")
## 魔法阵数据（包含场景、持续时间、周期等配置）
@export var magic_field_data: MagicFieldData = null
## 生成位置 Key（从黑板获取，如 "projectile_impact.hit_position"）
@export var position_key: String = "projectile_impact"
## 是否挂载到目标身上（true：作为目标的子节点；false：添加到场景根节点）
@export var attach_to_target: bool = false
## 目标 Key（从黑板获取，如果 attach_to_target 为 true）
@export var target_key: String = "targets"

func _tick(instance: BTInstance, delta: float) -> int:
	var context : AbilityContext = instance.blackboard.get_var("context")
	var instigator = context.instigator
	
	if not is_instance_valid(instigator):
		push_warning("AbilityNodeSpawnMagicField: Instigator is not valid!")
		return Status.FAILURE
	
	# 检查魔法阵数据
	if not is_instance_valid(magic_field_data):
		push_warning("AbilityNodeSpawnMagicField: magic_field_data is not set!")
		return Status.FAILURE
	
	# 检查魔法阵场景
	if not is_instance_valid(magic_field_data.magic_field_scene):
		push_warning("AbilityNodeSpawnMagicField: magic_field_scene is not set in magic_field_data!")
		return Status.FAILURE
	
	# 获取生成位置
	var spawn_position = _get_spawn_position(instance, context)
	if spawn_position == Vector3.INF:
		push_warning("AbilityNodeSpawnMagicField: Cannot determine spawn position!")
		return Status.FAILURE
	
	# 生成魔法阵
	_spawn_magic_field(instigator, spawn_position, magic_field_data, context)
	
	return Status.SUCCESS

## 生成魔法阵
func _spawn_magic_field(
		instigator: Node,
		spawn_position: Vector3,
		data: MagicFieldData,
		context: AbilityContext,
		instance: BTInstance) -> void:
	var magic_field = data.magic_field_scene.instantiate()
	
	# 类型检查
	if not magic_field is MagicFieldBase:
		push_error("AbilityNodeSpawnMagicField: magic_field_scene must be a MagicFieldBase, got: %s" % magic_field.get_class())
		magic_field.queue_free()
		return
	
	var magic_field_base = magic_field as MagicFieldBase
	
	# 确定挂载目标
	var attach_target: Node = null
	if attach_to_target:
		# 从黑板获取目标
		var raw_targets = instance.blackboard.get_var(target_key)
		if raw_targets is Node:
			attach_target = raw_targets as Node
		elif raw_targets is Array and not raw_targets.is_empty():
			attach_target = raw_targets[0] as Node
		
		if not is_instance_valid(attach_target):
			push_warning("AbilityNodeSpawnMagicField: attach_to_target is true but target is not valid, falling back to scene root")
			attach_target = null
	
	# 添加到场景或目标
	if is_instance_valid(attach_target):
		# 挂载到目标身上（作为子节点）
		attach_target.add_child(magic_field_base)
		# 设置本地位置（相对于目标）
		magic_field_base.position = Vector3.ZERO  # 魔法阵在目标位置
	else:
		# 添加到场景根节点
		var level_root = instigator.get_tree().current_scene
		if not is_instance_valid(level_root):
			push_error("AbilityNodeSpawnMagicField: Cannot find current scene root")
			magic_field_base.queue_free()
			return
		level_root.add_child(magic_field_base)
		# 设置世界位置
		magic_field_base.global_position = spawn_position
	
	# 注入运行时依赖
	magic_field_base.instigator = instigator
	
	# 应用魔法阵数据
	data.apply_to_magic_field(magic_field_base)
	
	print("AbilityNodeSpawnMagicField: Spawned magic field at position: %s" % spawn_position)

## 获取生成位置
func _get_spawn_position(instance: BTInstance, context: AbilityContext) -> Vector3:
	# 优先级1: 从黑板获取撞击位置（如果配置了 position_key）
	if not position_key.is_empty():
		var impact_data = instance.blackboard.get_var(position_key)
		if impact_data is Dictionary:
			var impact_dict = impact_data as Dictionary
			if impact_dict.has("hit_position") and impact_dict["hit_position"] is Vector3:
				return impact_dict["hit_position"] as Vector3
	
	# 优先级2: 从 context 获取 hit_position
	if context.hit_position != Vector3.ZERO:
		return context.hit_position
	
	# 优先级3: 从 context 的 custom_data 获取 target_position
	if context.custom_data.has("target_position") and context.custom_data["target_position"] is Vector3:
		return context.custom_data["target_position"] as Vector3
	
	# 优先级4: 使用目标位置
	var raw_targets = instance.blackboard.get_var("targets")
	if raw_targets is Node3D:
		return (raw_targets as Node3D).global_position
	elif raw_targets is Array and not raw_targets.is_empty():
		var first_target = raw_targets[0]
		if first_target is Node3D:
			return (first_target as Node3D).global_position
	
	# 优先级5: 使用施法者位置
	var instigator = context.instigator
	if instigator is Node3D:
		return (instigator as Node3D).global_position
	
	# 默认位置
	return Vector3.INF

