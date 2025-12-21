extends GameplayAbilityFeature
class_name MagicFieldFeature

## 魔法场特性
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
##
## 使用方式：
## ```gdscript
## var ability = ActiveAbility.new()
## var magic_field_feature = MagicFieldFeature.new()
## magic_field_feature.magic_field_data = my_magic_field_data
## ability.features.append(magic_field_feature)
## ```

@export_group("Magic Field Settings")
## 魔法场数据（包含场景、持续时间、周期等配置）
## 业务层可以在编辑器中创建 .tres 资源文件并配置
@export var magic_field_data: MagicFieldData = null

func _init() -> void:
	super("MagicFieldFeature")

## [重写] 技能实际生效时的处理
## 逻辑：应用直接效果（如放置时对施法者的效果），然后生成魔法场
## 魔法场携带 statuses 中的效果作为"弹头"传递给进入区域的目标
func on_cast(ability: GameplayAbility, context: AbilityContext) -> void:
	var ability_comp = context.ability_comp
	var input_target = context.input_target
	var instigator = context.instigator
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("MagicFieldFeature: Cannot cast, invalid ability_comp or instigator")
		return
	
	# 1. 应用直接效果（如放置时对施法者应用buff等）
	# 注意：effects 应用到施法者或通过 targeting_strategy 获取的目标
	ability._apply_initial_effects(instigator, input_target, context)
	
	# 2. 检查魔法场数据
	if not is_instance_valid(magic_field_data):
		push_warning("MagicFieldFeature: magic_field_data is not set for ability %s" % ability.ability_id)
		return
	
	# 3. 检查魔法场场景
	if not is_instance_valid(magic_field_data.magic_field_scene):
		push_warning("MagicFieldFeature: magic_field_scene is not set in magic_field_data for ability %s" % ability.ability_id)
		return
	
	# 4. 确定生成位置
	var spawn_position = _get_spawn_position(instigator, input_target, context)
	if spawn_position == Vector3.INF:
		return
	
	# 5. 生成魔法场
	_spawn_magic_field(instigator, spawn_position, magic_field_data, context)
	
	# 注意：魔法场是"放置即不管"（Place and Forget），所以这里不需要阻塞
	# 魔法场的效果是在目标进入区域时应用的（不在 on_cast 中应用），
	# 所以需要立即完成技能
	ability._ability_completion()

## 生成魔法场
## [param] instigator: Node 施法者
## [param] spawn_position: Vector3 生成位置
## [param] data: MagicFieldData 魔法场数据
## [param] context: AbilityContext 上下文信息
func _spawn_magic_field(
		instigator: Node,
		spawn_position: Vector3,
		data: MagicFieldData,
		context: AbilityContext) -> void:
	var magic_field = data.magic_field_scene.instantiate()
	
	# 类型检查
	if not magic_field is MagicFieldBase:
		push_error("MagicFieldFeature: magic_field_scene must be a MagicFieldBase, got: %s" % magic_field.get_class())
		magic_field.queue_free()
		return
	
	var magic_field_base = magic_field as MagicFieldBase
	
	# 添加到场景（通常加到当前关卡的独立容器中）
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("MagicFieldFeature: Cannot find current scene root")
		magic_field_base.queue_free()
		return
	
	level_root.add_child(magic_field_base)
	
	# 设置位置
	magic_field_base.global_position = spawn_position
	
	# 注入运行时依赖
	magic_field_base.instigator = instigator
	
	# 应用魔法场数据（持续时间等）
	data.apply_to_magic_field(magic_field_base)
	
	print("MagicFieldFeature: Spawned magic field for ability %s at position: %s" % [context.ability_id, spawn_position])

## 获取生成位置
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（可选）
## [param] context: AbilityContext 上下文信息
## [return] Vector3 生成位置
func _get_spawn_position(instigator: Node, input_target: Node, context: AbilityContext) -> Vector3:
	# 优先级1: 从 context 的 custom_data 或 hit_position 获取 spawn_position
	if context.hit_position != Vector3.ZERO:
		var pos = context.hit_position
		print("MagicFieldFeature: Using hit_position from context: %s" % pos)
		return pos
	
	if context.custom_data.has("target_position") and context.custom_data["target_position"] is Vector3:
		var pos = context.custom_data["target_position"] as Vector3
		print("MagicFieldFeature: Using target_position from custom_data: %s" % pos)
		return pos
	
	# 优先级2: 使用目标位置
	if is_instance_valid(input_target) and input_target is Node3D:
		var target_3d = input_target as Node3D
		var pos = target_3d.global_position
		print("MagicFieldFeature: Using input_target position: %s" % pos)
		return pos
	
	# 优先级3: 使用施法者位置
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		var pos = instigator_3d.global_position
		print("MagicFieldFeature: Using instigator position: %s" % pos)
		return pos
	
	# 默认位置
	push_warning("MagicFieldFeature: No valid position found in context, using Vector3.INF")
	return Vector3.INF

## [重写] 获取特性描述
func get_description() -> String:
	if not is_instance_valid(magic_field_data):
		return "魔法场特性（未配置）"
	return "魔法场特性"

