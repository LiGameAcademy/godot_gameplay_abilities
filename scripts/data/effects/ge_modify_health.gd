extends GameplayEffect
class_name GE_ModifyHealth

## 修改生命值效果
## 可以用于伤害或治疗

@export var attack_type: AttackType = null
@export var amount: float = 0.0  ## 正数为治疗，负数为伤害

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	# 使用鸭子类型查询组件（不依赖具体类型）
	var health_comp = CombatSystem.get_component_by_interface(target, "HealthComponent")
	if not health_comp:
		push_error("GE_ModifyHealth: Target %s has no HealthComponent!" % target.name)
		return
	
	if amount > 0:
		# 治疗
		health_comp.heal(amount)
		CombatEventBus.emit_healing_applied(target, amount)
	else:
		# 伤害
		var damage_info = DamageInfo.new(
			instigator, 
			null,  # source_component（可选）
			abs(amount), 
			attack_type,
			false  # is_crit
		)
		health_comp.apply_damage(damage_info)

func _get_description() -> String:
	if amount > 0:
		return "Heal target for %s\n" % [amount]
	else:
		var attack_type_name = attack_type.attack_type_display_name if attack_type else "unknown"
		return "Damage target for %s by %s\n" % [abs(amount), attack_type_name]

