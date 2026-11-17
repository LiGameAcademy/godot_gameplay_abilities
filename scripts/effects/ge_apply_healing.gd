extends GameplayEffect
class_name GE_ApplyHealing

## Restores health and reports only the amount committed by this application.

@export var healing_multiplier: float = 1.0 ## 治疗倍数
@export var vital_id : StringName = &"health"
@export var base_healing_attribute : StringName = &"attack"  # 使用攻击力作为基础治疗量
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"
@export var instigator_attribute_comp_name : StringName = &"GameplayAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	context["final_healing"] = 0.0
	var vital_comp: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name) as GameplayVitalAttributeComponent
	if not vital_comp:
		push_error("GE_ApplyHealing: Target %s has no %s component" % [target.name, vital_comp_name])
		return
	
	var health_vital: HealthVital = vital_comp.get_vital(vital_id) as HealthVital
	if not health_vital:
		push_error("GE_ApplyHealing: Target %s has no %s vital" % [target.name, vital_id])
		return

	var attribute_comp : GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(instigator, instigator_attribute_comp_name)
	if not attribute_comp:
		push_error("GE_ApplyHealing: Instigator %s has no %s component" % [instigator.name, instigator_attribute_comp_name])
		return

	var base_healing: float = attribute_comp.get_value(base_healing_attribute)
	var final_healing: float = health_vital.apply_healing(base_healing * healing_multiplier)
	if final_healing <= 0.0:
		return
	
	# 将最终治疗值添加到上下文，供 Cue 使用
	context["final_healing"] = final_healing
	
	AbilityEventBus.trigger_game_event(&"healing_applied", {
		"target": target,
		"instigator": instigator,
		"amount": final_healing
	})

func _get_description() -> String:
	return "Apply %s healing to %s\n" % [healing_multiplier, vital_comp_name]

