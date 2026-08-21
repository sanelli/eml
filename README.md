# elm

ELM compiler and interpreter that converts mathematical expressions into ELM
expressions and executes them.

## Requirements

- [Alire](https://alire.ada.dev/) (`alr`) with a GNAT toolchain (`alr toolchain`)

On macOS, if linking fails with `library not found for -lSystem`, set
`SDKROOT` to your Command Line Tools SDK (for example
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`) before building. The
project already passes that path to the linker when the host OS is macOS.

## Build

```powershell
alr build
```

This produces:

- `bin/elm` — compiler / interpreter executable (stub CLI for now)
- `bin/elm_tests` — in-repo smoke tests

Compiler switches treat **warnings as errors** and enable full style and
runtime checks (see `alire.toml` `[build-switches]` and `.cursor/rules/elm-build.mdc`).

## Run

```powershell
alr run
# or
./bin/elm
```

## Test

```powershell
alr run -- elm_tests
# or
./bin/elm_tests
```

Happy path: build succeeds with zero warnings; `elm` exits 0; `elm_tests`
checks each stub package marker and exits 0.

Negative path (warnings-as-errors): any unused entity or other warnable
construct must fail the build under `-gnatwe`. Do not leave such code in the
tree; fix it instead.

## Layout

| Path | Role |
|------|------|
| `src/elm.ads` | Root `Elm` package |
| `src/elm-main.adb` | Main procedure (`Elm.Main` → binary `elm`) |
| `src/elm-cli.*` | CLI placeholder |
| `src/regex_automata.*` | Regex automata stub |
| `src/expr_tokenizer.*` / `src/elm_tokenizer.*` | Tokenizer stubs |
| `src/expr_parser.*` / `src/elm_parser.*` | Parser stubs |
| `src/ir_elm.*` | Shared IR ELM stub |
| `src/interpreter.*` | Interpreter stub |
| `tests/elm_tests.adb` | Smoke tests |
