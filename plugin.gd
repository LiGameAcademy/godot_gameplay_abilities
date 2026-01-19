@tool
extends EditorPlugin

func _enter_tree() -> void:
	# 插件启用时的初始化
	add_autoload_singleton("GameplayAbilitySystem", "scripts/singletons/gameplay_ability_system.gd")
	add_autoload_singleton("GameplayCueManager", "scripts/singletons/gameplay_cue_manager.gd")
	add_autoload_singleton("AbilityEventBus", "scripts/singletons/ability_event_bus.gd")
	add_autoload_singleton("TagManager", "scripts/singletons/gameplay_tag_manager.gd")

func _exit_tree() -> void:
	# 插件禁用时的清理
	remove_autoload_singleton("GameplayAbilitySystem")
	remove_autoload_singleton("GameplayCueManager")
	remove_autoload_singleton("AbilityEventBus")
	remove_autoload_singleton("TagManager")
