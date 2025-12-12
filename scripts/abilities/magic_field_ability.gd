extends ActiveAbility
class_name MagicFieldAbility

## 魔法场技能
## 核心思想：载具与弹头分离（Carrier-Payload Pattern）
##
## 架构说明：
## - Ability (施法者): 负责计算"在哪里放"（位置、朝向），并实例化魔法场
## - MagicField (载具): 负责"检测谁"（事件驱动的区域检测），以及"应用什么弹头"
## - Status/Effect (弹头): 魔法场身上携带的"配置清单"，检测到目标时应用
##
## 设计原则：
## - 魔法场是"载具"，负责把"弹头"（Status/Effect）传递给进入区域的目标
## - 魔法场不关心伤害公式，只关心区域检测和弹头传递
## - 使用 Area3D 的事件驱动机制（body_entered/body_exited）维护目标列表

@export_group("Magic Field Settings")
## 魔法场数据（包含场景、持续时间、周期等配置）
## 业务层可以在编辑器中创建 .tres 资源文件并配置
@export var magic_field_data: MagicFieldData = null

## [重写] 施放技能
## 逻辑：生成魔法场
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("MagicFieldAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 检查魔法场数据
	if not is_instance_valid(magic_field_data):
		push_warning("MagicFieldAbility: magic_field_data is not set for ability %s" % ability_id)
		return
	
	# 2. 检查魔法场场景
	if not is_instance_valid(magic_field_data.magic_field_scene):
		push_warning("MagicFieldAbility: magic_field_scene is not set in magic_field_data for ability %s" % ability_id)
		return
	
	# 3. 确定生成位置
	var spawn_position = _get_spawn_position(instigator, input_target, context)
	if spawn_position == Vector3.INF:
		return

	# 4. 生成魔法场
	_spawn_magic_field(instigator, spawn_position, magic_field_data, context)

## 生成魔法场
## [param] instigator: Node 施法者
## [param] spawn_position: Vector3 生成位置
## [param] data: MagicFieldData 魔法场数据
## [param] context: Dictionary 上下文信息
func _spawn_magic_field(
		instigator: Node, 
		spawn_position: Vector3, 
		data: MagicFieldData, 
		context: Dictionary = {}) -> void:
	var magic_field = data.magic_field_scene.instantiate()
	
	# 类型检查
	if not magic_field is MagicFieldBase:
		push_error("MagicFieldAbility: magic_field_scene must be a MagicFieldBase, got: %s" % magic_field.get_class())
		magic_field.queue_free()
		return
	
	var magic_field_base = magic_field as MagicFieldBase
	
	# 添加到场景（通常加到当前关卡的独立容器中）
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("MagicFieldAbility: Cannot find current scene root")
		magic_field_base.queue_free()
		return
	
	level_root.add_child(magic_field_base)
	
	# 设置位置
	magic_field_base.global_position = spawn_position
	
	# 注入运行时依赖
	magic_field_base.instigator = instigator
	
	# 应用魔法场数据（持续时间等）
	data.apply_to_magic_field(magic_field_base)
	
	print("MagicFieldAbility: Spawned magic field for ability %s at position: %s" % [ability_id, spawn_position])

## 获取生成位置
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（可选）
## [param] context: Dictionary 上下文信息
## [return] Vector3 生成位置
func _get_spawn_position(instigator: Node, input_target: Node, context: Dictionary) -> Vector3:
	# 优先级1: 从 context 获取 spawn_position
	if context.has("target_position") and context["target_position"] is Vector3:
		var pos = context["target_position"] as Vector3
		print("MagicFieldAbility: Using target_position from context: %s" % pos)
		return pos
	
	# 优先级2: 使用目标位置
	if is_instance_valid(input_target) and input_target is Node3D:
		var target_3d = input_target as Node3D
		var pos = target_3d.global_position
		print("MagicFieldAbility: Using input_target position: %s" % pos)
		return pos
	
	# 优先级3: 使用施法者位置
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		var pos = instigator_3d.global_position
		print("MagicFieldAbility: Using instigator position: %s" % pos)
		return pos
	
	# 默认位置
	push_warning("MagicFieldAbility: No valid position found in context, using Vector3.ZERO")
	return Vector3.INF

