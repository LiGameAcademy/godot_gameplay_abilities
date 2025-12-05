# 📘 效果生命周期系统 (Effect Lifecycle System)

**版本：** v2.0 (动态令牌模式)  
**设计理念：** 开闭原则 (OCP) - 效果决定自己的生命周期，技能无需关心

## 1. 核心概念

### 即时效果 vs 持续效果

- **即时效果 (Instant Effect)**：`blocks_ability_completion = false`
  - 应用后立即完成，技能不需要等待
  - 适用于：伤害、Buff施加、瞬移等
  
- **持续效果 (Duration Effect)**：`blocks_ability_completion = true`
  - 应用后需要等待完成，技能会阻塞直到效果完成
  - 适用于：冲锋、引导法术、持续位移等

### 动态令牌模式 (Dynamic Token Pattern)

**核心思想：** Effect 在运行时自己注册/注销阻塞任务，而不是通过回调参数传递。

**优势：**
- ✅ 完美支持多目标（AOE）场景
- ✅ 支持嵌套子效果
- ✅ 代码更简洁，无需复杂的回调闭包
- ✅ 更加健壮，避免计数器溢出或过早结束

## 2. 架构设计

### 2.1 GameplayEffect 基类

```gdscript
# 关键属性
@export var blocks_ability_completion: bool = false

# 关键方法
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void
func _is_asynchronous() -> bool  # 子类重写，返回 true 表示异步执行

# 基类会自动：
# 1. 查找 AbilityComponent
# 2. 如果是阻塞效果，自动调用 register_blocking_task()
# 3. 如果是同步效果，自动调用 unregister_blocking_task()
# 4. 如果是异步效果，子类需要在完成时调用 unregister_blocking_task()
```

### 2.2 效果完成流程

```
技能施放 (commit_cast)
  ↓
设置 _blocking_tasks_count = 1 (主锁)
  ↓
应用效果 (apply)
  ↓
Effect 自动注册阻塞任务 (register_blocking_task)
  ↓
如果是异步效果 → 效果执行中（Tween/Timer/其他异步逻辑）
  ↓
效果完成 → Effect 调用 unregister_blocking_task
  ↓
移除主锁 (unregister_blocking_task)
  ↓
当 _blocking_tasks_count <= 0 → 技能解锁
```

## 3. 使用示例

### 3.1 即时效果示例（伤害）

```gdscript
# ge_apply_damage.gd
extends GameplayEffect
class_name GE_ApplyDamage

func _init() -> void:
    blocks_ability_completion = false  # 不阻塞

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    # 立即造成伤害
    var damage = context.get("damage", 100.0)
    # ... 伤害逻辑 ...
    # 不需要手动注销，基类会自动处理（因为 blocks_ability_completion = false）
```

### 3.2 持续效果示例（冲锋）

```gdscript
# ge_physics_motion.gd
extends GameplayEffect
class_name GE_PhysicsMotion

var _active_instances: Dictionary = {}  # 存储实例信息

func _init() -> void:
    blocks_ability_completion = true  # 阻塞技能完成

func _is_asynchronous() -> bool:
    return true  # 异步执行

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    var body = target as CharacterBody3D
    if not body:
        # 目标无效，需要手动注销（基类已注册）
        var ability_comp = _find_ability_component(instigator)
        if is_instance_valid(ability_comp):
            var ability_id = ability_comp.get_current_casting_ability_id()
            if not ability_id.is_empty():
                ability_comp.unregister_blocking_task(ability_id)
        return
    
    # 获取 AbilityComponent 和技能ID
    var ability_comp = _find_ability_component(instigator)
    var ability_id: StringName = &""
    if is_instance_valid(ability_comp):
        ability_id = ability_comp.get_current_casting_ability_id()
    
    # 启动 Tween
    var tween = body.create_tween()
    tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    # ... 物理移动逻辑 ...
    
    # 存储实例信息
    var instance_id = str(body.get_rid())
    _active_instances[instance_id] = {
        "ability_comp": ability_comp,
        "ability_id": ability_id
    }
    
    # Tween 完成时注销阻塞任务
    tween.finished.connect(func():
        if _active_instances.has(instance_id):
            var instance = _active_instances[instance_id]
            var comp = instance.get("ability_comp") as GameplayAbilityComponent
            var id = instance.get("ability_id") as StringName
            if is_instance_valid(comp) and not id.is_empty():
                comp.unregister_blocking_task(id)
            _active_instances.erase(instance_id)
    )
```

## 4. 技能配置

### 4.1 创建冲锋技能

```gdscript
# dash.tres (资源配置)
[resource]
script = ExtResource("active_ability")
ability_id = &"dash"
ability_name = "冲锋"
targeting_type = 0  # SELF_ONLY
effects = Array[ExtResource("effect")]([SubResource("ge_physics_motion")])

# ge_physics_motion 子资源
[sub_resource type="Resource" id="ge_physics_motion"]
script = ExtResource("ge_physics_motion")
blocks_ability_completion = true
distance = 5.0
duration = 0.2
direction_type = 1  # MOUSE
```

### 4.2 混合效果示例

一个技能可以同时有即时效果和持续效果：

```gdscript
# 技能：冲锋斩
# - 即时效果：立即造成伤害
# - 持续效果：冲锋位移

effects = [
    GE_ApplyDamage,      # blocks_ability_completion = false
    GE_PhysicsMotion    # blocks_ability_completion = true
]

# 执行流程：
# 1. 伤害立即生效
# 2. 开始冲锋
# 3. 技能等待冲锋完成
# 4. 技能解锁
```

## 5. 取消技能

```gdscript
# 在 GameplayAbilityComponent 中
ability_component.cancel_ability("dash")

# 这会：
# 1. 调用所有效果的 remove() 方法
# 2. 停止 Tween/Timer
# 3. Effect 的 remove() 方法会调用 unregister_blocking_task()
# 4. 重置技能状态
```

## 6. 优势总结

1. **开闭原则**：新增效果类型无需修改 Ability 代码
2. **多态设计**：技能层面统一处理，效果自己决定生命周期
3. **灵活组合**：一个技能可以混合即时和持续效果
4. **可扩展性**：未来添加"蓄力"、"引导"等效果，只需设置 `blocks_ability_completion = true`
5. **完美支持多目标**：AOE 技能击中多个敌人时，每个效果实例独立注册/注销
6. **支持嵌套子效果**：子效果也会自动注册/注销，互不干扰
7. **代码更简洁**：无需复杂的回调闭包，Effect 自己管理生命周期

## 7. 注意事项

1. **注销安全**：确保在效果完成或取消时都调用 `unregister_blocking_task()`，避免技能永久卡死
2. **多目标支持**：动态令牌模式完美支持多目标，每个效果实例独立注册/注销
3. **错误处理**：如果目标无效，阻塞效果应该立即调用 `unregister_blocking_task()`，避免技能永久卡死
4. **主锁机制**：`_blocking_tasks_count` 初始为 1（主锁），确保即使没有 Effect 也能正常结束技能

