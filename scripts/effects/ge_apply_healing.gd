extends GameplayEffect
class_name GE_ApplyHealing

## 应用治疗效果
## 恢复目标的生命值

@export var healing_multiplier: float = 1.0 ## 治疗倍数
@export var vital_id : StringName = &"health"
@export var base_healing_attribute : StringName = &"attack"  # 使用攻击力作为基础治疗量
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"
@export var instigator_attribute_comp_name : StringName = &"GameplayAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not vital_comp:
		push_error("GE_ApplyHealing: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	var health_vital : HealthVital = vital_comp.get_vital(vital_id)
	if not health_vital:
		push_error("GE_ApplyHealing: Target %s has no %s vital" % [target.name, vital_id])
		return

	var attribute_comp : GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(instigator, instigator_attribute_comp_name)
	if not attribute_comp:
		push_error("GE_ApplyHealing: Instigator %s has no %s component" % [instigator.name, instigator_attribute_comp_name])
		return

	var base_healing = attribute_comp.get_value(base_healing_attribute)
	var final_healing = base_healing * healing_multiplier
	
	# 应用治疗
	health_vital.heal(final_healing)
	
	# 将最终治疗值添加到上下文，供 Cue 使用
	context["final_healing"] = final_healing
	
	AbilityEventBus.trigger_game_event(&"healing_applied", {
		"target": target,
		"instigator": instigator,
		"amount": final_healing
	})

func _get_description() -> String:
	return "Apply %s healing to %s\n" % [healing_multiplier, vital_comp_name]

