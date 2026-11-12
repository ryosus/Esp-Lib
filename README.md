# esp-lib

Drawing-based ESP library for Roblox, plus a [Fluent](https://github.com/dawid-scripts/Fluent) interface that exposes every option.

Behaviour and option set are modelled on [ic3w0lf22/Unnamed-ESP](https://github.com/ic3w0lf22/Unnamed-ESP).

```
examples/           example scripts using the library directly
esp_lib.lua         the library (config table + drawing functions)
esp_gui.lua         Fluent menu for every option
tests/              headless test suites (mock Roblox + real Fluent)
```

## GUI

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/main/esp_gui.lua"))()
```

Requires an executor with `Drawing`, `loadstring` and `game:HttpGet`. Fluent and the library are downloaded automatically.

| Key | Action |
|---|---|
| `F3` | toggle the ESP on / off |
| `LeftControl` | minimise the menu |

The GUI always fetches `esp_lib.lua` from this repository. It checks `esplib.api` and refuses to run against an outdated library instead of silently ignoring options.

| Tab | Contents |
|---|---|
| ESP | master switch + key, player targets (show players / teammates, **excluded teams**, team + enemy colours, Roblox team colour), filters (visibility check, max distance, minimum health, target refresh) |
| Box | normal / corner box, padding, corner length, outline thickness, colours |
| Health | health bar (width, colours) and health text (`hp/maxhp [pct%]`, numbers or percent) |
| Text | names (size, y offset, line spacing, colour, outline) and distance |
| Tracer | origin (mouse / head / top / bottom / center / custom x·y, reset), colours, thickness |
| Skeleton | R15 + R6 bone lines, colour, thickness; **head dot** (filled, size, thickness, colour) |
| Misc | outlines switch, rainbow + speed, crosshair |
| Targets | draw any instance by name (e.g. `Battery`, `MoneyPrinter`) — box, label and distance, tracked live |
| Config | theme, acrylic, config save / load, reset settings |

## Library

```lua
-- optional: initial options, see the configuration table below
getgenv().esplib = {
    box = { type = "corner" },
    tracer = { from = "bottom" },
    team = { check = true },
}

local esplib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua"))()

esplib.add_box(character)
esplib.add_healthbar(character)
esplib.add_name(character, player.Name)
esplib.add_distance(character)
esplib.add_tracer(character)
esplib.add_skeleton(character)
esplib.add_head_dot(character)
```

Options are read every frame, so changing `esplib.<option>` at runtime takes effect immediately — that is all the GUI does.

| Function | Purpose |
|---|---|
| `add_box(instance)` | box around a `Model`, `BasePart`, `Accessory` or `Tool` |
| `add_healthbar(instance)` | health bar + optional health text |
| `add_dynamic_text(instance, key, text)` | stacked text above the box |
| `add_name(instance, name)` | `add_dynamic_text` with key `"name"` |
| `set_text(instance, key, text)` | update a dynamic text |
| `add_distance(instance)` | distance in metres under the box |
| `add_tracer(instance)` | line from the configured origin |
| `add_skeleton(instance)` | R15 and R6 bone lines |
| `add_head_dot(instance)` | dot on the head |
| `set_color(instance, color)` | per-instance accent override (also `nil` to clear) |
| `remove_esp(instance)` | remove every drawing for one instance |
| `unload()` | remove every drawing, the crosshair and the render loop |
| `reset()` | restore `esplib.defaults` |

Instances whose `Parent` becomes `nil` are pruned automatically. `getgenv().espinstances` holds the live records.

## Configuration

Every key is optional; missing keys fall back to these defaults.

| Key | Default | Notes |
|---|---|---|
| `enabled` | `true` | master switch |
| `outlines` | `true` | dark outline behind boxes, bars, tracers, crosshair and text |
| `box.enabled` | `true` | |
| `box.type` | `"normal"` | `"normal"` or `"corner"` |
| `box.padding` | `1.15` | multiplier on every projected bound corner |
| `box.corner_length` | `0.25` | fraction of the shortest side |
| `box.thickness` | `3` | outline thickness |
| `box.fill` / `box.outline` | white / black | |
| `healthbar.enabled` | `true` | |
| `healthbar.width` | `1` | bar width in pixels |
| `healthbar.fill` / `healthbar.outline` | green / black | |
| `healthbar.text.enabled` | `false` | health text under the target |
| `healthbar.text.format` | `"both"` | `"both"`, `"numbers"`, `"percent"` |
| `healthbar.text.size` / `.fill` | `13` / white | |
| `dynamic_text.enabled` | `true` | names / dynamic texts |
| `dynamic_text.size` | `13` | |
| `dynamic_text.y_offset` | `0` | pixels above the box |
| `dynamic_text.line_spacing` | `2` | gap between stacked texts |
| `dynamic_text.outline` | `true` | text outline |
| `dynamic_text.fill` | white | |
| `distance.enabled` | `true` | |
| `distance.size` / `.fill` / `.outline` | `13` / white / `true` | |
| `tracer.enabled` | `true` | |
| `tracer.from` | `"mouse"` | `"mouse"`, `"head"`, `"top"`, `"bottom"`, `"center"`, `"custom"` |
| `tracer.origin` | `Vector2.new(0, 0)` | used by `"custom"`; `(0, 0)` means the default point |
| `tracer.from_offset` | `135` | default custom origin: `(width/2, height - from_offset)` |
| `tracer.thickness` / `.outline_thickness` | `1` / `3` | |
| `tracer.fill` / `tracer.outline` | white / black | |
| `skeleton.enabled` | `true` | |
| `skeleton.color` | white | bone colour |
| `skeleton.thickness` | `2` | |
| `head_dot.enabled` | `false` | |
| `head_dot.filled` | `true` | |
| `head_dot.size` | `1` | multiplier of the projected head radius |
| `head_dot.thickness` | `1` | |
| `head_dot.fill` | white | |
| `minimum_health.enabled` | `true` | hide targets at or below `minimum_health.value` |
| `minimum_health.value` | `0` | |
| `team.check` | `false` | skip teammates entirely |
| `team.colors` | `false` | colour players by friendly / enemy / team colour |
| `team.use_team_color` | `false` | use `Player.TeamColor` instead |
| `team.friendly` / `team.enemy` | green / red | |
| `team.excluded` | `{}` | set of Team names never drawn, e.g. `{ ["Police"] = true }` |
| `filters.max_distance` | `0` | studs, `0` = unlimited |
| `filters.visibility_check` | `false` | hide on-screen details when a wall blocks the target; tracers keep pointing at it |
| `rainbow` | `false` | cycles the accent colour |
| `rainbow_speed` | `0.35` | |
| `crosshair.enabled` | `false` | |
| `crosshair.size` / `.gap` | `10` / `4` | |
| `crosshair.thickness` / `.outline_thickness` | `1` / `3` | |
| `crosshair.fill` / `.outline` | white / black | |

`esplib.defaults` is a snapshot of the table above (used by `reset()`), and `esplib.api` is the option-set version the GUI checks against (`4`).

Accent colours (`team.*`, `rainbow`) apply to the box, names, distance, tracer, skeleton and head dot. `set_color` wins over them for a single instance.

## Differences from Unnamed ESP

* One head marker: the **head dot** (the skeleton head circle was removed).
* Visibility check keeps tracers — off-screen enemies stay locatable.
* Custom ESP is generalised: track any instance by name from the Targets tab instead of per-game modules.
* Config is a single live table instead of a custom menu, so any script can drive it.

## Examples

`examples/` contains scripts using the library directly:

* `fps_esp.lua`, `skeleton_esp.lua` — player ESP
* `fnaf eternal nights animatronics esp.lua`, `fnaf eternal nights item esp.lua` — object ESP
* `flee_facility.lua` — name-based object ESP
* `defuse division with aimbot lol.lua` — ESP combined with a third-party aimbot
* `unload esp.lua` — remove every drawing

## Tests

```sh
python tests/run_tests.py
```

Needs the [Luau CLI](https://github.com/luau-lang/luau/releases) (`luau`, `luau-compile` on `PATH` or via `$LUAU` / `$LUAU_COMPILE`).

The suites run the real sources against mocked environments:

| Suite | Covers |
|---|---|
| `tests/lib_test.lua` | render loop: every drawing module, filters, team logic, tracer origins, health formats, outlines, pruning, legacy config, reload |
| `tests/gui_test.lua` | every UI control writes the right `esplib` option (mocked Fluent) |
| `tests/real_ui_test.lua` | the same wiring against the **real Fluent 1.1.0 source tree**, then asserts actual drawing state |

The Fluent sources are downloaded into `.scratch/cache` on first run; the real-Fluent suite is skipped when offline.

## Notes

* The GUI and the library are fetched separately, so right after an update GitHub's raw cache may serve the previous `esp_lib.lua` for a few minutes. If the menu reports an outdated library, re-run shortly after.
* Fluent 1.1.0 force-enables the acrylic blur (`Config.Acrylic or true`); the GUI defaults the interface setting to off, the Config tab can turn it back on.
* For educational use. Using this in a game may violate its rules — use at your own risk.
