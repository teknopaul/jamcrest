# Plan: `--template` mode in the existing `jamcrest` binary

## Requirements source

`ai-prompts/templating.md` — reproduced here for context:

> Jamcrest C++ needs a templating mechanism that uses JavaScript input and supports
> replacing variables supplied on the command line
>
> `jamcrest --template <template.req.js> --data <input.js> | curl ...`
>
> This enables users to take a request template and create a JSON output with global
> variables replaced with input variables.
>
> `template.req.js`:
> ```js
> { user: { name: name, password: pass } }
> ```
>
> `input.js`:
> ```js
> { name:"alice", pass: 1234 }
> ```
>
> N.B. the input .js file allows using JavaScript primitive types, not just strings.

---

## Design

This is a **new execution mode** inside the existing `jamcrest` binary — no separate binary.

### How it works

1. Load `input.js` as a JS object expression; spread its properties into `globalThis`
   (identical to what `--args=EXPR` already does).
2. Load `template.req.js` as a JS expression; evaluate it with those names in scope.
3. `JSON.stringify` the result and write to stdout.
4. Exit 0 on success, 2 on any error.

V8 is already initialised. The existing `host.EvalReturn()` handles step 2 exactly.
The embedded jamcrest JS (matchers etc.) is still loaded but not invoked in this mode.

### New flags

| Flag | Meaning |
|------|---------|
| `--template <path>` | path to template JS expression file (`.req.js`) |
| `--data <path>` | path to data JS object file (`.js`) |

Both flags must appear together; either alone is a usage error (exit 2).
`--template` and `--matcher` are mutually exclusive (exit 2 if both given).
In template mode stdin is **not read**.

### Template file format

A bare JS expression whose value is serialisable to JSON.
Variable names refer to properties spread from the data file:

```js
{
    user: {
        name: name,
        password: pass
    }
}
```

### Data file format

A bare JS object expression. Values may be any JSON-serialisable JS type
(string, number, boolean, null, array, nested object):

```js
{
    name: "alice",
    pass: 1234
}
```

### Output

`JSON.stringify` of the evaluated template expression written to stdout.
Errors (unresolved var, syntax error, non-serialisable result) go to stderr,
exit 2.

---

## Files changed / added

```
src/cpp/
  cli_args.h          ← add template_path, data_path fields
  cli_args.cpp        ← parse --template and --data
  main.cpp            ← new template-mode branch

test/fixtures/templating/
  login/
    template.req.js   ← {user:{name:name,password:pass}}
    data.js           ← {name:"alice",pass:1234}
    expected.json     ← {"user":{"name":"alice","password":1234}}
  config/
    template.req.js   ← {host:host,port:port,debug:debug}
    data.js           ← {host:"example.com",port:8080,debug:false}
    expected.json
  types/
    template.req.js   ← exercises string, number, bool, null, array, object
    data.js
    expected.json
  errors/
    undef-template.req.js   ← references name not in data → ReferenceError
    undef-data.js           ← {}
    bad-syntax.req.js       ← } invalid syntax {

test/
  tpl-phase1-scaffold.sh
  tpl-phase2-render.sh
  tpl-phase3-types-errors.sh

Makefile              ← add cppcheck target
```

---

## Phase 1 — Scaffold (context budget ~1 200 lines)

**Goal**: `--template` and `--data` are recognised flags; `--help` updated;
usage errors work; one test script passes.

### Exact tasks

#### 1. `src/cpp/cli_args.h`

Add two fields after `array_sort_keys`:

```cpp
std::string template_path;  // --template <path>
std::string data_path;      // --data <path>
```

#### 2. `src/cpp/cli_args.cpp`

Inside the `else if` chain add:

```cpp
} else if (std::strcmp(arg, "--template") == 0) {
    if (i + 1 >= argc) { a.error = "--template requires a path"; return a; }
    a.template_path = argv[++i];
} else if (std::strcmp(arg, "--data") == 0) {
    if (i + 1 >= argc) { a.error = "--data requires a path"; return a; }
    a.data_path = argv[++i];
}
```

After the loop, add validation:

```cpp
// --template and --matcher are mutually exclusive
if (!a.template_path.empty() && !a.matcher_path.empty())
    a.error = "--template and --matcher are mutually exclusive";
// --template requires --data and vice versa
if (a.template_path.empty() != a.data_path.empty())
    a.error = "--template and --data must be used together";
```

#### 3. `src/cpp/main.cpp` — update `--help` block and add stub

In the `--help` printf block, add:
```cpp
std::printf("       --template <path>           Render a JS template to JSON (requires --data).\n");
std::printf("       --data <path>               JS object supplying template variables.\n");
```

After the matcher_path empty-check block, add the template-mode guard:

```cpp
// Template mode: render JS template with data vars, output JSON to stdout.
if (!args.template_path.empty()) {
    std::fprintf(stderr, "jamcrest: --template mode not yet implemented\n");
    return 2;
}
```

#### 4. `test/tpl-phase1-scaffold.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_output_contains "--help shows --template" "--template" --help
assert_output_contains "--help shows --data"     "--data"     --help

# --template without --data → exit 2
assert_usage_error "--template alone is error" --template /dev/null

# --data without --template → exit 2
assert_usage_error "--data alone is error" --data /dev/null

# --template + --matcher together → exit 2
assert_usage_error "--template and --matcher conflict" \
    --template /dev/null --matcher /dev/null

print_summary
```

#### 5. `test/run-all.sh` — extend glob

```bash
for script in "$SCRIPT_DIR"/phase*.sh \
              "$SCRIPT_DIR"/tpl-phase*.sh \
              "$SCRIPT_DIR"/test-*.sh; do
```

#### 6. Write `ai-context/PROGRESS.md`

---

## Phase 2 — Template rendering implementation (context budget ~1 600 lines)

**Goal**: `jamcrest --template template.req.js --data data.js` produces correct
JSON on stdout; `tpl-phase2-render.sh` passes.

### Exact tasks

#### 1. Create fixture files

`test/fixtures/templating/login/template.req.js`:
```js
({
    user: {
        name: name,
        password: pass
    }
})
```

`test/fixtures/templating/login/data.js`:
```js
({
    name: "alice",
    pass: 1234
})
```

`test/fixtures/templating/login/expected.json`:
```json
{"user":{"name":"alice","password":1234}}
```

`test/fixtures/templating/config/template.req.js`:
```js
({
    host: host,
    port: port,
    debug: debug
})
```

`test/fixtures/templating/config/data.js`:
```js
({
    host: "example.com",
    port: 8080,
    debug: false
})
```

`test/fixtures/templating/config/expected.json`:
```json
{"host":"example.com","port":8080,"debug":false}
```

Note: wrap bare object expressions in `({...})` so V8 does not parse them as
block statements. Strip trailing whitespace/semicolons the same way the existing
code does for matchers.

#### 2. `src/cpp/main.cpp` — implement template mode

Replace the `"not yet implemented"` stub with:

```cpp
if (!args.template_path.empty()) {
    // --- Template mode ---
    std::string data_src, tpl_src, err;

    if (!read_file(args.data_path, data_src, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }
    if (!read_file(args.template_path, tpl_src, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }

    V8Host host;
    if (!host.Init()) {
        std::fprintf(stderr, "jamcrest: failed to initialize V8\n");
        return 2;
    }

    // Load embedded jamcrest JS (needed for V8 global setup)
    struct { const unsigned char* data; unsigned int len; const char* name; } js[] = {
        { src_js_jamcrest_matchers_js,  src_js_jamcrest_matchers_js_len,  "jamcrest-matchers.js"  },
        { src_js_jamcrest_impl_js,      src_js_jamcrest_impl_js_len,      "jamcrest-impl.js"      },
        { src_js_jamcrest_bootstrap_js, src_js_jamcrest_bootstrap_js_len, "jamcrest-bootstrap.js" },
    };
    for (auto& f : js) {
        std::string src(reinterpret_cast<const char*>(f.data), f.len);
        if (!host.Eval(src, f.name, err)) {
            std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
            return 2;
        }
    }

    // Spread data object properties into globalThis (same as --args path)
    auto strip_trailing = [](std::string& s) {
        size_t end = s.find_last_not_of(" \t\r\n;");
        if (end != std::string::npos) s.resize(end + 1);
    };
    strip_trailing(data_src);
    std::string spread_expr =
        "(function(__d){for(var __k in __d)globalThis[__k]=__d[__k];})(" + data_src + ");";
    if (!host.Eval(spread_expr, args.data_path, err)) {
        std::fprintf(stderr, "jamcrest: --data error: %s\n", err.c_str());
        return 2;
    }

    // Evaluate template expression and JSON.stringify result
    strip_trailing(tpl_src);
    std::string tpl_eval = "JSON.stringify(" + tpl_src + ")";
    std::string result_json;
    if (!host.EvalReturn(tpl_eval, args.template_path, result_json, err)) {
        std::fprintf(stderr, "jamcrest: --template error: %s\n", err.c_str());
        return 2;
    }

    // result_json is a JSON string literal ("..."); unescape it for final output
    std::string output = unescape_json_string(result_json);
    std::printf("%s\n", output.c_str());
    return 0;
}
```

Place this block **before** the existing `if (args.matcher_path.empty())` check
so the normal matcher flow is skipped entirely in template mode.

#### 3. `test/tpl-phase2-render.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures/templating"

assert_template() {
    local label="$1" tpl="$2" data="$3" expected_file="$4"
    local out expected rc=0
    out=$("$BINARY" --template "$tpl" --data "$data" 2>/dev/null) || rc=$?
    expected=$(cat "$expected_file")
    if [ "$rc" -ne 0 ]; then
        fail "$label (exit $rc)"
    elif [ "$out" = "$expected" ]; then
        pass "$label"
    else
        fail "$label (got='$out' want='$expected')"
    fi
}

assert_template "login template" \
    "$FIXTURES/login/template.req.js" \
    "$FIXTURES/login/data.js" \
    "$FIXTURES/login/expected.json"

assert_template "config template" \
    "$FIXTURES/config/template.req.js" \
    "$FIXTURES/config/data.js" \
    "$FIXTURES/config/expected.json"

print_summary
```

#### 4. Write `ai-context/PROGRESS.md`

---

## Phase 3 — Types, errors, and pipeline (context budget ~1 400 lines)

**Goal**: all JS types work; error cases exit 2 with message; a round-trip
render → `jamcrest --matcher` pipeline test passes.

### Exact tasks

#### 1. `test/fixtures/templating/types/` — exercises all JS primitive types

`template.req.js`:
```js
({
    s: strVal,
    n: numVal,
    b: boolVal,
    z: nullVal,
    arr: arrVal,
    obj: objVal
})
```

`data.js`:
```js
({
    strVal:  "hello",
    numVal:  3.14,
    boolVal: true,
    nullVal: null,
    arrVal:  [1, 2, 3],
    objVal:  { x: 1 }
})
```

`expected.json`:
```json
{"s":"hello","n":3.14,"b":true,"z":null,"arr":[1,2,3],"obj":{"x":1}}
```

#### 2. Error fixture files

`test/fixtures/templating/errors/undef-template.req.js`:
```js
({ result: notDefined })
```

`test/fixtures/templating/errors/undef-data.js`:
```js
({})
```

`test/fixtures/templating/errors/bad-syntax.req.js`:
```js
} this is not valid JS {
```

#### 3. `test/tpl-phase3-types-errors.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures/templating"

# Types
out=$("$BINARY" --template "$FIXTURES/types/template.req.js" \
    --data "$FIXTURES/types/data.js" 2>/dev/null)
assert_eq "all types render" "$(cat "$FIXTURES/types/expected.json")" "$out"

# Undefined variable → exit 2
rc=0
"$BINARY" --template "$FIXTURES/errors/undef-template.req.js" \
    --data "$FIXTURES/errors/undef-data.js" 2>/dev/null || rc=$?
assert_eq "undef var → exit 2" 2 "$rc"

# Syntax error in template → exit 2
rc=0
"$BINARY" --template "$FIXTURES/errors/bad-syntax.req.js" \
    --data "$FIXTURES/errors/undef-data.js" 2>/dev/null || rc=$?
assert_eq "syntax error → exit 2" 2 "$rc"

# Pipeline: render login template then assert with jamcrest --matcher
login_out=$("$BINARY" \
    --template "$FIXTURES/login/template.req.js" \
    --data    "$FIXTURES/login/data.js")
rc=0
echo "$login_out" | "$BINARY" \
    --matcher "$FIXTURES/login/matcher.js" 2>/dev/null || rc=$?
assert_eq "render→assert pipeline" 0 "$rc"

print_summary
```

#### 4. `test/fixtures/templating/login/matcher.js`

```js
matcher = {
    "user": {
        "name": anyString(),
        "password": anyNumber()
    }
};
```

#### 5. Write `ai-context/PROGRESS.md`

---

## Phase 4 — cppcheck (context budget ~800 lines)

**Goal**: `make cppcheck` target added and passes against all C++ sources.

### Exact tasks

#### 1. `Makefile` — add cppcheck target

```makefile
cppcheck:
	@command -v cppcheck >/dev/null 2>&1 || \
	    { echo "cppcheck not installed; skipping"; exit 0; }
	cppcheck --enable=all --error-exitcode=1 \
	    --suppress=missingIncludeSystem \
	    --suppress=unmatchedSuppression \
	    -I src/cpp \
	    src/cpp/cli_args.cpp src/cpp/v8_host.cpp src/cpp/main.cpp
```

#### 2. Fix any cppcheck findings

Likely findings in the current code and new code:
- Unchecked return value from `realloc`-style calls (none in this codebase, but verify)
- `printf` format string mismatches
- Possible null dereferences after `.ToLocal()`

Fix each finding. If a finding is a false positive from V8 headers, add a
targeted `--suppress=<id>:<file>` to the Makefile target rather than inline
`// cppcheck-suppress` in source (keeps source clean).

#### 3. `make test` — full suite must pass

Run `make test` and confirm exit 0, including the new `tpl-phase*.sh` scripts.

#### 4. Write final `ai-context/PROGRESS.md`

```markdown
# PROGRESS

## Status: COMPLETE

All phases done. `make test` passes.

## What was built
- `--template <path>` and `--data <path>` flags added to existing jamcrest binary
- Template mode: loads data JS object, spreads vars into globalThis, evaluates
  template JS expression, JSON.stringify output to stdout
- Fixtures in test/fixtures/templating/{login,config,types,errors}/
- Bash tests: tpl-phase1-scaffold.sh, tpl-phase2-render.sh, tpl-phase3-types-errors.sh
- Makefile: cppcheck target

## Files changed
- src/cpp/cli_args.h
- src/cpp/cli_args.cpp
- src/cpp/main.cpp
- Makefile
- test/run-all.sh

## Files added
- test/tpl-phase1-scaffold.sh
- test/tpl-phase2-render.sh
- test/tpl-phase3-types-errors.sh
- test/fixtures/templating/** (all fixture files)
- ai-context/PROGRESS.md
```

---

## Key constraints (carry into every phase)

- No new binary — all changes are inside the existing `jamcrest` C++ build.
- No `{{}}` placeholder syntax — variables are plain JS identifiers.
- `-std=c++17 -Wall -Wextra -Werror` must stay clean.
- `cppcheck` must pass (phase 4).
- No stdin is read in template mode.
- Bash tests follow existing `lib.sh` conventions (`pass`/`fail`/`print_summary`).
- Fixtures go under `test/fixtures/templating/` — no inline data in test scripts.
- Each phase ends by writing `ai-context/PROGRESS.md`.
