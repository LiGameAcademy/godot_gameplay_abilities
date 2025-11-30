# 事件系统设计文档

## 目录

- [概述](#概述)
- [系统架构](#系统架构)
- [优势分析](#优势分析)
- [缺点分析](#缺点分析)
- [缺点规避方案](#缺点规避方案)
- [最佳实践](#最佳实践)
- [插件与外部通信](#插件与外部通信)
- [扩展指南](#扩展指南)

## 概述

Godot Gameplay Abilities Plugin 的事件系统采用**统一事件总线 + 多态事件类 + 工厂模式**的设计，实现了高内聚、低耦合的事件驱动架构。系统支持两种事件触发方式，既保证了类型安全，又保持了向后兼容性。

## 系统架构

### 核心组件

```
CombatEventBus (单例)
├── event_factory: CombatEventFactory (实例)
├── game_event_occurred (统一事件信号)
└── 细粒度事件信号 (向后兼容)
    ├── damage_dealt
    ├── damage_received
    ├── entity_died
    └── ...

CombatEvent (抽象基类)
├── event_type: StringName
├── context: Variant (CombatEventContext | Dictionary)
└── emit_gameplay_signal() (抽象方法)

CombatEventFactory (实例类)
├── _event_class_map: Dictionary[StringName, Callable]
└── create_event() (工厂方法)
```

### 事件流程

```
触发事件
    ↓
方式1: 直接传入事件实例 (推荐)
    ↓
CombatEventBus.trigger_game_event(event)
    ↓
发出统一事件信号 game_event_occurred
    ↓
触发细粒度信号 (通过多态调用)
    ↓
外部系统监听并处理

方式2: 传入类型+字典 (向后兼容)
    ↓
CombatEventBus.trigger_game_event(event_type, context)
    ↓
通过工厂创建事件实例
    ↓
后续流程同方式1
```

## 优势分析

### 1. **符合开闭原则（OCP）**

**优势：**
- 添加新事件类型只需创建新的事件类并注册，无需修改核心代码
- 使用多态替代 `match` 语句，避免了违反开闭原则的问题

**示例：**
```gdscript
# 添加新事件类型只需：
# 1. 创建新事件类
extends CombatEvent
class_name MyCustomEvent

func _init(p_context: Dictionary) -> void:
    super(&"my_custom_event", p_context)

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
    event_bus.my_custom_signal.emit(context["data"])

# 2. 在工厂中注册
CombatEventBus.event_factory.register_event(&"my_custom_event", _create_my_custom_event)

# 3. 无需修改 CombatEventBus.trigger_game_event() 方法！
```

### 2. **类型安全**

**优势：**
- 支持强类型上下文（`CombatEventContext` 子类）
- 编译时类型检查，避免字典键错误
- IDE 自动补全支持

**示例：**
```gdscript
# 强类型上下文
var ctx = DamageReceivedContext.new(source, target, damage_info)
var event = DamageReceivedEvent.new(ctx)
# ctx.source, ctx.target, ctx.damage_info 都有类型提示
```

### 3. **灵活的事件触发方式**

**优势：**
- 方式1：直接传入事件实例（类型安全，推荐）
- 方式2：传入类型+字典（向后兼容，简单快速）
- 两种方式可以混合使用

### 4. **统一的事件接口**

**优势：**
- 所有事件通过 `game_event_occurred` 统一信号触发
- 状态系统可以配置监听多个事件类型
- 便于实现事件日志、调试、分析等功能

### 5. **工厂模式的优势**

**优势：**
- 工厂作为单例成员变量，生命周期清晰
- 支持动态注册新事件类型
- 未注册的事件类型自动使用 `GenericEvent`

### 6. **向后兼容**

**优势：**
- 保留细粒度事件信号，现有代码无需修改
- 支持字典上下文，逐步迁移到强类型上下文

## 缺点分析

### 1. **性能开销**

**缺点：**
- 事件对象创建开销（方式1需要创建上下文和事件对象）
- 字典转换开销（强类型上下文需要转换为字典）
- 双重信号发射（统一信号 + 细粒度信号）

**影响：**
- 高频事件（如每帧触发的事件）可能产生性能问题
- 大量事件对象可能增加GC压力

### 2. **类型推断问题**

**缺点：**
- GDScript 静态分析器无法正确识别多态调用
- 需要使用 `call()` 方法动态调用，失去类型检查

**影响：**
- IDE 无法提供完整的代码提示
- 运行时错误可能延迟发现

### 3. **事件对象生命周期**

**缺点：**
- 事件对象在触发后可能被立即释放
- 如果监听器异步处理事件，可能访问已释放的对象

**影响：**
- 需要确保事件上下文数据的有效性
- 异步处理需要复制数据

### 4. **字典上下文的类型不安全**

**缺点：**
- 方式2使用字典，缺少类型检查
- 字典键错误只能在运行时发现

**影响：**
- 容易出现拼写错误
- 缺少IDE支持

### 5. **事件工厂的注册复杂度**

**缺点：**
- 添加新事件类型需要在工厂中注册
- 如果忘记注册，会使用 `GenericEvent`，可能丢失功能

**影响：**
- 需要维护注册列表
- 可能遗漏注册导致功能异常

## 缺点规避方案

### 1. **性能优化**

#### 方案A：对象池模式
```gdscript
# 为高频事件使用对象池
class_name EventPool
var _damage_received_pool: Array[DamageReceivedEvent] = []

func get_damage_received_event(context: DamageReceivedContext) -> DamageReceivedEvent:
    if _damage_received_pool.is_empty():
        return DamageReceivedEvent.new(context)
    var event = _damage_received_pool.pop_back()
    event.context = context  # 重置上下文
    return event

func return_event(event: DamageReceivedEvent) -> void:
    event.context = null  # 清理引用
    _damage_received_pool.append(event)
```

#### 方案B：延迟创建
```gdscript
# 只在需要细粒度信号时才创建事件对象
func trigger_game_event(event_type: StringName, context: Dictionary) -> void:
    game_event_occurred.emit(event_type, context)
    
    # 只在有监听器时才创建事件对象
    if has_signal_listeners(event_type):
        var event = event_factory.create_event(event_type, context)
        event.emit_gameplay_signal(self)
```

#### 方案C：批量事件处理
```gdscript
# 对于高频事件，使用批量处理
var _pending_events: Array[CombatEvent] = []

func trigger_game_event_batch(events: Array[CombatEvent]) -> void:
    _pending_events.append_array(events)
    if _pending_events.size() >= BATCH_SIZE:
        _process_event_batch()

func _process_event_batch() -> void:
    for event in _pending_events:
        game_event_occurred.emit(event.event_type, event.get_context())
        event.emit_gameplay_signal(self)
    _pending_events.clear()
```

### 2. **类型安全增强**

#### 方案A：使用类型注解
```gdscript
# 在事件类中添加类型注解
extends CombatEvent
class_name DamageReceivedEvent

var typed_context: DamageReceivedContext:
    get:
        return context as DamageReceivedContext

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
    if typed_context:
        event_bus.damage_received.emit(
            typed_context.target,
            typed_context.damage_info
        )
```

#### 方案B：编译时检查
```gdscript
# 使用 @export 和类型检查
@export var required_context_keys: Array[String] = ["target", "damage_info"]

func _init(p_context: Dictionary) -> void:
    super(&"damage_received", p_context)
    _validate_context()

func _validate_context() -> void:
    for key in required_context_keys:
        assert(context.has(key), "Missing required context key: " + key)
```

### 3. **事件生命周期管理**

#### 方案A：数据复制
```gdscript
# 在事件上下文中提供数据复制方法
extends CombatEventContext
class_name DamageReceivedContext

func duplicate_data() -> Dictionary:
    return {
        "source": source,
        "target": target,
        "damage_info": damage_info.duplicate() if damage_info.has_method("duplicate") else damage_info
    }
```

#### 方案B：引用计数
```gdscript
# 使用 RefCounted 确保事件对象在需要时保持存活
extends RefCounted
class_name CombatEvent
# 自动管理生命周期
```

### 4. **字典上下文类型安全**

#### 方案A：强制使用强类型上下文
```gdscript
# 在文档和示例中推荐使用强类型上下文
# 逐步废弃字典方式（保留向后兼容）

## @deprecated 使用 DamageReceivedEvent.new(DamageReceivedContext.new(...)) 替代
func trigger_game_event(event_type: StringName, context: Dictionary) -> void:
    push_warning("Dictionary context is deprecated. Use typed context instead.")
    # ... 实现
```

#### 方案B：字典验证
```gdscript
# 在工厂中验证字典结构
func create_event(event_type: StringName, context: Dictionary) -> CombatEvent:
    _validate_context_structure(event_type, context)
    # ... 创建事件
```

### 5. **工厂注册简化**

#### 方案A：自动注册
```gdscript
# 使用反射自动注册事件类型
func _initialize_event_map() -> void:
    var event_classes = [
        DamageReceivedEvent,
        DamageDealtEvent,
        # ...
    ]
    for event_class in event_classes:
        var instance = event_class.new({})
        var event_type = instance.get_event_type()
        _register_event(event_type, _create_event_by_class.bind(event_class))
```

#### 方案B：注册验证
```gdscript
# 在运行时验证所有事件类型都已注册
func _ready() -> void:
    event_factory = CombatEventFactory.new()
    _validate_event_registrations()

func _validate_event_registrations() -> void:
    var required_events = [
        &"damage_received",
        &"damage_dealt",
        # ...
    ]
    for event_type in required_events:
        assert(event_factory._event_class_map.has(event_type), 
               "Event type not registered: " + event_type)
```

## 最佳实践

### 1. **事件触发方式选择**

#### ✅ 推荐：使用强类型上下文（方式1）
```gdscript
# 类型安全，IDE支持好
var ctx = DamageReceivedContext.new(source, target, damage_info)
var event = DamageReceivedEvent.new(ctx)
CombatEventBus.trigger_game_event(event)
```

#### ⚠️ 向后兼容：使用字典（方式2）
```gdscript
# 简单快速，但缺少类型检查
CombatEventBus.trigger_game_event(&"damage_received", {
    "source": source,
    "target": target,
    "damage_info": damage_info
})
```

### 2. **事件监听方式选择**

#### ✅ 推荐：监听统一事件信号
```gdscript
# 可以监听多个事件类型
CombatEventBus.game_event_occurred.connect(_on_game_event)

func _on_game_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"damage_received":
            _handle_damage_received(context)
        &"ability_activated":
            _handle_ability_activated(context)
```

#### ⚠️ 向后兼容：监听细粒度信号
```gdscript
# 类型明确，但需要多个连接
CombatEventBus.damage_received.connect(_on_damage_received)
CombatEventBus.ability_activated.connect(_on_ability_activated)
```

### 3. **状态系统事件监听**

```gdscript
# 在 GameplayStatusData 中配置
@export var trigger_on_events: Array[StringName] = [
    &"damage_received",
    &"turn_start"
]

# 状态会自动监听这些事件
```

### 4. **事件上下文设计**

#### ✅ 推荐：使用强类型上下文
```gdscript
extends CombatEventContext
class_name DamageReceivedContext

var source: Node
var target: Node
var damage_info: DamageInfo

func _init(p_source: Node, p_target: Node, p_damage_info: DamageInfo) -> void:
    source = p_source
    target = p_target
    damage_info = p_damage_info

func get_event_type() -> StringName:
    return &"damage_received"

func to_dict() -> Dictionary:
    return {
        "source": source,
        "target": target,
        "damage_info": damage_info
    }
```

### 5. **错误处理**

```gdscript
func trigger_game_event(event_or_type: Variant, context: Variant = {}) -> void:
    var event: CombatEvent = null
    
    if event_or_type is CombatEvent:
        event = event_or_type
    else:
        var event_type = event_or_type as StringName
        if not event_factory._event_class_map.has(event_type):
            push_warning("Unknown event type: " + event_type + ". Using GenericEvent.")
        event = event_factory.create_event(event_type, context)
    
    # 验证事件有效性
    if not event:
        push_error("Failed to create event")
        return
    
    # 触发事件
    game_event_occurred.emit(event.event_type, event.get_context())
    if event.has_method("emit_gameplay_signal"):
        event.call("emit_gameplay_signal", self)
```

### 6. **性能考虑**

```gdscript
# 对于高频事件，考虑批量处理
var _damage_events: Array[DamageReceivedEvent] = []

func _process(_delta: float) -> void:
    # 批量处理伤害事件
    if _damage_events.size() > 0:
        _process_damage_events_batch()
        _damage_events.clear()

func queue_damage_event(event: DamageReceivedEvent) -> void:
    _damage_events.append(event)
```

## 插件与外部通信

### 1. **插件发射事件给外部系统**

插件通过 `CombatEventBus` 发射事件，外部系统可以监听这些事件。

#### 方式A：监听统一事件信号（推荐）

```gdscript
# 外部系统代码
extends Node

func _ready() -> void:
    # 监听统一事件信号
    CombatEventBus.game_event_occurred.connect(_on_combat_event)

func _on_combat_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"damage_received":
            var target = context.get("target")
            var damage_info = context.get("damage_info")
            # 处理伤害事件（例如：更新UI、播放音效等）
            _update_damage_ui(target, damage_info)
        
        &"entity_died":
            var entity = context.get("entity")
            var instigator = context.get("instigator")
            # 处理死亡事件（例如：显示死亡动画、掉落物品等）
            _handle_entity_death(entity, instigator)
        
        &"ability_activated":
            var entity = context.get("entity")
            var ability_id = context.get("ability_id")
            # 处理技能激活（例如：播放技能特效、音效等）
            _play_ability_effects(entity, ability_id)
```

#### 方式B：监听细粒度事件信号

```gdscript
# 外部系统代码
extends Node

func _ready() -> void:
    # 监听细粒度信号
    CombatEventBus.damage_received.connect(_on_damage_received)
    CombatEventBus.entity_died.connect(_on_entity_died)
    CombatEventBus.ability_activated.connect(_on_ability_activated)

func _on_damage_received(target: Node, damage_info: DamageInfo) -> void:
    # 处理伤害事件
    _update_damage_ui(target, damage_info)

func _on_entity_died(entity: Node, instigator: Node) -> void:
    # 处理死亡事件
    _handle_entity_death(entity, instigator)

func _on_ability_activated(entity: Node, ability_id: StringName) -> void:
    # 处理技能激活
    _play_ability_effects(entity, ability_id)
```

### 2. **插件订阅外部事件**

插件可以订阅外部系统的事件，实现双向通信。

#### 方式A：通过外部事件总线（已实现）

插件已提供外部事件订阅功能，可以直接使用：

```gdscript
# 外部系统：游戏管理器
extends Node
class_name GameManager

signal player_level_up(new_level: int)
signal quest_completed(quest_id: StringName)

func _ready() -> void:
    # 设置外部事件总线
    CombatEventBus.set_external_event_bus(self)
    
    # 插件订阅外部事件
    CombatEventBus.subscribe_to_external_event(
        &"player_level_up",
        _on_external_player_level_up
    )
    
    CombatEventBus.subscribe_to_external_event(
        &"quest_completed",
        _on_external_quest_completed
    )

# 触发外部事件
func level_up_player() -> void:
    var new_level = player_level + 1
    player_level_up.emit(new_level)  # 插件会自动接收

# 插件处理外部事件：玩家升级
func _on_external_player_level_up(new_level: int) -> void:
    # 将外部事件转换为插件内部事件
    CombatEventBus.trigger_game_event(&"player_level_up", {
        "new_level": new_level
    })
    
    # 或者直接触发插件内部逻辑
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var health_comp = CombatSystem.get_component_by_interface(player, "HealthComponent")
        var mana_comp = CombatSystem.get_component_by_interface(player, "ManaComponent")
        if health_comp:
            health_comp.set_current_value(health_comp.max_value)
        if mana_comp:
            mana_comp.set_current_value(mana_comp.max_value)

# 插件处理外部事件：任务完成
func _on_external_quest_completed(quest_id: StringName) -> void:
    # 将外部事件转换为插件内部事件
    CombatEventBus.trigger_game_event(&"quest_completed", {
        "quest_id": quest_id
    })
```

#### 方式B：通过接口注入

```gdscript
# 定义外部事件接口
class_name ExternalEventSubscriber
extends RefCounted

## 订阅外部事件
func subscribe_to_external_events(event_bus: Node) -> void:
    if event_bus.has_signal("custom_event"):
        event_bus.custom_event.connect(_on_custom_event)

func _on_custom_event(data: Dictionary) -> void:
    # 处理外部事件
    pass

# 在 CombatEventBus 中使用
var external_subscriber: ExternalEventSubscriber

func set_external_event_bus(event_bus: Node) -> void:
    external_subscriber = ExternalEventSubscriber.new()
    external_subscriber.subscribe_to_external_events(event_bus)
```

### 3. **双向通信示例**

```gdscript
# 外部系统：游戏管理器
extends Node
class_name GameManager

func _ready() -> void:
    # 订阅插件事件
    CombatEventBus.game_event_occurred.connect(_on_combat_event)
    
    # 让插件订阅外部事件
    CombatEventBus.set_external_event_bus(self)

# 插件事件处理
func _on_combat_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"entity_died":
            var entity = context.get("entity")
            if entity.is_in_group("player"):
                # 玩家死亡，触发游戏结束
                game_over.emit()
        
        &"ability_activated":
            var entity = context.get("entity")
            var ability_id = context.get("ability_id")
            # 记录技能使用统计
            _record_ability_usage(entity, ability_id)

# 外部事件：游戏开始
signal game_started
signal game_over

func start_game() -> void:
    game_started.emit()

# 插件会监听 game_started 事件，并触发相应的战斗系统初始化
```

### 4. **事件桥接模式**

对于复杂的外部系统集成，可以使用事件桥接器：

```gdscript
# 事件桥接器
extends Node
class_name CombatEventBridge

## 将插件事件转换为外部系统事件
func _on_plugin_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"damage_received":
            # 转换为外部系统的事件格式
            ExternalSystem.emit_signal("combat_damage", {
                "target_id": context.get("target").get_instance_id(),
                "damage": context.get("damage_info").base_damage
            })
        
        &"entity_died":
            ExternalSystem.emit_signal("entity_death", {
                "entity_id": context.get("entity").get_instance_id()
            })

## 将外部系统事件转换为插件事件
func _on_external_event(event_name: String, data: Dictionary) -> void:
    match event_name:
        "player_healed":
            # 转换为插件事件
            CombatEventBus.trigger_game_event(&"healing_applied", {
                "target": data.get("player"),
                "amount": data.get("amount")
            })

func _ready() -> void:
    # 双向桥接
    CombatEventBus.game_event_occurred.connect(_on_plugin_event)
    ExternalSystem.custom_event.connect(_on_external_event)
```

### 5. **事件命名空间**

为了避免事件名称冲突，建议使用命名空间：

```gdscript
# 插件事件使用 "combat:" 前缀
CombatEventBus.trigger_game_event(&"combat:damage_received", context)

# 外部系统事件使用 "game:" 前缀
GameEventBus.trigger_event(&"game:player_level_up", data)

# 在桥接器中处理命名空间
func _on_plugin_event(event_type: StringName, context: Dictionary) -> void:
    if event_type.begins_with("combat:"):
        var external_event = event_type.replace("combat:", "game:")
        ExternalSystem.trigger_event(external_event, context)
```

## 扩展指南

### 添加新事件类型

1. **创建事件上下文类**（推荐）
```gdscript
extends CombatEventContext
class_name MyCustomContext

var custom_data: String

func _init(p_custom_data: String) -> void:
    custom_data = p_custom_data

func get_event_type() -> StringName:
    return &"my_custom_event"

func to_dict() -> Dictionary:
    return {"custom_data": custom_data}
```

2. **创建事件类**
```gdscript
extends CombatEvent
class_name MyCustomEvent

func _init(p_context: MyCustomContext) -> void:
    super(p_context.get_event_type(), p_context)

static func from_dict(context: Dictionary) -> MyCustomEvent:
    return MyCustomEvent.new(MyCustomContext.new(context.get("custom_data", "")))

func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
    var ctx = get_context()
    if validate_context(["custom_data"]):
        # 如果有对应的细粒度信号
        # event_bus.my_custom_signal.emit(ctx["custom_data"])
        pass
```

3. **在工厂中注册**
```gdscript
# 在 CombatEventFactory._initialize_event_map() 中添加
_register_event(&"my_custom_event", _create_my_custom_event)

# 添加创建函数
func _create_my_custom_event(context: Dictionary) -> CombatEvent:
    return MyCustomEvent.from_dict(context)
```

4. **添加细粒度信号**（可选）
```gdscript
# 在 CombatEventBus 中添加
signal my_custom_event(data: String)

# 在事件类中触发
func emit_gameplay_signal(event_bus: CombatEventBus) -> void:
    var ctx = get_context()
    event_bus.my_custom_event.emit(ctx["custom_data"])
```

## 总结

### 核心优势
- ✅ 符合开闭原则，易于扩展
- ✅ 类型安全（使用强类型上下文）
- ✅ 统一的事件接口
- ✅ 向后兼容

### 主要缺点及规避
- ⚠️ 性能开销 → 使用对象池、批量处理
- ⚠️ 类型推断问题 → 使用类型注解、编译时检查
- ⚠️ 事件生命周期 → 使用 RefCounted、数据复制
- ⚠️ 字典类型不安全 → 推荐使用强类型上下文
- ⚠️ 工厂注册复杂度 → 自动注册、注册验证

### 最佳实践
1. **优先使用强类型上下文**（方式1）
2. **监听统一事件信号**进行多事件处理
3. **使用事件桥接器**实现插件与外部系统的双向通信
4. **使用命名空间**避免事件名称冲突
5. **考虑性能优化**（对象池、批量处理）用于高频事件

### 外部通信
- **插件 → 外部**：通过 `CombatEventBus.game_event_occurred` 信号
- **外部 → 插件**：通过事件桥接器或接口注入
- **双向通信**：使用事件桥接模式

通过遵循这些最佳实践，可以构建一个健壮、可扩展、高性能的事件驱动系统。

