extends GameplayEffect
class_name GE_AreaDamage

## 范围伤害效果（已弃用）
## 
## ⚠️ 此效果已弃用，建议使用新的三层架构：
## 1. 在 Status 中配置 `hit_detector: AreaHitDetector` 来检测目标
## 2. 在 Status 中配置 `target_mode: DETECTED_TARGETS` 来应用效果到检测到的目标
## 3. 在 Status 的 `effects` 中使用 `GE_ApplyDamage` 来对每个目标应用伤害
##
## 示例：
## ```gdscript
## # sacrifice_status.tres
## hit_detector: AreaHitDetector (radius: 4.0)
## target_mode: DETECTED_TARGETS
## effects: [GE_ApplyDamage] (damage_multiplier: 0.8)
## period: 1.0
## ```
##
## 此效果保留以保持向后兼容性，但将在未来版本中移除。
## 检测目标周围的所有敌人，并对每个敌人造成伤害
## 适用于：光环伤害、范围持续伤害等

@export var damage_multiplier: float = 1.0  ## 伤害倍数
@export var detection_radius: float = 4.0  ## 检测半径
@export var vital_id: StringName = &"health"  ## 生命值ID
@export var base_damage_attribute: StringName = &"attack"  ## 基础伤害属性
@export var vital_comp_name: StringName = &"GameplayAttributeComponent"  ## 生命值组件名称
@export var instigator_attribute_comp_name: StringName = &"GameplayAttributeComponent"  ## 施法者属性组件名称
@export var ability_comp_name: StringName = &"GameplayAbilityComponent"  ## 技能组件名称

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(target) or not is_instance_valid(instigator):
		return
	
	# 目标必须是 Node3D 才能检测周围敌人
	# 在状态系统中，target 和 instigator 通常是同一个（施法者自己）
	if not target is Node3D:
		push_warning("GE_AreaDamage: Target %s is not Node3D, cannot detect area" % target.name)
		return
	
	var target_3d = target as Node3D
	
	# 获取施法者的属性组件和技能组件
	# 注意：在状态系统中，instigator 是状态的施法者，target 是状态的目标（通常是同一个）
	var attribute_comp = GameplayAbilitySystem.get_component_by_interface(instigator, instigator_attribute_comp_name)
	if not is_instance_valid(attribute_comp):
		push_error("GE_AreaDamage: Instigator %s has no %s component" % [instigator.name, instigator_attribute_comp_name])
		return
	
	var ability_comp = GameplayAbilitySystem.get_component_by_interface(instigator, ability_comp_name)
	if not is_instance_valid(ability_comp):
		push_error("GE_AreaDamage: Instigator %s has no %s component" % [instigator.name, ability_comp_name])
		return
	
	# 计算基础伤害
	var base_damage = attribute_comp.get_value(base_damage_attribute)
	var base_final_damage = base_damage * damage_multiplier
	
	# 检测周围敌人（以 target 为中心，instigator 作为施法者）
	var enemies = _detect_enemies_in_area(target_3d, instigator)
	
	# 对每个敌人造成伤害
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var vital_comp = GameplayAbilitySystem.get_component_by_interface(enemy, vital_comp_name)
		if not is_instance_valid(vital_comp):
			continue
		
		var health_vital = vital_comp.get_vital(vital_id)
		if not is_instance_valid(health_vital):
			continue
		
		# 创建伤害信息
		var damage_info = DamageInfo.new(instigator, ability_comp, base_final_damage)
		
		# 应用伤害
		var final_damage = health_vital.apply_damage(damage_info, enemy)
		
		# 触发伤害事件
		AbilityEventBus.trigger_game_event(&"damage_applied", {
			"target": enemy,
			"instigator": instigator,
			"damage_info": damage_info
		})

## 检测范围内的敌人
## [param] center: Node3D 中心点
## [param] instigator: Node 施法者（用于过滤友军）
## [return] Array[Node] 敌人列表
func _detect_enemies_in_area(center: Node3D, instigator: Node) -> Array[Node]:
	var enemies: Array[Node] = []
	
	# 使用 AreaHitDetector 检测范围内的敌人
	var detector = AreaHitDetector.new()
	detector.detection_radius = detection_radius
	detector.exclude_caster = true
	detector.max_results = 32
	
	# 创建临时上下文
	var context = {
		"detection_position_source": AreaHitDetector.DetectionPositionSource.CASTER_POSITION
	}
	
	# 获取目标列表
	var targets = detector.get_targets(center, context)
	
	# 过滤出敌人（有 HealthComponent 的实体）
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# 跳过自己
		if target == instigator:
			continue
		
		# 检查是否是敌人（有 HealthComponent 的实体）
		var health_comp = GameplayAbilitySystem.get_component_by_interface(target, "HealthComponent")
		if is_instance_valid(health_comp) and target not in enemies:
			enemies.append(target)
	
	return enemies

func _get_description() -> String:
	return "Area damage: %.1f%% damage in %.1f radius\n" % [damage_multiplier * 100, detection_radius]

