extends GameplayAbilityFeature
class_name CostFeature

## 消耗特性
## 管理技能的资源消耗
## 
## 使用方式：
## ```gdscript
## var ability = GameplayAbility.new()
## var cost_feature = CostFeature.new()
## cost_feature.costs = [VitalCost.new()]
## ability.features.append(cost_feature)
## ```

@export_group("Cost Settings")
## 技能消耗器数组（支持多种消耗类型）
@export var costs: Array[AbilityCostBase] = []

func _init() -> void:
	super("CostFeature")

func can_activate(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 如果 context 跳过消耗，直接返回 true
	if context.get("skip_cost", false):
		return true
	
	# 检查是否可以支付所有消耗
	var ability_comp = context.get("ability_comp")
	var instigator = context.get("instigator")
	
	if not is_instance_valid(ability_comp):
		push_error("CostFeature: Cannot get ability_comp for ability %s" % ability_instance.get_definition().ability_id)
		return false
	if not is_instance_valid(instigator):
		push_error("CostFeature: Cannot get instigator for ability %s" % ability_instance.get_definition().ability_id)
		return false
	
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(ability_comp, instigator):
			return false
	
	return true

func try_pay(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 如果 context 跳过消耗，直接返回 true
	if context.get("skip_cost", false):
		return true
	
	# 检查并支付所有消耗
	var ability_comp = context.get("ability_comp")
	var instigator = context.get("instigator")
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("CostFeature: Cannot get ability_comp or instigator for ability %s" % ability_instance.get_definition().ability_id)
		return false
	
	# 遍历所有消耗器，检查并消耗资源
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		
		# 检查是否可以支付
		if not cost.can_pay(ability_comp, instigator):
			push_warning("CostFeature: Cannot pay cost for ability %s: %s" % [ability_instance.get_definition().ability_id, cost.get_cost_description()])
			return false
		
		# 尝试支付消耗
		if not cost.try_pay(ability_comp, instigator):
			push_warning("CostFeature: Failed to pay cost for ability %s: %s" % [ability_instance.get_definition().ability_id, cost.get_cost_description()])
			return false
	
	return true

func get_description() -> String:
	if costs.is_empty():
		return "无消耗"
	
	var cost_descriptions: Array[String] = []
	for cost in costs:
		if is_instance_valid(cost):
			cost_descriptions.append(cost.get_cost_description())
	
	return "消耗: %s" % ", ".join(cost_descriptions)
