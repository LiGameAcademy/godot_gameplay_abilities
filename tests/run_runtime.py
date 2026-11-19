"""Run dependency contracts in a disposable Godot host (no ARPG required)."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="gas-contract-") as directory:
        host = Path(directory)
        shutil.copytree(source, host / "addons/godot_gameplay_abilities",
                        ignore=shutil.ignore_patterns(".git", ".godot", "__pycache__"))
        config = 'config_version=5\n[application]\nconfig/name="GAS contracts"\n[autoload]\n'
        for name, script in [("GameplayAbilitySystem", "gameplay_ability_system"),
                             ("AbilityEventBus", "ability_event_bus"),
                             ("TagManager", "gameplay_tag_manager"),
                             ("GameplayCueManager", "gameplay_cue_manager")]:
            config += f'{name}="*res://addons/godot_gameplay_abilities/scripts/singletons/{script}.gd"\n'
        config += '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        (host / "project.godot").write_text(config, encoding="utf-8")
        test_root = "res://addons/godot_gameplay_abilities/tests"
        commands = [
            (["--verbose", "--editor", "--import"], None),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/runtime_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS combo"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/channeling_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS channeling tree and missing-tree guard"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/vital_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS Vital lifecycle, payment and attributed damage"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/healing_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS actual healing events and reentrant recovery"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/attribute_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS attribute sources, snapshots and definitions"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/composite_effect_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS typed composite effect resources and independent defaults"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/attribute_dependencies_test.tscn", "--quit-after", "1800"],
             "PASS: GAS settled attribute snapshots and cycle diagnostics"),
        ]
        for command, expected_marker in commands:
            result = subprocess.run([args.godot, "--headless", "--path", str(host), *command],
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
            output = result.stdout + result.stderr
            diagnostics = ("ERROR:", "Parse Error", "ObjectDB instances leaked at exit",
                           "ObjectDB instances were leaked at exit", "Resource still in use:",
                           "Leaked instance:")
            if (result.returncode or any(diagnostic in output for diagnostic in diagnostics)
                    or (expected_marker and expected_marker not in output)):
                print(output)
                print(f"FAILED: {command} (Godot exit code {result.returncode})")
                raise SystemExit(1)
            if expected_marker:
                print(expected_marker)


if __name__ == "__main__":
    main()
