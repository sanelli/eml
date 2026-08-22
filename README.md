# eml

EML compiler and interpreter that converts mathematical expressions into EML
expressions and executes them.

## Requirements

- [Alire](https://alire.ada.dev/) (`alr`) with a GNAT toolchain (`alr toolchain`)
- PowerShell (`pwsh`) for the pre-build git-commit embed script

On macOS, if linking fails with `library not found for -lSystem`, set
`SDKROOT` to your Command Line Tools SDK (for example
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`) before building. The
project already passes that path to the linker when the host OS is macOS.

## Build

```powershell
alr build
```

This produces:

- `bin/eml` — compiler / interpreter executable
- `bin/eml_tests` — in-repo tests

Compiler switches treat **warnings as errors** and enable full style and
runtime checks (see `alire.toml` `[build-switches]` and `.cursor/rules/eml-build.mdc`).

## Run

```powershell
alr run
# or
./bin/eml --no-logo preproc -i path/to/file.teml
./bin/eml --no-logo tokenize -i path/to/file.teml
./bin/eml --no-logo parse -i path/to/file.teml
./bin/eml --no-logo compile -i path/to/file.teml
```

### Preproc

Substitute `$VARNAME` placeholders before tokenization:

```powershell
./bin/eml preproc -i filename.teml
./bin/eml preproc -i filename.teml -o other.teml
./bin/eml preproc -i f.teml -v '$X=1+2'
./bin/eml --no-logo preproc -i f.teml -v '$X=1' -w none
```

- `-i` / `--input` — required `.teml` file
- `-o` / `--output` — optional `.teml` output; stdout if omitted
- `-v` / `--var $NAME=EXPR` — bind a variable (repeatable; quote in PowerShell)
- `-w` / `--warn` — `default` (default), `none`, or `error` for unused `--var`
- `--no-logo` / `--no-color` — same as other commands

Unbound `$VARNAME` in the file is an error (all occurrences reported). Exit `0`
on success, `1` on failure.

### Tokenize

```powershell
./bin/eml tokenize -i filename.teml
./bin/eml tokenize -i filename.teml -o other.tokens
./bin/eml tokenize -i f.teml -v '$X=1' -w none
./bin/eml --no-logo tokenize -i filename.teml -o other.tokens
```

- `-i` / `--input` — required `.teml` file
- `-o` / `--output` — optional `.tokens` file; omit to write tokens to stdout
- `-v` / `--var` — preprocessor bindings (repeatable)
- `-w` / `--warn` — unused `--var` warning mode
- `--no-logo` — suppress the stdout banner (use for pure dumps / pipes)
- `--no-color` — plain stderr diagnostics (no ANSI color)

The preprocessor runs first. Token dumps use original source line/column and
mark substituted spans with `-- $NAME begin` / `-- $NAME end` comment lines.

Invalid tokens are reported on stderr; scanning continues and valid tokens are
still emitted. Exit status is `0` on success and `1` on CLI, I/O, preprocess,
or lex errors.

### Parse

```powershell
./bin/eml parse -i filename.teml
./bin/eml parse -i filename.teml -o other.syntaxtree
./bin/eml parse -i filename.teml -of md -o other.md
./bin/eml parse -i f.teml -v '$X=1' -w none
./bin/eml --no-logo parse -i filename.teml
```

- `-i` / `--input` — required `.teml` file
- `-o` / `--output` — optional dump file; omit to write to stdout
- `-of` / `--output-format` — `mermaid` (default), `md`, `dot`, or `svg`
- `-v` / `--var` — preprocessor bindings (repeatable)
- `-w` / `--warn` — unused `--var` warning mode
- Output extension must match the format (`.syntaxtree`, `.md`, `.dot`, `.svg`)

The preprocessor runs first, then tokenize and parse. Lex or parse errors are
reported on stderr with original line/column; substituted text adds
`(from $NAME)` when applicable. No tree is written on failure. Exit status is
`0` on success and `1` on CLI, I/O, preprocess, lex, or parse errors.

### Compile

Lower a `.teml` file to stack-machine IR (`.beml` binary by default, or textual `.eml`):

```powershell
./bin/eml compile -i filename.teml
./bin/eml compile -i filename.teml -o other.beml
./bin/eml compile -i filename.teml -o other.eml -f eml
./bin/eml compile -i f.teml -v '$X=1' -w none -o out.beml
./bin/eml --no-logo compile -i f.teml -f eml
```

- `-i` / `--input` — required `.teml` file
- `-o` / `--output` — optional; extension must match format (`.beml` default, `.eml` with `-f eml`); stdout if omitted
- `-f` / `--format` — `beml` (default) or `eml`
- `-v` / `--var` — preprocessor bindings (repeatable)
- `-w` / `--warn` — unused `--var` warning mode
- `--no-logo` — required when piping binary `.beml` to stdout

The preprocessor runs first, then tokenize, parse, and IR lowering. Exit status is
`0` on success and `1` on CLI, I/O, preprocess, lex, or parse errors.

## EML file formats

### Textual `.eml` (`--format eml`)

Human-readable stack-machine IR.

- **Header** (whole-line comments): `Source`, `Compiler`, `Version`, `Date` (`YYYY-MM-DD HH:MM:SS UTC`)
- **Instructions:** `ONE` (no comment) and `EML` with optional trailing `--` comments naming the rewrite
- **Stack semantics:** `ONE` pushes `1`; `EML` pops `Y` then `X` and pushes `eml(X, Y) = exp(X) - ln(Y)`

Example for source constant `e`:

```
-- Source: e.teml
-- Compiler: eml
-- Version: 0.1.0-dev
-- Date: 2026-08-22 09:00:00 UTC
ONE
ONE
EML  -- e
```

### Binary `.beml` (`--format beml`, default)

Compact packed-bit encoding of the same instruction stream (no comments, no source path).

**Endianness: big-endian** (network byte order) for the 2-byte UTC year and the 4-byte instruction count.

Byte layout, in order:

1. Magic: 4 bytes ASCII `BEML`
2. Format version: 1 byte (`1`)
3. UTC year: 2 bytes, unsigned 16-bit **big-endian**
4. UTC month, day, hour, minute, second: 1 byte each
5. Instruction count: 4 bytes, unsigned 32-bit **big-endian** (number of `ONE`/`EML` ops)
6. Code: packed bits — `1` = `ONE`, `0` = `EML`; MSB-first in each byte; unused bits in the last byte padded with `0`; count is authoritative

Example: `ONE`, `ONE`, `EML` → count `3`, one code byte `11000000` (binary).

## Samples

`.teml` examples live under [`samples/`](samples/), including precedence stress
cases (`16_`–`25_`) and parameterized expressions using `$VARNAME`. Run them with:

```powershell
./scripts/run_samples.ps1
./scripts/run_samples.ps1 -Operations preproc
./scripts/run_samples.ps1 -Operations tokenize
./scripts/run_samples.ps1 -Operations tokenize,parse
./scripts/run_samples.ps1 -Operations tokenize,parse,compile
./scripts/run_samples.ps1 --operations preproc tokenize parse compile
```

`-Operations` / `--operations` selects which front-end steps to run (`preproc`,
`tokenize`, `parse`, `compile`). Pass a comma-separated list or multiple values after
`--operations`. If omitted, **all** operations are run.

The script passes dummy `--var` bindings for sample variable names and
`--warn none`. Outputs go to `.results/<operation>/` (gitignored). For `parse`,
each sample is emitted in all four formats. For `compile`, each sample writes
default `.beml` and `-f eml` `.eml`. Exit `1` if any sample fails.

## Test

```powershell
alr run -- eml_tests
# or
./bin/eml_tests
```

Coverage includes regex automata, preprocessor, `.teml` tokenization, expression
parsing (precedence and errors), tree emitters, IR lowering, and `eml preproc` / `eml tokenize`
/ `eml parse` / `eml compile` CLI happy/negative paths.

## Layout

| Path | Role |
|------|------|
| `src/eml.ads` | Root `Eml` package |
| `src/eml-main.adb` | Main procedure (`Eml.Main` → binary `eml`) |
| `src/eml-cli.*` | CLI (`preproc`, `tokenize`, `parse`, `compile`, banner, flags) |
| `src/eml-info.*` | Program name / author / version / commit |
| `src/regex_automata.*` | In-repo regex → NFA library |
| `src/expr_preprocessor.*` | `.teml` `$VARNAME` substitution |
| `src/expr_tokenizer.*` | `.teml` tokenizer |
| `src/expr_parser.*` | `.teml` parser and tree emitters |
| `src/expr_lower.*` | `.teml` AST → IR EML lowering |
| `src/eml_tokenizer.*` | `.eml` tokenizer stub |
| `src/eml_parser.*` | `.eml` parser stub |
| `src/ir_eml.*` | Shared IR EML tree and `.eml`/`.beml` encoders |
| `src/interpreter.*` | Interpreter stub |
| `tests/` | Regex, preprocessor, tokenizer, parser, and CLI tests |
| `scripts/embed_git_commit.ps1` | Pre-build short-hash embed |
| `scripts/run_samples.ps1` | Batch preproc / tokenize / parse / compile samples |
