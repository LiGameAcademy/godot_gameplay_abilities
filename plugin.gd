@tool
extends EditorPlugin

func _enter_tree() -> void:
	# 插件启用时的初始化
	add_autoload_singleton("CombatSystem", "scripts/singletons/combat_system.gd")
	add_autoload_singleton("DamageCalculator", "scripts/singletons/damage_calculator.gd")
	add_autoload_singleton("CombatEventBus", "scripts/singletons/combat_event_bus.gd")
	add_autoload_singleton("EffectExecutor", "scripts/singletons/effect_executor.gd")

func _exit_tree() -> void:
	# 插件禁用时的清理
	remove_autoload_singleton("CombatSystem")
	remove_autoload_singleton("DamageCalculator")
	remove_autoload_singleton("CombatEventBus")
	remove_autoload_singleton("EffectExecutor")
