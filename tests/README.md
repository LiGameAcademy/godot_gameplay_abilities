# Runtime regression checks

Run `python tests/run_runtime.py --godot /absolute/path/to/godot` with Godot 4.7.2 and Python 3.10+.
The runner creates a disposable host with the four GAS autoloads. It checks combo cost/cooldown construction, dictionary contexts, independent game-time waits, reparenting, forgetting and deletion through weak references.

Known baseline: Godot 4.7.2 retains the `GameplayEffect` and `GameplayFilterData` scripts at exit (three ObjectDB objects, two script resources). The same diagnostic reproduces with unmodified commit `34bc173` merely preloading `ActiveAbilityDefinition`, without creating any ability instances. The runner prints and allows only that exact resource set and count; other engine errors, script errors, extra retained resources and missing pass markers fail validation. This check does not claim that the baseline script-retention issue is fixed.
