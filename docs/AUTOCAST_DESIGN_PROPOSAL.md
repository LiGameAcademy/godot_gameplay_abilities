# 自动施法（Autocast）设计提案

## 设计决策

### 自动施法属于哪一层？

**结论：自动施法属于业务层（AI/行为逻辑），而非插件层（技能系统核心）**

#### 理由：

1. **技能系统核心职责**：
   - ✅ 技能的定义和配置
   - ✅ 技能的施放和执行
   - ✅ 技能的效果应用
   - ❌ **不负责**：何时施放、对谁施放（这是AI/行为逻辑）

2. **自动施法的复杂性**：
   - 目标选择策略（优先治疗友军、优先攻击低血敌人等）
   - 施法条件判断（血量低于阈值、敌人进入范围等）
   - 优先级管理（多个自动施法技能的优先级）
   - 这些都属于**游戏逻辑**，而非**技能系统核心**

3. **参考《魔兽争霸3》**：
   - 自动施法由**单位AI系统**管理
   - 技能系统只提供基础配置接口
   - 实际的自动施法逻辑在AI层实现

## 设计方案

### 方案：元数据扩展（已采用）

**插件层提供元数据字典，业务层完全自主实现**

#### 1. 插件层：提供元数据字典

```gdscript
# GameplayAbility 基类
@export_group("Metadata")
## 元数据字典（供业务层扩展使用）
## 业务层可以使用此字典存储自定义数据，如：
## - 自动施法配置：metadata["supports_autocast"] = true
## - AI优先级：metadata["ai_priority"] = 5
## - 自定义标签：metadata["custom_tags"] = ["heal", "support"]
## 插件层不解析此字典，完全由业务层管理
@export var metadata: Dictionary = {}
```

**优势**：
- ✅ 插件层不维护自动施法相关方法，保持简洁
- ✅ 业务层可以自由定义元数据结构
- ✅ 完全解耦，插件层不依赖业务层逻辑

#### 2. 业务层：实现自动施法逻辑

```gdscript
# scripts/ai/autocast_manager.gd
extends Node
class_name AutocastManager

## 自动施法管理器
## 负责管理单位的自动施法逻辑

var _autocast_abilities: Dictionary[StringName, bool] = {}  # ability_id -> enabled
var _autocast_timer: Timer = null

func _ready() -> void:
	_autocast_timer = Timer.new()
	_autocast_timer.wait_time = 0.5  # 每0.5秒检查一次
	_autocast_timer.timeout.connect(_check_autocast)
	add_child(_autocast_timer)
	_autocast_timer.start()

## 启用/禁用自动施法
func set_autocast_enabled(ability_id: StringName, enabled: bool) -> void:
	_autocast_abilities[ability_id] = enabled

## 检查并执行自动施法
func _check_autocast() -> void:
	var ability_comp = get_parent().get_node_or_null("GameplayAbilityComponent")
	if not is_instance_valid(ability_comp):
		return
	
	# 遍历所有启用的自动施法技能
	for ability_id in _autocast_abilities:
		if not _autocast_abilities[ability_id]:
			continue
		
		var ability_data = ability_comp.get_ability_data(ability_id)
		if not is_instance_valid(ability_data):
			continue
		
		# 从元数据中读取自动施法配置（业务层管理）
		if not ability_data.metadata.get("supports_autocast", false):
			continue
		
		# 基础检查：冷却是否就绪、是否禁用
		if ability_data.disabled or not ability_data.is_cooldown_ready():
			continue
		
		# 业务层逻辑：选择目标
		var target = _select_autocast_target(ability_data, ability_comp)
		if not is_instance_valid(target):
			continue
		
		# 业务层逻辑：检查施法条件（如血量阈值）
		if not _check_autocast_conditions(ability_data, target):
			continue
		
		# 执行自动施法
		var context = AbilityContext.create()
		ability_comp.commit_cast(ability_id, target, context)

## 选择自动施法目标（业务层实现）
func _select_autocast_target(ability_data: GameplayAbility, ability_comp: GameplayAbilityComponent) -> Node:
	# 根据技能类型选择目标
	# 例如：治疗技能选择血量最低的友军
	# 例如：攻击技能选择最近的敌人
	# 这些逻辑完全由业务层决定
	return null

## 检查自动施法条件（业务层实现）
func _check_autocast_conditions(ability_data: GameplayAbility, target: Node) -> bool:
	# 业务层逻辑：检查施法条件
	# 例如：治疗技能只在友军血量低于50%时施放
	# 例如：攻击技能只在敌人进入射程时施放
	return true
```

## 使用示例

### 1. 在技能资源中配置元数据

```gdscript
# 在技能资源（.tres）的 Inspector 中
metadata = {
    "supports_autocast": true,
    "autocast_priority": 5,
    "autocast_conditions": {
        "target_health_threshold": 0.5,  # 目标血量低于50%时施放
        "range": 10.0  # 射程内才施放
    }
}
```

### 2. 在业务层使用

```gdscript
# prefabs/enemy.gd
extends CharacterBody3D

@onready var ability_comp = $GameplayAbilityComponent
@onready var autocast_manager = $AutocastManager

func _ready() -> void:
	# 启用治疗技能的自动施法
	autocast_manager.set_autocast_enabled(&"heal", true)
	
	# 启用攻击技能的自动施法
	autocast_manager.set_autocast_enabled(&"fireball", true)
```

### 3. UI 集成示例

```gdscript
# ui/ability_button.gd
extends Button

@export var ability_id: StringName = &""
var autocast_manager: AutocastManager = null

func _ready() -> void:
	# 获取自动施法管理器
	var owner_entity = get_tree().get_first_node_in_group("player")
	if is_instance_valid(owner_entity):
		autocast_manager = owner_entity.get_node_or_null("AutocastManager")
	
	# 连接右键点击事件（切换自动施法）
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_instance_valid(autocast_manager):
			var current_state = autocast_manager.is_autocast_enabled(ability_id)
			autocast_manager.set_autocast_enabled(ability_id, not current_state)
			_update_autocast_indicator()

func _update_autocast_indicator() -> void:
	if not is_instance_valid(autocast_manager):
		return
	
	var is_enabled = autocast_manager.is_autocast_enabled(ability_id)
	# 更新UI显示（例如：改变按钮颜色、显示图标等）
```

## 扩展点

### 1. 技能特定的自动施法逻辑

业务层可以在 `AutocastManager` 中根据技能类型实现不同的逻辑：

```gdscript
func _select_autocast_target(ability_data: GameplayAbility, ability_comp: GameplayAbilityComponent) -> Node:
	# 从元数据中读取技能类型
	var ability_type = ability_data.metadata.get("ability_type", "")
	
	match ability_type:
		"heal":
			return _select_lowest_health_ally(ability_comp)
		"attack":
			return _select_nearest_enemy(ability_comp)
		"buff":
			return _select_self_or_ally(ability_comp)
		_:
			return null
```

### 2. 通过元数据配置复杂条件

```gdscript
# 技能资源中的元数据
metadata = {
    "supports_autocast": true,
    "autocast_config": {
        "target_selection": "lowest_health_ally",
        "conditions": {
            "target_health_below": 0.5,
            "caster_mana_above": 0.3,
            "range": 15.0
        },
        "priority": 5
    }
}

# AutocastManager 中解析配置
func _check_autocast_conditions(ability_data: GameplayAbility, target: Node) -> bool:
	var config = ability_data.metadata.get("autocast_config", {})
	var conditions = config.get("conditions", {})
	
	# 检查目标血量
	if conditions.has("target_health_below"):
		var threshold = conditions["target_health_below"]
		var health_comp = GameplayAbilitySystem.get_component_by_interface(target, "HealthComponent")
		if is_instance_valid(health_comp):
			var health_ratio = health_comp.current_health / health_comp.max_health
			if health_ratio > threshold:
				return false
	
	# 检查施法者蓝量
	if conditions.has("caster_mana_above"):
		var threshold = conditions["caster_mana_above"]
		var owner = get_parent()
		var mana_comp = GameplayAbilitySystem.get_component_by_interface(owner, "ManaComponent")
		if is_instance_valid(mana_comp):
			var mana_ratio = mana_comp.current_mana / mana_comp.max_mana
			if mana_ratio < threshold:
				return false
	
	# 检查射程
	if conditions.has("range"):
		var max_range = conditions["range"]
		var owner = get_parent()
		var distance = owner.global_position.distance_to(target.global_position)
		if distance > max_range:
			return false
	
	return true
```

## 总结

### 推荐方案

1. **插件层**：提供元数据字典
   - `metadata: Dictionary` - 供业务层存储自定义数据
   - 插件层不解析元数据，完全由业务层管理

2. **业务层**：实现完整逻辑
   - `AutocastManager` 组件
   - 从 `metadata` 读取自动施法配置
   - 目标选择策略
   - 施法条件判断
   - 优先级管理
   - UI集成

### 优势

- ✅ **职责清晰**：插件层只负责技能核心，业务层负责游戏逻辑
- ✅ **易于扩展**：业务层可以根据游戏需求自由实现，不受插件层限制
- ✅ **保持插件通用性**：不绑定特定游戏逻辑，完全通用
- ✅ **符合开闭原则**：对扩展开放，对修改封闭
- ✅ **简洁设计**：不需要在插件层维护自动施法相关方法

### 与《魔兽争霸3》的对比

- **《魔兽争霸3》**：技能系统提供 `autocast` 标志，AI系统管理自动施法逻辑
- **本方案**：技能系统提供 `metadata` 字典，业务层（AI系统）完全自主管理

两者设计理念一致：**技能系统提供配置，AI系统实现逻辑**。
