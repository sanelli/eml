---
name: compile fn emit-eml
overview: Add compile-only `--function-name`/`-fn` for renaming JS `main` or clib `compute`, and `--emit-eml` for optionally exporting `eml` in the clib header. Reject these flags with unsupported `-of` values.
todos:
  - id: "1"
    content: "Emitters: function name and emit-eml"
    status: completed
  - id: "2"
    content: Wire CLI flags and diagnostics
    status: completed
  - id: "3"
    content: CLI tests, docs, samples, build
    status: completed
isProject: false
---

# Compile --function-name and --emit-eml

Stay on **`feature/compile-js`**. Do not create a new branch. Keep this plan under [`.cursor/plans/`](.cursor/plans/) (commit with the work; never delete).

## Locked product decisions

- **`--function-name` / `-fn <ident>`** — compile only; requires a value; space-separated (no `=`). Repeated flag is invalid CLI.
  - With **`-of js`**: renames the generated entry function (default **`main`**). Companion HTML calls that name: `math.format(<ident>())`.
  - With **`-of clib`**: renames the generated entry function (default **`compute`**). Header and `.c` both use the chosen name.
  - With any other compile `-of` (`beml`, `eml`, `c`, …), or on non-`compile` commands: **invalid CLI** (diagnostic + usage, exit `1`).
- **`--emit-eml`** — compile only; boolean switch (no value). Repeated is invalid CLI.
  - Meaningful only with **`-of clib`**.
  - **Present:** declare `eml` in the companion `.h`; define `eml` non-static in the `.c` (today’s behavior).
  - **Absent (default):** omit `eml` from the `.h`; define `eml` as **`static`** in the `.c` (still needed for nested calls). Entry function (`compute` or `-fn` name) remains in the header.
  - With any other `-of`, or on non-`compile`: **invalid CLI**.
- **Identifier rules** for `-fn`: non-empty; first char letter or `_`; rest letters, digits, or `_`. Otherwise invalid CLI. Do not reserve-check `main`/`eml`/`compute` beyond these shape rules.
- **Defaults when flags omitted:** JS → `main`; clib → `compute`; clib does not emit `eml` in the header.
- **`-of c` program `main` is not renamed** by `-fn` (unsupported combo → error).
- New diagnostics in the CLI 000xx range (next free after 27): e.g. repeated `-fn`, missing `-fn` value, invalid identifier, `-fn` not allowed for this `-of`/command, repeated `--emit-eml`, `--emit-eml` not allowed for this `-of`/command.

## Implementation outline

### Emitters

- [`src/js_backend.ads`](src/js_backend.ads) / [`.adb`](src/js_backend.adb): pass `Function_Name` into `Format_Js` / writers; `Format_Html (Js_File_Name, Function_Name)`.
- [`src/c_backend.ads`](src/c_backend.ads) / [`.adb`](src/c_backend.adb): pass `Function_Name` and `Emit_Eml` into `Format_C_Lib` / `Format_C_Header` / lib writers. Program path unchanged.

### CLI

- [`src/eml-cli.adb`](src/eml-cli.adb): parse `--function-name`/`-fn` and `--emit-eml` in the shared flag loop; after command/`-of` known, validate combinations for `compile`; thread values into `Write_Compile_Output` → backends.
- Update `Put_Compile_Help` / usage: document `-fn` (js/clib) and `--emit-eml` (clib).
- [`src/eml-diagnostics.ads`](src/eml-diagnostics.ads) / [`.adb`](src/eml-diagnostics.adb): new messages.

### Tests / docs / samples

- Unit tests: renamed JS function + HTML call site; clib header with/without `eml`; static vs non-static `eml` in `.c`; renamed `compute`.
- CLI tests: happy `-of js -fn run`; `-of clib -fn eval --emit-eml`; defaults; negatives (bad ident, `-fn` with `beml`, `--emit-eml` with `js`, repeated flags, `-fn` on `run`).
- Update [`.cursor/rules/eml-cli.mdc`](.cursor/rules/eml-cli.mdc) and [README.md](README.md) Compile subsection.
- `run_samples`: no need to pass new flags (defaults preserve current marker checks: `function main` / `compute` / optional `eml(` in hdr — adjust clib sample assert: default header must still have entry name `compute`, and must **not** require `eml(` in `.h` anymore).

## Steps

### 1. Emitters: function name and emit-eml

Update JS/C backends and unit tests as locked above.

### 2. Wire CLI flags and diagnostics

Parse/validate `-fn` / `--emit-eml`; update help; pass through to writers.

### 3. CLI tests, docs, samples, build

CLI cases, README/`eml-cli.mdc`, fix `run_samples` clib header assertion for default (no `eml` in `.h`), `alr build` + `./bin/eml_tests`.

## Out of scope

Renaming `-of c` `main`; renaming the `eml` operator function itself; wasm/wat.
