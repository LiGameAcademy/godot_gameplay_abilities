extends Node

## 战斗事件总线（单例）
## 提供全局事件通讯机制，实现组件间的解耦

# 伤害相关事件
signal damage_dealt(instigator: Node, target: Node, damage_info: DamageInfo, final_damage: float)
signal damage_received(target: Node, damage_info: DamageInfo)
signal entity_died(entity: Node, instigator: Node)

# 治疗相关事件
signal healing_applied(target: Node, amount: float)
signal health_restored(entity: Node)

# 属性相关事件
signal attribute_changed(entity: Node, attribute_id: StringName, new_value: float)

# 技能相关事件
signal ability_activated(entity: Node, ability_id: StringName)
signal ability_failed(entity: Node, ability_id: StringName, reason: String)
signal ability_learned(entity: Node, ability_id: StringName)
signal ability_forgotten(entity: Node, ability_id: StringName)
signal ability_cooldown_ready(entity: Node, ability_id: StringName)

# 状态相关事件
signal status_applied(entity: Node, status_id: StringName)
signal status_removed(entity: Node, status_id: StringName)

## 发送伤害事件
func emit_damage_dealt(instigator: Node, target: Node, damage_info: DamageInfo, final_damage: float) -> void:
	damage_dealt.emit(instigator, target, damage_info, final_damage)

## 发送实体死亡事件
func emit_entity_died(entity: Node, instigator: Node) -> void:
	entity_died.emit(entity, instigator)

## 发送治疗事件
func emit_healing_applied(target: Node, amount: float) -> void:
	healing_applied.emit(target, amount)

## 发送属性变化事件
func emit_attribute_changed(entity: Node, attribute_id: StringName, new_value: float) -> void:
	attribute_changed.emit(entity, attribute_id, new_value)

## 发送技能激活事件
func emit_ability_activated(entity: Node, ability_id: StringName) -> void:
	ability_activated.emit(entity, ability_id)

## 发送技能失败事件
func emit_ability_failed(entity: Node, ability_id: StringName, reason: String) -> void:
	ability_failed.emit(entity, ability_id, reason)

## 发送技能学习事件
func emit_ability_learned(entity: Node, ability_id: StringName) -> void:
	ability_learned.emit(entity, ability_id)

## 发送技能遗忘事件
func emit_ability_forgotten(entity: Node, ability_id: StringName) -> void:
	ability_forgotten.emit(entity, ability_id)

## 发送技能冷却就绪事件
func emit_ability_cooldown_ready(entity: Node, ability_id: StringName) -> void:
	ability_cooldown_ready.emit(entity, ability_id)

## 发送状态应用事件
func emit_status_applied(entity: Node, status_id: StringName) -> void:
	status_applied.emit(entity, status_id)

## 发送状态移除事件
func emit_status_removed(entity: Node, status_id: StringName) -> void:
	status_removed.emit(entity, status_id)

