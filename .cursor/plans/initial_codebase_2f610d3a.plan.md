---
name: initial codebase
overview: Create `feature/initial-codebase` from main, tighten Cursor rules (branch creation + warnings forbidden), then scaffold an Alire Ada crate with a compiling `elm` executable, strict GNAT flags, core package stubs, and an in-repo smoke test—no backends yet.
todos:
  - id: "1"
    content: Create branch `feature/initial-codebase` from `main`
    status: completed
  - id: "2"
    content: Update Cursor rules for feature-branch creation and forbidding warnings
    status: completed
  - id: "3"
    content: Initialize Alire binary crate `elm` and GPR with maximum-strictness compiler switches; expand `.gitignore`
    status: completed
  - id: "4"
    content: Add compiling stub packages for regex automata, both tokenizers, both parsers, IR ELM, interpreter, and thin CLI; wire `elm` main
    status: completed
  - id: "5"
    content: Add in-repo `elm_tests` smoke tests and prove `alr build` + tests succeed with zero warnings/errors
    status: completed
  - id: "6"
    content: Document build/run/test in `README.md`
    status: completed
isProject: false
---

# Initial ELM codebase setup

## Prerequisites confirmed

- Repo is docs/rules only; no Ada/Alire sources yet.
- Alire available (`alr` 2.1.0). Toolchain install/build will need network + cleared proxy env per [elm-shell](.cursor/rules/elm-shell.mdc).
- Branch for this work: **`feature/initial-codebase`** (from `main`). Do not implement on `main`.

## Scope (locked)

| In scope | Out of scope |
|---|---|
| Alire bin crate, GPR, `.gitignore`, minimal README build notes | LLVM / .NET / JVM backends |
| Compiling stubs for core pipeline packages | Real tokenize/parse/compile/run logic |
| Thin `elm` main (identity / exit 0) | VS Code extension, CI YAML |
| In-repo smoke tests (no third-party test crates) | Regex engine, parsers, interpreter behavior |
| Cursor rule updates: branch creation + warnings forbidden | Commits/push unless later requested |

## Layout to create

```
elm/
  alire.toml
  elm.gpr
  src/
    elm.adb                 -- main executable
    elm-cli.ads / .adb      -- CLI placeholder (no real subcommands yet)
    regex_automata.ads/.adb
    expr_tokenizer.ads/.adb
    elm_tokenizer.ads/.adb
    expr_parser.ads/.adb
    elm_parser.ads/.adb
    ir_elm.ads/.adb
    interpreter.ads/.adb
  tests/
    elm_tests.adb           -- smoke tests over stub APIs
  README.md                 -- add `alr build` / `alr run` / test how-to
  .gitignore                -- Alire/obj/bin/config artifacts
  .cursor/rules/            -- planning + warnings updates
```

Stub packages expose a minimal compile-safe API (e.g. `function Name return String`) so later chunks fill them in without reshaping the tree. No LLVM dependency.

## Compiler strictness

Configure [elm.gpr](elm.gpr) (and keep Alire from weakening it) so Ada builds use the strictest practical GNAT set, for example:

- `-gnatwa` / related all-warnings family
- `-gnatwe` (warnings as errors)
- full style checks (`-gnaty` / project-equivalent)
- runtime checks appropriate for development builds (e.g. overflow)

Any warning or style violation fails the build. Same switches apply to the test binary.

## Tests

Happy path:

- `alr build` succeeds with warnings-as-errors.
- `elm` runs and exits successfully (stub main).
- `elm_tests` calls each stub package’s marker API and exits 0.

Negative path (process-level, no feature logic yet):

- Document/assert that introducing an unused entity or other warnable construct fails the build under `-gnatwe` (one intentional check in the plan execution notes, or a short comment in the test README section—do not leave a failing file in-tree).

No AUnit/external crates (architecture: no third-party crates except future LLVM).

## Rule updates (part of this plan)

1. **[elm-planning.mdc](.cursor/rules/elm-planning.mdc)** / **[elm-process.mdc](.cursor/rules/elm-process.mdc)** — strengthen Branch: after plan approval, **create** a feature branch from `main` (name similar to the plan) once the user grants permission; do not implement on `main` unless explicitly told; do not create branches silently.
2. **New or extended rule** (prefer a short addition to [elm-architecture.mdc](.cursor/rules/elm-architecture.mdc) or a dedicated `elm-build.mdc`) — **Warnings are forbidden**: maximum warning level, warnings treated as errors, style checks on; any warning or error must be fixed before work is done; Alire/GPR must keep these switches.

## Steps / TODOs (1:1)

1. Create branch `feature/initial-codebase` from `main`.
2. Update Cursor rules for feature-branch creation and forbidding warnings.
3. Initialize Alire binary crate `elm` and GPR with maximum-strictness compiler switches; expand `.gitignore`.
4. Add compiling stub packages for regex automata, both tokenizers, both parsers, IR ELM, interpreter, and thin CLI; wire `elm` main.
5. Add in-repo `elm_tests` smoke tests and prove `alr build` + tests succeed with zero warnings/errors.
6. Document build/run/test in `README.md`.

## Success criterion

`alr build` produces an `elm` executable with no warnings and no errors under the strict switches; smoke tests pass.