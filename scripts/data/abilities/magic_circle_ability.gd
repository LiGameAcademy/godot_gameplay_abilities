extends ActiveAbility
class_name MagicCircleAbility

## 魔法阵技能
## 核心思想：在指定位置创建魔法阵，魔法阵检测范围内的目标并应用效果
##
## 架构说明：
## - Ability (施法者): 负责计算"在哪里放"（位置、朝向），并实例化魔法阵
## - MagicCircle (魔法阵): 负责"检测谁"（范围检测），以及"应用什么效果"
## - Effect (效果): 魔法阵身上携带的"配置清单"，检测到目标时应用
##
## 设计原则：
## - 魔法阵是"检测器"，负责把"效果"应用到范围内的目标
## - 魔法阵不关心伤害公式，只关心范围和检测
## - 检测到目标时，将携带的 Effect 应用给目标

@export_group("Magic Circle Settings")
## 魔法阵数据（包含场景、类型、周期等配置）
## 业务层可以在编辑器中创建 .tres 资源文件并配置
@export var magic_circle_data: MagicCircleData = null

## [重写] 施放技能
## 逻辑：生成魔法阵，并把 target_effects 作为"效果"传递给魔法阵
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("MagicCircleAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 应用自身效果（后坐力、耗蓝等）
	_apply_caster_effects(instigator, context)
	
	# 2. 检查魔法阵数据
	if not is_instance_valid(magic_circle_data):
		push_warning("MagicCircleAbility: magic_circle_data is not set for ability %s" % ability_id)
		return
	
	# 3. 检查魔法阵场景
	if not is_instance_valid(magic_circle_data.magic_circle_scene):
		push_warning("MagicCircleAbility: magic_circle_scene is not set in magic_circle_data for ability %s" % ability_id)
		return
	
	# 4. 确定生成位置
	var spawn_position = _get_spawn_position(instigator, input_target, context)
	
	# 5. 获取要传递的效果列表（优先使用 magic_circle_data 的效果，否则使用 target_effects）
	var effects_to_apply = magic_circle_data.effects if not magic_circle_data.effects.is_empty() else target_effects
	if effects_to_apply.is_empty():
		effects_to_apply = effects  # 向后兼容：使用基类的 effects
	if effects_to_apply.is_empty():
		push_warning("MagicCircleAbility: No effects configured for ability %s. Magic circle will spawn but won't deal damage. Please configure effects in magic_circle_data or target_effects in the ability resource." % ability_id)
	
	# 调试日志
	print("MagicCircleAbility: Casting %s at position: %s with %d effect(s)" % [ability_id, spawn_position, effects_to_apply.size()])
	
	# 6. 生成魔法阵
	_spawn_magic_circle(instigator, spawn_position, magic_circle_data, effects_to_apply, context)

## 生成魔法阵
## [param] instigator: Node 施法者
## [param] spawn_position: Vector3 生成位置
## [param] data: MagicCircleData 魔法阵数据
## [param] effects_to_apply: Array[GameplayEffect] 效果列表
## [param] context: Dictionary 上下文信息
func _spawn_magic_circle(
		instigator: Node, 
		spawn_position: Vector3, 
		data: MagicCircleData, 
		effects_to_apply: Array, 
		context: Dictionary = {}) -> void:
	var magic_circle = data.magic_circle_scene.instantiate()
	
	# 类型检查
	if not magic_circle is MagicCircleBase:
		push_error("MagicCircleAbility: magic_circle_scene must be a MagicCircleBase, got: %s" % magic_circle.get_class())
		magic_circle.queue_free()
		return
	
	var magic_circle_base = magic_circle as MagicCircleBase
	
	# 添加到场景（通常加到当前关卡的独立容器中）
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("MagicCircleAbility: Cannot find current scene root")
		magic_circle_base.queue_free()
		return
	
	level_root.add_child(magic_circle_base)
	
	# 设置位置
	magic_circle_base.global_position = spawn_position
	print("MagicCircleAbility: Setting magic circle position to: %s" % spawn_position)
	
	# 注入运行时依赖
	magic_circle_base.instigator = instigator
	
	# 应用魔法阵数据（类型、周期等）
	data.apply_to_magic_circle(magic_circle_base)
	
	# 注入效果列表（如果 magic_circle_data 没有配置效果，使用传入的效果）
	if magic_circle_base.effects_to_apply.is_empty():
		magic_circle_base.effects_to_apply = effects_to_apply.duplicate(true)
	
	# 注入目标筛选策略（如果 magic_circle_data 没有配置策略，使用 Ability 的策略）
	if not is_instance_valid(magic_circle_base.targeting_strategy):
		if is_instance_valid(targeting_strategy):
			magic_circle_base.targeting_strategy = targeting_strategy.duplicate(true)
	
	# 连接信号：由能力层处理筛选与效果应用
	magic_circle_base.targets_detected.connect(_on_magic_circle_targets_detected.bind(magic_circle_base, effects_to_apply))
	
	# 传递上下文
	var circle_context = context.duplicate()
	circle_context["ability_id"] = ability_id
	circle_context["instigator"] = instigator
	circle_context["spawn_position"] = spawn_position
	magic_circle_base.spawn_context = circle_context
	
	print("MagicCircleAbility: Spawned magic circle for ability %s at position: %s" % [ability_id, spawn_position])

## 处理魔法阵检测到的目标（能力层负责筛选与应用效果）
## [param] targets: Array[Node] 魔法阵检测到的目标
## [param] execution_context: Dictionary 魔法阵提供的上下文
## [param] magic_circle_base: MagicCircleBase 实例
## [param] effects_to_apply: Array[GameplayEffect] 传递给魔法阵的效果
func _on_magic_circle_targets_detected(
		targets: Array,
		execution_context: Dictionary,
		magic_circle_base: MagicCircleBase,
		effects_to_apply: Array) -> void:
	if targets.is_empty():
		print("MagicCircleAbility: No targets detected for ability %s" % ability_id)
		return
	
	var instigator = execution_context.get("instigator", magic_circle_base.instigator)
	if not is_instance_valid(instigator):
		print("MagicCircleAbility: Instigator is not valid for ability %s" % ability_id)
		return
	
	# 使用能力层的 targeting_strategy 进行筛选
	var final_targets = _filter_targets_with_strategy(targets, instigator, execution_context, targeting_strategy)
	
	# 如果能力层筛选后为空，直接返回
	if final_targets.is_empty():
		print("MagicCircleAbility: No targets detected after filtering for ability %s" % ability_id)
		return
	
	# 准备效果上下文
	var apply_context = execution_context.duplicate()
	apply_context["ability_id"] = ability_id
	
	# 应用效果（使用传入的 effects_to_apply，保持与投射物/数据层解耦）
	_apply_effects_to_targets(effects_to_apply, instigator, final_targets, apply_context)

## 获取生成位置
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（可选）
## [param] context: Dictionary 上下文信息
## [return] Vector3 生成位置
func _get_spawn_position(instigator: Node, input_target: Node, context: Dictionary) -> Vector3:
	# 优先级1: 从 context 获取 spawn_position
	if context.has("spawn_position") and context["spawn_position"] is Vector3:
		var pos = context["spawn_position"] as Vector3
		print("MagicCircleAbility: Using spawn_position from context: %s" % pos)
		return pos
	
	# 优先级2: 从 context 获取 hit_position（投射物撞击位置）
	if context.has("hit_position") and context["hit_position"] is Vector3:
		var pos = context["hit_position"] as Vector3
		print("MagicCircleAbility: Using hit_position from context: %s" % pos)
		return pos
	
	# 优先级3: 使用目标位置
	if is_instance_valid(input_target) and input_target is Node3D:
		var target_3d = input_target as Node3D
		var pos = target_3d.global_position
		print("MagicCircleAbility: Using input_target position: %s" % pos)
		return pos
	
	# 优先级4: 使用施法者位置
	if instigator is Node3D:
		var instigator_3d = instigator as Node3D
		var pos = instigator_3d.global_position
		print("MagicCircleAbility: Using instigator position: %s" % pos)
		return pos
	
	# 默认位置
	push_warning("MagicCircleAbility: No valid position found in context, using Vector3.ZERO")
	return Vector3.ZERO
