# Jamcrest — Phased Implementation Plan

Build target: a CLI tool `jamcrest` that reads a JSON document from stdin and matches
it against a JavaScript matcher object, using an embedded V8 engine. C++ is a thin
host (V8 lifecycle, CLI args, stdin); all matching logic lives in JavaScript.

Each phase below is scoped so that an implementing agent (Claude Sonnet 4.6) can
load only the files listed in **Touches** plus this plan and complete the phase
without exceeding its context window.

---

## Conventions used throughout

- Build system: **GNU make** with a single top-level `Makefile`. No CMake.
- Dependency provisioning: shell scripts under `./setup/` (idempotent, re-runnable).
- Binary output: `./target/jamcrest`.
- C++ source: `./src/cpp/` (only V8 host + CLI plumbing).
- JS source: `./src/js/` (all matching logic).
- Tests: `./test/*.sh` (bash, invoke the built binary; one script per feature).
- Fixtures: `./test/fixtures/` (input JSON + expected matcher JS pairs).
- Exit codes: `0` = match, `1` = no match, `2` = usage/IO error.
- Every phase ends with `make test` green and a single commit.

## File layout (final state)

```
.
├── Makefile
├── setup/
│   ├── install-deps.sh          # apt / yum / brew dispatch
│   └── build-v8.sh              # fallback: build V8 from depot_tools
├── src/
│   ├── cpp/
│   │   ├── main.cpp             # entry, argv handling, stdin slurp
│   │   ├── v8_host.cpp/.h       # isolate/context lifecycle, JS file loader
│   │   └── cli_args.cpp/.h      # flag parsing
│   └── js/
│       ├── jamcrest-impl.js     # entry: compare(input, matcher, opts)
│       ├── jamcrest-matchers.js # all matcher factories
│       └── jamcrest-bootstrap.js# glue called from C++
├── test/
│   ├── run-all.sh
│   ├── lib.sh                   # assert_match / assert_no_match helpers
│   ├── fixtures/
│   │   ├── alice.json
│   │   ├── alice-matcher.js
│   │   └── ...
│   └── <phase-feature>.sh       # one per matcher group
└── target/
    └── jamcrest                 # built binary
```

---

## Phase 1 — Project scaffolding, Makefile, dependency setup

**Goal:** A working `make` build that produces a no-op `./target/jamcrest` binary,
plus reproducible scripts that install/locate V8.

**Touches**
- `Makefile`
- `setup/install-deps.sh`
- `setup/build-v8.sh`
- `src/cpp/main.cpp` (minimal `int main` that prints "jamcrest" and exits 0)
- `test/run-all.sh` (just runs `./target/jamcrest --version` for now)
- `test/lib.sh`
- `.gitignore`

**Tasks**
1. `setup/install-deps.sh`
   - Detect package manager (`apt-get`, `dnf`, `brew`).
   - Install `build-essential`/`clang`, `pkg-config`, `python3`, `curl`, `git`.
   - Try the distro V8 dev package first (`libnode-dev` on Debian gives a usable
     V8 via libnode; otherwise `libv8-dev` if available).
   - If no usable V8 headers/libs found, exec `setup/build-v8.sh`.
   - Emit `setup/.v8.mk` with `V8_CFLAGS=…` and `V8_LDFLAGS=…` for the Makefile.
2. `setup/build-v8.sh`
   - Clone `depot_tools` into `setup/_deps/depot_tools`.
   - `fetch v8`, `gclient sync`, build a static monolith
     (`v8_monolithic=true is_component_build=false`).
   - Write absolute include/lib paths into `setup/.v8.mk`.
   - Idempotent: skip if `setup/_deps/v8/out/x64.release/obj/libv8_monolith.a` exists.
3. `Makefile` targets:
   - `setup` → runs `setup/install-deps.sh`.
   - `all` (default) → builds `target/jamcrest`.
   - `clean` → removes `target/`.
   - `distclean` → removes `target/` and `setup/_deps/`.
   - `test` → builds then runs `test/run-all.sh`.
   - `install` (PREFIX=/usr/local) → `cp target/jamcrest $(PREFIX)/bin/`.
   - Includes `setup/.v8.mk` if present.
4. `test/lib.sh`: define `assert_eq`, `assert_match` (exit-code 0 from binary),
   `assert_no_match` (exit-code 1), `assert_usage_error` (exit-code 2), `pass`,
   `fail`. Tally results, exit non-zero if any failed.
5. `test/run-all.sh`: source `lib.sh`, sourceglob `test/*.sh` except itself,
   print summary.

**Acceptance**
- `make setup && make && make test` succeeds on a clean checkout.
- `./target/jamcrest --version` prints a version string.

**Commit:** `phase 1: project scaffolding, makefile, v8 dependency setup`

---

## Phase 2 — V8 host: embed, load JS, run

**Goal:** C++ binary can initialize V8, load `src/js/*.js` from disk, evaluate it,
and report uncaught JS exceptions cleanly. Still ignores stdin and most flags.

**Touches**
- `src/cpp/v8_host.cpp` / `v8_host.h`
- `src/cpp/main.cpp` (update)
- `src/js/jamcrest-bootstrap.js` (placeholder: prints "ok")
- `test/phase2-bootstrap.sh`
- `Makefile` (link rules)

**Tasks**
1. `V8Host` class:
   - `Init()` — `V8::InitializeICUDefaultLocation`, platform, isolate, context.
   - `LoadFile(path)` — read file → `v8::Script::Compile` → `Run`.
   - `Call(fnName, argsJson)` — look up global function, JSON-parse `argsJson`
     to a `v8::Value`, invoke, JSON-stringify the return value.
   - `Shutdown()` — dispose isolate, platform.
   - Uncaught exceptions: capture `TryCatch`, format
     `file:line: message\n  stack…` to stderr, return non-zero status.
2. `main.cpp`: locate JS root (env `JAMCREST_JS_DIR` or `<bin>/../share/jamcrest/js`
   or `./src/js` relative to argv[0] for dev), load
   `jamcrest-matchers.js` then `jamcrest-impl.js` then `jamcrest-bootstrap.js`.
   Call `bootstrap()` which returns `"ok"`. Print it.
3. Makefile compile/link rules using `V8_CFLAGS` / `V8_LDFLAGS` from
   `setup/.v8.mk`.

**Acceptance**
- `make test` passes `phase2-bootstrap.sh` which asserts the binary prints "ok"
  and exits 0.
- Deliberately broken JS file produces stderr with file:line and exit ≠ 0.

**Commit:** `phase 2: v8 host + js file loading`

---

## Phase 3 — CLI args, stdin slurp, matcher loading, test harness

**Goal:** Real CLI surface. `cat input.json | jamcrest --matcher matcher.js`
loads both, calls `jamcrest.compare(input, matcher, opts)` in JS (still a stub
that always returns `{ match: true }`), exits 0/1.

**Touches**
- `src/cpp/cli_args.cpp` / `.h`
- `src/cpp/main.cpp` (update)
- `src/js/jamcrest-impl.js` (stub `compare()` returning `{match:true}`)
- `src/js/jamcrest-bootstrap.js` (wire `compare`)
- `test/phase3-cli.sh`
- `test/fixtures/alice.json`, `test/fixtures/alice-matcher.js`

**Flags**
- `--matcher <path>` (required)
- `--ignore-unknown` / `--ignore-properties` (synonyms; parsed, stored, not yet used)
- `--quiet` (suppress diagnostic on mismatch)
- `--help`, `--version`

**Tasks**
1. `cli_args`: hand-rolled parser (no getopt dependency). Returns a struct with
   `matcher_path`, `ignore_unknown`, `quiet`, plus error string.
2. `main.cpp`:
   - Parse argv → `CliArgs`. Usage errors → exit 2.
   - Read all of stdin into `std::string` (binary-safe, up to e.g. 64 MB).
   - Read matcher file → `std::string`.
   - In JS: evaluate the matcher source as `globalThis.__matcher = (…matcher source…)`
     (wrap in parens to allow object-literal at top level).
   - Call `jamcrest.compare(JSON.parse(input), __matcher, opts)`.
   - On `result.match === true` → exit 0.
   - On `false` → write `result.diagnostic` to stderr unless `--quiet`, exit 1.
3. Test fixtures (`alice.json` matching `alice-matcher.js`, both with identical
   `{id:1234,name:"Alice"}` content).

**Acceptance**
- `phase3-cli.sh` covers: matching pair → 0; `--help` → 0 with usage; missing
  `--matcher` → 2; unreadable matcher → 2; malformed JSON on stdin → 2.

**Commit:** `phase 3: cli args, stdin/matcher loading, test harness`

---

## Phase 4 — Core deep-equal comparator (strict default mode)

**Goal:** `jamcrest.compare` performs true recursive equality on plain JSON
values (no matchers yet). Produces a path-based diagnostic on mismatch.

**Touches**
- `src/js/jamcrest-impl.js` (real implementation)
- `test/phase4-deep-equal.sh`
- `test/fixtures/deep/*.json|.js`

**Spec**
- Primitives compare by `===`, with `NaN===NaN` treated as equal.
- Arrays: same length, element-wise.
- Objects: same key set, recurse per key.
- Extra keys in input are NOT yet ignored (`--ignore-unknown` is honored in Phase 12).
- On mismatch return `{match:false, diagnostic:"at $.path.to.field: expected X got Y"}`.

**Tasks**
1. Implement `deepEqual(input, matcher, path)` returning `{match, diagnostic}`.
2. Export `compare(input, matcher, opts)` that calls into `deepEqual` and threads
   opts through (unused for now).
3. Fixtures: identical pair (pass), wrong scalar (fail), missing key (fail),
   extra key (fail), array length mismatch (fail), nested mismatch (fail with
   correct path), `NaN` equality (pass).

**Acceptance**
- All `phase4-deep-equal.sh` cases pass; diagnostic paths verified by `grep`.

**Commit:** `phase 4: deep-equal comparator (strict mode)`

---

## Phase 5 — Matcher dispatch + type matchers

**Goal:** When a matcher value is a function it is invoked with the input value
instead of compared by `===`. Implement the `any*` / `isA` / `notANumber` family.

**Touches**
- `src/js/jamcrest-impl.js` (dispatch)
- `src/js/jamcrest-matchers.js` (new factories)
- `test/phase5-type-matchers.sh`
- `test/fixtures/types/*`

**Matchers in this phase**
`any()`, `anyBoolean()`, `anyString()`, `anyNumber()`, `anyArray()`, `anyObject()`,
`anything()`, `isA(typeName)`, `notANumber()`, `notNullValue()`, `blankOrNull()`.

**Tasks**
1. Convention: each factory returns a function with `.__jamcrest = true` and
   `.describe = "anyNumber"` (used in diagnostics).
2. `deepEqual` dispatch: if `typeof matcher === 'function' && matcher.__jamcrest`,
   call `matcher(input)`; truthy → match, falsy → produce
   `"at $.path: expected <describe> got <typeof+preview>"`.
3. Expose factories on `globalThis` so matcher files can use them unqualified.
4. Tests: one fixture per matcher (pass + fail case each).

**Acceptance**
- `phase5-type-matchers.sh` covers every matcher above with pass + fail fixtures.

**Commit:** `phase 5: matcher dispatch + type matchers`

---

## Phase 6 — Comparison & string matchers

**Goal:** Numeric and string matcher families.

**Touches**
- `src/js/jamcrest-matchers.js` (extend)
- `test/phase6-comparison.sh`
- `test/phase6-strings.sh`
- `test/fixtures/comparison/*`, `test/fixtures/strings/*`

**Matchers**
- Numeric: `greaterThan(n)`, `greaterThanOrEqualTo(n)`, `lessThan(n)`,
  `lessThanOrEqualTo(n)`, `closeTo(operand, error)`,
  `equalTo(v)`, `equalToIgnoringCase(s)`.
- String: `containsString(s)`, `startsWith(s)`, `endsWith(s)`,
  `startsWithIgnoringCase(s)`, `emptyString()`, `hasLength(n)`,
  `matchesPattern(re)`, `matchesRegex(re)` (alias).

**Tasks**
1. Implement each as a factory returning a tagged function.
2. `matchesPattern` accepts either a `RegExp` or a string pattern.
3. Fixtures cover boundary cases (`closeTo` at exactly ±error, `lessThan` at
   equal value should fail, etc.).

**Acceptance**
- Both phase6 scripts green.

**Commit:** `phase 6: comparison and string matchers`

---

## Phase 7 — Collection / array matchers

**Goal:** Array-shaped matchers including the special "single-matcher-applied-to-
all-elements" array rule from the README.

**Touches**
- `src/js/jamcrest-impl.js` (special-case array of length 1 holding a matcher)
- `src/js/jamcrest-matchers.js` (extend)
- `test/phase7-arrays.sh`
- `test/fixtures/arrays/*`

**Matchers**
`empty()`, `emptyArray()`, `arrayWithSize(n)`, `arrayContaining(...)`,
`arrayContainingInAnyOrder(...)`, `anySorted(arr, comparator)`.

**Special rule** (from README): when the matcher position is an array of length
1 whose sole element is a tagged matcher function, apply that function to every
element of the input array.

**Tasks**
1. In `deepEqual`, detect `Array.isArray(matcher) && matcher.length === 1 &&
   matcher[0].__jamcrest` before falling through to element-wise compare.
2. `anySorted(expected, cmp)` — sort copies of both arrays with `cmp`, then
   element-wise compare (matchers allowed in `expected`).
3. `arrayContainingInAnyOrder` — bipartite match (each expected matcher pairs
   with one input element).
4. Fixtures: applies-to-all rule, sorted array of strings, contains-in-any-order
   with mixed matchers and literals.

**Acceptance**
- `phase7-arrays.sh` green.

**Commit:** `phase 7: array and collection matchers`

---

## Phase 8 — Map/object matchers + logical combinators

**Goal:** Key-based matchers and matcher composition.

**Touches**
- `src/js/jamcrest-matchers.js` (extend)
- `test/phase8-objects.sh`
- `test/phase8-logical.sh`
- `test/fixtures/objects/*`, `test/fixtures/logical/*`

**Matchers**
- Object: `hasKey(k)`, `hasProperty(k, valueMatcher?)`, `aMapWithSize(n)`,
  `anEmptyMap()`, `in(collection)`.
- Logical: `not(m)`, `anyOf(...m)`, `either(m).or(m)` (chained, see below).

**Tasks**
1. `either(m)` returns an object `{or(m2): function}` so `either(a).or(b)` works.
   Document this divergence from raw factory pattern.
2. `not` inverts result and rewrites diagnostic to "expected not <describe>".
3. Fixtures: `hasProperty("name", containsString("Ali"))`, `not(emptyString())`,
   `anyOf(equalTo(1), equalTo(2), equalTo(3))`, `either(anyNumber()).or(anyString())`.

**Acceptance**
- Both phase8 scripts green.

**Commit:** `phase 8: object and logical matchers`

---

## Phase 9 — Flags, integration, install

**Goal:** Wire up the unknown-key flag, end-to-end README examples work, install
target is usable.

**Touches**
- `src/js/jamcrest-impl.js` (honor `opts.ignoreUnknown`)
- `src/cpp/main.cpp` (pass flag through)
- `test/phase9-flags.sh`
- `test/phase9-readme-examples.sh`
- `test/fixtures/readme/*`
- `Makefile` (`install` target finalized to also copy `src/js/` to
  `$(PREFIX)/share/jamcrest/js/`)
- `README.md` (usage section verified against actual binary; only changes if
  divergence found)

**Tasks**
1. `compare(input, matcher, {ignoreUnknown})`: when true, extra keys in input
   objects are not treated as a mismatch (recurse only on keys present in matcher).
2. `--ignore-unknown` and `--ignore-properties` both flip the same flag.
3. Re-implement the two README examples as fixtures and assert they behave as
   documented (`anyNumber()` example must pass).
4. `make install PREFIX=/tmp/jc-test` then run binary from `/tmp/jc-test/bin/` to
   verify JS files are discoverable via the `share/jamcrest/js` lookup added in
   Phase 2.

**Acceptance**
- All phase scripts green. Fresh checkout: `make setup && make && make test`
  passes. `make install PREFIX=/tmp/x && /tmp/x/bin/jamcrest --version` works.

**Commit:** `phase 9: flags, readme integration, install target`

---

## Out-of-scope (explicitly deferred)

- Streaming / NDJSON input (one match per line).
- Custom user-provided matcher plugins loaded from arbitrary paths.
- Coloured diagnostic output / TTY detection.
- Windows support (POSIX only).
- Performance tuning beyond "doesn't hang on 64 MB input".

## Cross-phase rules for the implementing agent

- Do NOT add features from later phases early. If a matcher is listed for phase N,
  do not stub it in phase N-1 even as a no-op.
- Every commit must leave `make test` green.
- New bash test files must be sourced by `test/run-all.sh` automatically (glob).
- C++ code must compile with `-Wall -Wextra -Werror -std=c++17`.
- JS code targets the V8 version produced by `setup/`; no Node-specific APIs
  (no `require`, no `process`, no `fs`). Use only ECMAScript built-ins.
