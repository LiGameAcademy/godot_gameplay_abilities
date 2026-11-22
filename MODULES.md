# Attribute、Vital、Status 和 Ability 的按需安装

可以把所选模块复制到宿主的 `addons/godot_gameplay_abilities`。从正式插件的独立检出运行命令，使用 Python 3.10+。宿主目录须已有 `project.godot`。

| 安装选项 | 提供的能力 | 宿主需配置 |
| --- | --- | --- |
| `attribute` | 属性定义、属性集、成长曲线、修饰器和 `GameplayAttributeComponent` | 无 Autoload |
| `vital` | Attribute 的全部能力，加上 `GameplayVitalAttributeComponent`、生命、法力、扣费和基础伤害入口 | 无必需 Autoload |
| `status` | 状态施加、叠层、到期、周期和事件特性，以及 Effect、标签、过滤器和 Cue 的共享基础 | 基础状态无需 Autoload，事件、标签和 Cue 可由宿主显式提供 |
| `status-attribute` | Status、Attribute 及内置 `GE_AttributeModifier` | 基础限时加成无需 Autoload |
| `status-vital` | Status + Attribute、Vital 及内置 `GE_ApplyDamage` 和通用伤害策略 | 无必需 Autoload，可显式配置战斗总线和标签服务 |
| `ability` | 技能学习、激活、完成、冷却特性及运行自定义行为树所需的基础类型 | 无必需 Autoload，宿主提供执行树 |

## 只用 Attribute

```sh
python tools/install_modules.py attribute --project "/path/to/my-godot-project"
```

打开宿主项目，在角色下面添加 `GameplayAttributeComponent`。创建 `GameplayAttribute` 并填写属性 ID，例如 `power`，再通过 `GameplayAttributeSet.attributes` 配置它的基础值。初始化时把属性集交给 `component.initialize()`，业务侧使用 `get_value()`、`set_base_value()` 或修饰器接口。可运行回归中的属性从 `10 → 13 → 10`，分别对应初始化、添加及移除修饰器。 [最小属性脚本](tests/module_profiles/attribute_only.gd)

## 在同一工程加上 Vital

从同一份插件版本再次运行安装工具。

```sh
python tools/install_modules.py vital --project "/path/to/my-godot-project"
```

角色改用 `GameplayVitalAttributeComponent`，初始化时传入已有的属性集及 Vital 定义。以法力为例，属性集定义 `max_mana`，再让 `GameplayVital.max_value_attribute` 指向它。技能以外的费用可通过 `try_spend()` 结算。角色生命使用 `HealthVital`，伤害从 `apply_damage()` 进入。两参数调用会在宿主已注册 `AbilityEventBus` 时广播全局伤害事件，零 Autoload 的项目仍可监听生命和伤害的本地信号。 [最小 Vital 脚本](tests/module_profiles/vital_only.gd)

## 单独安装 Status 或加到已有的 Vital

```sh
python tools/install_modules.py status --project "/path/to/my-godot-project"
```

这条命令也可用于已有 Attribute 或 Vital 的工程。文件相同的共享依赖会直接复用。可以直接使用基础状态和组件信号。

给角色添加 `GameplayStatusComponent`，创建 `GameplayStatusData` 并配置状态 ID、持续时间、叠层上限和策略，然后调用 `apply_status()`。可以通过 `has_status()` 查询，也可以订阅 `status_applied` 和 `status_removed`。周期特性可以使用宿主自定义的 `GameplayEffect`，表现可以使用自定义的 `GameplayCueBase`。内置限时属性增益由下节的组合安装提供。 [最小状态脚本](tests/module_profiles/status_only.gd)

### 按战斗场景接入服务

战斗场景可以创建自己的总线，并把它传给所属角色的 Status 组件。以下代码放在战斗根节点的初始化逻辑中，在应用任何状态前执行。示例中的 `status_component` 是已取得的角色组件引用。多个角色可以使用同一个服务对象，另一场战斗可以创建自己的服务对象。

```gdscript
var services: GameplayServices = GameplayServices.new()
services.events = GameplayServices.EventBus.new()
add_child(services.events)
status_component.configure_services(services)
```

需要标签或 Cue 时，可在同一个服务对象上分别设置 `tags` 和 `cues`，对应节点由宿主添加到场景树。期间保持服务对象的引用配置稳定。状态存续时 `configure_services()` 会拒绝替换，避免将标签和持续 Cue 留在旧服务上。

完整插件中，未显式配置的 Status 会使用现有的同名 Autoload。显式配置后只使用该服务对象里的实例，留空可以省略对应服务。有标签条件的基础效果需要标签服务才能验证条件。技能生命周期事件仍沿用完整插件的既有总线。

## 用内置效果做限时属性增益

```sh
python tools/install_modules.py status-attribute --project "/path/to/my-godot-project"
```

角色同时提供属性组件和状态组件。给 `GameplayStatusData.apply_effects` 加一个 `GE_AttributeModifier`，将效果的 `attribute_component_name` 设为 `GameplayAttributeComponent`，再填入修饰器。使用 Vital 宿主时可沿用已指向 `GameplayVitalAttributeComponent` 的配置。状态到期会根据本次状态实例的来源清理修饰器，同一效果资源可以由多个状态分别使用。

示例资源给 `power` 增加 `3`，持续 `0.5` 秒。回归用两种状态共享这份效果，一个先到期，另一个保持两层。属性依次经过 `10 → 13 → 16 → 19 → 16 → 10`。宿主可以按节点名或已有的组件接口提供属性组件。 [限时属性增益资源](tests/module_profiles/timed_attribute_bonus.tres) · [组合回归](tests/module_profiles/status_attribute.gd)

## 用内置伤害做周期状态

```sh
python tools/install_modules.py status-vital --project "/path/to/my-godot-project"
```

让目标提供 `GameplayVitalAttributeComponent` 和 `HealthVital`。给状态添加 `FeaturePeriodicEffects`，配置周期与一个 `GE_ApplyDamage`，用 `fixed_base_damage` 配置固定基础伤害。保留效果的默认免疫规则时，在本场战斗的 `GameplayServices.tags` 中注册 `state.invulnerable`。通过同一服务对象传入战斗自己的事件总线，`damage_received` 和 `damage_applied` 就会送到该总线。状态仍走统一伤害流程，致死归属可通过 Vital 组件的 `health_depleted` 读取。宿主直接调用生命组件时，也可以用 `apply_damage_with_events()` 指定总线。 [周期伤害回归](tests/module_profiles/status_vital.gd)

## 用 Ability 执行自定义技能

```sh
python tools/install_modules.py ability --project "/path/to/my-godot-project"
```

给角色添加 `GameplayAbilityComponent`，然后创建 `GameplayAbilityDefinition`，配置技能 ID、`execution_tree` 和 `CooldownFeature`，再调用 `learn_ability()`。执行树可以直接用宿主实现的 `BTAction`。在动作的提交点调用 `CooldownFeature.start_cooldown()`，随后返回 `Status.SUCCESS`。界面可以监听组件的 `ability_activated` 和 `ability_completed` 信号。

`try_activate_ability()` 返回 `true` 表示接受施放。执行树随后由组件驱动，冷却从树调用 `start_cooldown()` 时开始；冷却期间两种激活检查均返回 `false`。共享一份技能定义的角色各自记录冷却。这个组合包含基础行为树、Effect、Cue、标签和技能修饰器类型。需要内置的主动、连击、引导和扣费模板时，使用完整插件。 [可运行示例](tests/module_profiles/ability_only.gd)

安装工具保留已有的相同文件，发现同路径内容有差异会在复制前提示。宿主的 `project.godot` 和 Autoload 配置由你管理。已有完整插件的项目，继续使用 README 中的完整安装方式。

### 阅读内置行为树模板

主动、连击和引导的行为树实现在 [`examples/ability_templates`](examples/ability_templates/)。使用完整插件时，仍可用 `ActiveAbilityDefinition`、`ComboAbilityDefinition` 和 `ChannelingAbilityDefinition` 创建资源。原来的脚本路径、UID、类名和导出字段继续由资源入口提供，已有 `.tres` 和 `.tscn` 可以直接加载。

## 把完整安装迁移到按需安装

先在宿主的独立副本中迁移，并使用原安装对应的插件版本运行安装工具。如果当前版本没有安装工具，先在副本中升级完整插件并验证。检查项目脚本、场景和资源使用的组件、效果、技能模板及 Autoload，根据这些依赖选择安装选项。仍使用内置主动、连击或引导模板的项目需要完整插件。

下面以仅使用限时属性加成的宿主为例。

1. 关闭 Godot。把完整的 `addons/godot_gameplay_abilities` 目录及 `.godot` 导入缓存移到项目副本外，以便回退和验证全量导入。
2. 在副本中移除完整插件对应的编辑器启用项和宿主已不需要的 GAS Autoload。保留其他插件和 Autoload 设置。
3. 从插件检出运行 `python tools/install_modules.py status-attribute --project "/path/to/project-copy"`。安装器会拒绝覆盖仍存在的完整插件。
4. 用 Godot 重新导入项目副本，打开原场景，验证状态叠层、到期和修饰器清理。回归用例在两种安装中运行同一份场景、脚本和 `.tres`，并核对文件内容。

## 验证安装边界

从正式插件的独立检出执行下面的命令。在 Windows 上可指定 Godot 的控制台版。

```sh
python tests/run_module_profiles.py --godot "/path/to/godot"
```

运行器建立七份零 Autoload 临时工程。属性、生命和状态宿主省略 Ability 和行为树。Ability 宿主省略 Attribute、Vital、Status 和内置技能模板，验证激活、完成、冷却拒绝、冷却缩减和两名角色的冷却隔离。

迁移用例另外构建一个完整安装的宿主，在切换为 `status-attribute` 后重新导入相同资源并检查结果。
