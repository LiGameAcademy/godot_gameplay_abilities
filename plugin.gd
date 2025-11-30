@tool
extends EditorPlugin

func _enter_tree() -> void:
	# 插件启用时的初始化
	add_autoload_singleton("CombatSystem", "res://addons/godot_gameplay_abilities/singletons/combat_system.gd")
	add_autoload_singleton("DamageCalculator", "res://addons/godot_gameplay_abilities/singletons/damage_calculator.gd")
	add_autoload_singleton("CombatEventBus", "res://addons/godot_gameplay_abilities/singletons/combat_event_bus.gd")
	add_autoload_singleton("EffectExecutor", "res://addons/godot_gameplay_abilities/singletons/effect_executor.gd")

func _exit_tree() -> void:
	# 插件禁用时的清理
	remove_autoload_singleton("CombatSystem")
	remove_autoload_singleton("DamageCalculator")
	remove_autoload_singleton("CombatEventBus")
	remove_autoload_singleton("EffectExecutor")