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

## Input formats

| Format | Extension | Role |
|--------|-----------|------|
| `mxeml` | `.mxeml` | Math expression language (operators, functions, `eml(x, y)`) |
| `teml` | `.teml` | Nested tree text: `1` and `eml(S, S)` only |
| `eml` | `.eml` | Textual stack IR (`ONE` / `EML`) |
| `beml` | `.beml` | Binary packed-bit stack IR |

`--input` / `-i` is optional (stdin when omitted). If `-i` is omitted,
`--input-format` / `-if` is required. When both are present, `-if` overrides
the file extension.

Diagnostics print as `[ID] line:column description` (five-digit IDs).

## Pipelines

```mermaid
flowchart TD
  mxeml[mxeml] --> preproc
  teml[teml] --> preproc
  preproc --> preprocOut["preproc: expanded .mxeml / .teml"]
  preproc --> tokenize
  eml[eml] --> tokenize
  tokenize --> tokensOut["tokenize: .tokens"]
  tokenize --> parse
  beml[beml] --> bemlRead[Beml_Reader]
  bemlRead --> parse
  parse --> parseMx["parse mxeml: AST dump"]
  parse --> parseIr["parse teml/eml/beml: IR tree dump"]
  parse --> lowerOrIR[Expr_Lower or IR tree]
  lowerOrIR --> irNode[IR_Eml.Node]
  irNode --> writeEml["compile -of eml"]
  writeEml --> emlFile[.eml]
  irNode --> flatten[IR_Eml.Flatten]
  flatten --> writeBeml["compile -of beml"]
  writeBeml --> bemlFile[.beml]
  irNode --> writeJs["compile -of js"]
  writeJs --> jsFile[.js]
  jsFile --> htmlFile[".html companion when -o"]
  irNode --> writeC["compile -of c"]
  writeC --> cMain[".c with main"]
  irNode --> writeClib["compile -of clib"]
  writeClib --> cLib[".c eml+compute"]
  cLib --> cHdr[".h companion when -o"]
  flatten --> stack[Complex stack]
  stack --> stdout["eml run: stdout compact Complex"]
```

`preproc`, `tokenize`, and `parse` stop at their dump (expanded text, tokens,
or tree). `compile` and `run` continue from `IR_Eml.Node`; `run` Flattens to
opcodes and evaluates on a complex stack (no output file). `-of js` walks the
IR tree into nested `eml(...)` calls (no Flatten) and, with `-o`, writes a
companion `.html` that loads math.js and the generated script. `-of c` emits a
standalone C program (`<complex.h>`, `long double complex`); `-of clib` emits
a library `.c` and, with `-o`, a companion `.h` (`eml` + `compute`).

## Run

```powershell
alr run
# or
./bin/eml --no-logo preproc -i path/to/file.mxeml
./bin/eml --no-logo tokenize -i path/to/file.mxeml
./bin/eml --no-logo parse -i path/to/file.mxeml
./bin/eml --no-logo compile -i path/to/file.mxeml
./bin/eml --no-logo compile -if mxeml -of eml   # stdin math → textual .eml
./bin/eml --no-logo run -i path/to/file.mxeml
```

### Preproc

Substitute `$VARNAME` placeholders (`.mxeml` and `.teml` only):

```powershell
./bin/eml preproc -i filename.mxeml
./bin/eml preproc -i filename.mxeml -o other.mxeml
./bin/eml preproc -i f.mxeml -v '$X=1+2'
./bin/eml --no-logo preproc -i f.mxeml -v '$X=1' -w none
```

- `-i` / `--input` — optional; extension `.mxeml` or `.teml` (or `-if`)
- `-o` / `--output` — optional; extension must match input format
- `-of` / `--output-format` — `mxeml` or `teml` (default = input format)
- `-v` / `--var $NAME=EXPR` — bind a variable (repeatable)
- `-w` / `--warn` — `default`, `none`, or `error` for unused `--var`

### Tokenize

```powershell
./bin/eml tokenize -i filename.mxeml
./bin/eml tokenize -i filename.mxeml -o other.tokens
./bin/eml tokenize -i f.eml
./bin/eml --no-logo tokenize -i filename.mxeml -o other.tokens
```

Accepts `mxeml`, `teml`, and `eml` (not `beml`). `-of tokens` is the only
output format (default).

### Parse

```powershell
./bin/eml parse -i filename.mxeml
./bin/eml parse -i filename.mxeml -o other.syntaxtree
./bin/eml parse -i filename.mxeml -of md -o other.md
./bin/eml parse -i tree.teml
./bin/eml parse -i stack.eml -of svg -o t.svg
```

Accepts all four input formats. `-of` / `--output-format`: `mermaid` (default),
`md`, `dot`, or `svg`. Output extension must match.

### Compile

Lower to stack-machine IR (`.beml` binary by default, or textual `.eml`), emit
browser JavaScript (`.js`), or emit C (`.c` / library `.c`+`.h`):

```powershell
./bin/eml compile -i filename.mxeml
./bin/eml compile -i filename.mxeml -o other.beml
./bin/eml compile -i filename.mxeml -o other.eml -of eml
./bin/eml compile -i f.teml -of beml
./bin/eml compile -i stack.eml -of beml
./bin/eml --no-logo compile -i f.mxeml -of eml
./bin/eml compile -i f.mxeml -of js -o out.js
./bin/eml compile -i f.mxeml -of c -o out.c
./bin/eml compile -i f.mxeml -of clib -o out.c
```

- `-of` / `--output-format` — `beml` (default), `eml`, `js`, `c`, or `clib`
  (replaces old `-f` / `--format`)
- Same-format compile is an error (`eml`→`eml`, `beml`→`beml`)
- `--format` / `-f` is rejected; use `-of`
- `-of js` writes a classic browser script that defines `eml(x, y)` with
  [math.js](https://mathjs.org/) (`math.exp` / `math.log`) and a `main()` that
  returns nested `eml(...)` calls matching the IR tree. When `-o out.js` is
  set, a companion `out.html` is written beside it (loads the pinned math.js
  CDN bundle and `out.js`, then shows `math.format(main())`). Without `-o`,
  only the JavaScript goes to stdout.
- `-of c` writes a standalone C program using `<complex.h>` and
  `long double complex` (`cexpl` / `clogl`), with `main` printing the result.
- `-of clib` writes a C library `.c` defining `eml` and `compute`. When `-o`
  is set, also writes a companion `.h` with those declarations. Without `-o`,
  only the `.c` goes to stdout.
- **Future (not implemented yet):** compile targets **`wasm`** and **`wat`**
  (textual WebAssembly).

### Run

Evaluate IR EML and print one compact complex value on stdout. No `-o` / `-of`.

```powershell
./bin/eml run -i filename.mxeml
./bin/eml run -i f.teml -v '$X=1'
./bin/eml --no-logo run -if eml < prog.eml
./bin/eml run -i f.beml
```

- Accepts all four input formats
- `--var` / `-v` on **mxeml / teml** only (preprocessor paste). On `.eml` /
  `.beml`, every `--var` is unused (same warn/error as compile)
- `$NAME:VALUE` runtime bindings are not implemented yet
- `--output` / `-o` and `--output-format` / `-of` are invalid CLI

## EML file formats

### Textual `.eml` (`--output-format eml`)

Human-readable stack-machine IR.

- **Header** (whole-line comments): `Source`, `Compiler`, `Version`, `Date` (`YYYY-MM-DD HH:MM:SS UTC`)
- **Instructions:** `ONE` (no comment) and `EML` with optional trailing `--` comments naming the rewrite
- **Stack semantics:** `ONE` pushes `1`; `EML` pops `Y` then `X` and pushes `eml(X, Y) = exp(X) - ln(Y)`

Example for source constant `e`:

```
-- Source: e.mxeml
-- Compiler: eml
-- Version: 0.1.0-dev
-- Date: 2026-08-22 09:00:00 UTC
ONE
ONE
EML  -- e
```

### Nested `.teml`

Paper tree grammar only:

```
1
eml(1, 1)
eml(eml(1, 1), 1)
```

### Binary `.beml` (`--output-format beml`, default)

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

`.mxeml` examples live under [`samples/`](samples/), including precedence stress
cases (`16_`–`25_`) and parameterized expressions using `$VARNAME`. Nested
`.teml` samples (`t01_`…) cover the tree-text format. `run_samples.ps1`
exercises every input format each command supports: `.teml` samples for
preproc/tokenize/parse/compile/run, and stack `.eml` / `.beml` derived by compiling
non-taylor samples into `.results/_chain/` then piping into tokenize/parse/compile/run.

```powershell
./scripts/run_samples.ps1
./scripts/run_samples.ps1 -Operations preproc
./scripts/run_samples.ps1 -Operations tokenize
./scripts/run_samples.ps1 -Operations tokenize,parse
./scripts/run_samples.ps1 -Operations tokenize,parse,compile,run
./scripts/run_samples.ps1 --operations preproc tokenize parse compile run
```

`-Operations` / `--operations` selects which front-end steps to run (`preproc`,
`tokenize`, `parse`, `compile`, `run`). Pass a comma-separated list or multiple values after
`--operations`. If omitted, **all** operations are run.

The script passes dummy `--var` bindings for sample variable names and
`--warn none`. Outputs go to `.results/<operation>/` (gitignored) except `run`,
which captures stdout into a variable (not printed) and checks
`|actual - expected| < 0.01`. Taylor `.mxeml` samples are skipped for `run`
(and for IR chaining). For `parse`, each sample is emitted in all four formats.
For `compile`, each sample writes default `.beml`, `-of eml` `.eml`, and (for
non-taylor sources) `-of js` `.js` plus companion `.html`, plus `-of c` / `-of clib`
(`.c`, and `.h` for clib). Exit `1`
if any sample fails.

## Test

```powershell
alr run -- eml_tests
# or
./bin/eml_tests
```

Coverage includes regex automata, preprocessor, mxeml/teml/eml tokenization,
parsers, IR lowering, the interpreter, BEML reader, and CLI happy/negative
paths.

## Layout

| Path | Role |
|------|------|
| `src/eml.ads` | Root `Eml` package |
| `src/eml-main.adb` | Main procedure (`Eml.Main` → binary `eml`) |
| `src/eml-cli.*` | CLI (`preproc`, `tokenize`, `parse`, `compile`, `run`, banner, flags) |
| `src/eml-diagnostics.*` | Diagnostic ID catalog and formatting |
| `src/eml-info.*` | Program name / author / version / commit |
| `src/regex_automata.*` | In-repo regex → NFA library |
| `src/expr_preprocessor.*` | `$VARNAME` substitution for mxeml/teml |
| `src/expr_tokenizer.*` | `.mxeml` tokenizer |
| `src/expr_parser.*` | `.mxeml` parser and tree emitters |
| `src/expr_lower.*` | `.mxeml` AST → IR EML lowering |
| `src/teml_tokenizer.*` | Nested `.teml` tokenizer |
| `src/teml_parser.*` | Nested `.teml` → IR |
| `src/eml_tokenizer.*` | Stack `.eml` tokenizer |
| `src/eml_parser.*` | Stack `.eml` → IR |
| `src/beml_reader.*` | `.beml` binary reader |
| `src/beml_parser.*` | BEML opcodes → IR |
| `src/ir_eml.*` | Shared IR EML tree, encoders, and tree dumps |
| `src/interpreter.*` | In-process ONE/EML interpreter (`eml run`) |
| `tests/` | Unit and CLI tests |
| `scripts/embed_git_commit.ps1` | Pre-build short-hash embed |
| `scripts/run_samples.ps1` | Batch preproc / tokenize / parse / compile / run samples |
