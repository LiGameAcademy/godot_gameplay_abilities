extends Node
## Checks serialized resources that still reference the original template scripts.

@export var combo: ComboAbilityDefinition
@export var channeling: ChannelingAbilityDefinition

func _ready() -> void:
	if not _check_resources():
		push_error("Legacy ability definitions or their generated execution trees did not load")
		get_tree().quit.call_deferred(1)
		return
	print("PASS: GAS legacy ability template resources and scenes")
	get_tree().quit.call_deferred(0)

func _check_resources() -> bool:
	if combo == null or combo.ability_id != &"legacy_combo" or combo.combo_steps.size() != 1:
		return false
	var step: ActiveAbilityDefinition = combo.combo_steps[0]
	if step == null or step.ability_id != &"legacy_active" or step.execution_tree == null:
		return false
	if channeling == null or channeling.ability_id != &"legacy_channel" or channeling.max_duration != 0.75:
		return false
	var combo_cast: GameplayAbilityInstance = combo.create_instance(self)
	var channel_cast: GameplayAbilityInstance = channeling.create_instance(self)
	var combo_tree: BTInstance = combo_cast.get_bt_instance()
	var channel_tree: BTInstance = channel_cast.get_bt_instance()
	var trees_generated: bool = combo_tree != null and combo_tree.tree_root.node_id == &"combo_root_sequence" \
		and channel_tree != null and channel_tree.tree_root.node_id == &"channeling_ability_sequence"
	combo_cast.dispose()
	channel_cast.dispose()
	return trees_generated and combo.execution_tree == null and channeling.execution_tree == null
