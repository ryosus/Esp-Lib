"""Builds headless Luau harnesses and runs the behavioral test suites.

The suites execute the real esp_lib.lua / esp_gui.lua sources against a mocked
Roblox environment (Drawing, instances, services, Fluent).

Requires the Luau CLI: https://github.com/luau-lang/luau/releases
Resolution order: $LUAU, .scratch/tools/, PATH.

Usage: python tests/run_tests.py
"""

import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
CACHE = ROOT / ".scratch" / "cache"
FLUENT_TAG = "1.1.0"
FLUENT_FILES_URL = "https://api.github.com/repos/dawid-scripts/Fluent/git/trees/{tag}?recursive=1"
FLUENT_RAW_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/{tag}/{path}"
ADDONS = {
    "save_manager.lua": "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua",
    "interface_manager.lua": "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua",
}


def find_tool(name: str) -> str:
    override = os.environ.get(name.upper())
    if override:
        return override

    local = ROOT / ".scratch" / "tools" / f"{name}.exe"
    if local.exists():
        return str(local)

    found = shutil.which(name)
    if found:
        return found

    print(f"{name} not found. Install the Luau CLI or set ${name.upper()}.")
    sys.exit(1)


LUAU = find_tool("luau")
LUAU_COMPILE = find_tool("luau-compile")


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_return(text: str, marker: str) -> str:
    assert marker in text, f"missing marker {marker!r}"
    return text.replace(marker, "")


def embed(name: str, source: str) -> str:
    assert "]===]" not in source, f"{name} contains the lua long-string terminator"
    return f"{name} = [===[\n{source}\n]===]\n"


def syntax_check(*files: pathlib.Path) -> None:
    for path in files:
        result = subprocess.run(
            [str(LUAU_COMPILE), str(path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            print(f"syntax error in {path.name}:\n{result.stdout}{result.stderr}")
            sys.exit(1)
        print(f"syntax ok: {path.name}")


def build_library_harness() -> pathlib.Path:
    mock = strip_return(read(TESTS / "mock.lua"), "\nreturn MOCK\n")
    lib = read(ROOT / "esp_lib.lua")
    test = read(TESTS / "lib_test.lua")

    harness = (
        mock
        + "\n"
        + embed("LIB_SOURCE", lib)
        + "ESP = assert(loadstring(LIB_SOURCE))()\n\n"
        + test
    )
    path = TESTS / "_lib_run.lua"
    path.write_text(harness, encoding="utf-8")
    return path


def build_gui_harness() -> pathlib.Path:
    mock = strip_return(read(TESTS / "mock.lua"), "\nreturn MOCK\n")
    test = read(TESTS / "gui_test.lua")

    harness = (
        mock
        + "\n"
        + embed("LIB_SOURCE", read(ROOT / "esp_lib.lua"))
        + embed("FLUENT_SOURCE", read(TESTS / "mock_fluent.lua"))
        + embed("SAVE_SOURCE", read(TESTS / "mock_save_manager.lua"))
        + embed("IFACE_SOURCE", read(TESTS / "mock_interface_manager.lua"))
        + embed("GUI_SOURCE", read(ROOT / "esp_gui.lua"))
        + """
MOCK.http_get = function(url)
    if url:find("SaveManager", 1, true) then
        return SAVE_SOURCE
    elseif url:find("InterfaceManager", 1, true) then
        return IFACE_SOURCE
    elseif url:find("esp_lib", 1, true) then
        return LIB_SOURCE
    elseif url:find("Fluent", 1, true) then
        return FLUENT_SOURCE
    end
    error("gui requested an unknown url: " .. tostring(url))
end
"""
        + test
    )
    path = TESTS / "_gui_run.lua"
    path.write_text(harness, encoding="utf-8")
    return path


def download(url: str, target: pathlib.Path) -> None:
    if target.exists():
        return
    import urllib.request

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(urllib.request.urlopen(url, timeout=30).read())


def fetch_fluent_sources():
    """Real Fluent sources the ui is built against, or None when offline."""
    try:
        import json
        import urllib.request

        tree_file = CACHE / f"fluent-{FLUENT_TAG}" / "tree.json"
        if not tree_file.exists():
            download(FLUENT_FILES_URL.format(tag=FLUENT_TAG), tree_file)
        tree = json.loads(tree_file.read_text(encoding="utf-8"))
        paths = [
            entry["path"]
            for entry in tree["tree"]
            if entry["path"].startswith("src/") and entry["path"].endswith(".lua")
        ]

        files = {}
        for path in paths:
            target = CACHE / f"fluent-{FLUENT_TAG}" / path
            download(FLUENT_RAW_URL.format(tag=FLUENT_TAG, path=path), target)
            key = path[len("src/"):-len(".lua")]
            files[key] = target.read_text(encoding="utf-8")

        addons = {}
        for name, url in ADDONS.items():
            target = CACHE / name
            download(url, target)
            addons[name] = target.read_text(encoding="utf-8")

        return files, addons
    except Exception as error:  # offline / rate limited
        print(f"skipping real-fluent suite: {error}")
        return None


def build_real_harness(sources) -> pathlib.Path:
    files, addons = sources
    runtime = strip_return(read(TESTS / "fluent_runtime.lua"), "\nreturn RUNTIME\n")
    loader = strip_return(read(TESTS / "fluent_loader.lua"), "\nreturn FLUENT_LIBRARY\n")

    table = ["FLUENT_FILES = {}"]
    for key in sorted(files):
        source = files[key]
        assert "]===]" not in source, key
        table.append(f'FLUENT_FILES["{key}"] = [===[\n{source}\n]===]\n')
    table.append("FLUENT_FOLDERS = {}")

    # Fluent 1.1.0 force-enables acrylic and its blur needs a depth-of-field
    # pipeline; the ui wiring under test is unaffected, so it is stubbed.
    table.append(
        'FLUENT_FILES["Acrylic/init"] = [===[\n'
        "local Acrylic = {}\n"
        "function Acrylic.init()\n"
        "    function Acrylic.Enable() end\n"
        "    function Acrylic.Disable() end\n"
        "end\n"
        "function Acrylic.Enable() end\n"
        "function Acrylic.Disable() end\n"
        "function Acrylic.CreateAcrylic() return Instance.new('Model') end\n"
        "function Acrylic.AcrylicPaint()\n"
        "    local frame = Instance.new('Frame')\n"
        "    local background = Instance.new('Frame')\n"
        "    background.Name = 'Background'\n"
        "    background.BackgroundTransparency = 0\n"
        "    background.Parent = frame\n"
        "    return { Frame = frame, Background = background, Model = Instance.new('Model'),\n"
        "        AddParent = function() end, Cleanup = function() end }\n"
        "end\n"
        "return Acrylic\n]===]\n"
    )

    harness = (
        runtime
        + "\n"
        + "\n".join(table)
        + "\n"
        + loader
        + "\n"
        + embed("LIB_SOURCE", read(ROOT / "esp_lib.lua"))
        + embed("GUI_SOURCE", read(ROOT / "esp_gui.lua"))
        + embed("SAVE_SOURCE", addons["save_manager.lua"])
        + embed("IFACE_SOURCE", addons["interface_manager.lua"])
        + read(TESTS / "real_ui_test.lua")
    )
    path = TESTS / "_real_run.lua"
    path.write_text(harness, encoding="utf-8")
    return path


def run(path: pathlib.Path) -> int:
    print(f"\n=== {path.name} ===")
    result = subprocess.run(
        [str(LUAU), str(path)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(result.stdout, end="")
    if result.stderr.strip():
        print(result.stderr, end="")
    return result.returncode


def main() -> int:
    syntax_check(ROOT / "esp_lib.lua", ROOT / "esp_gui.lua")

    exit_code = 0
    for path in (build_library_harness(), build_gui_harness()):
        exit_code |= run(path)

    sources = fetch_fluent_sources()
    if sources is not None:
        exit_code |= run(build_real_harness(sources))

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
