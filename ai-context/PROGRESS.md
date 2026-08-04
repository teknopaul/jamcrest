# PROGRESS

## Status: COMPLETE

All phases done. `make test` passes (139 tests). `make cppcheck` passes.

## What was built
- `--template <path>` and `--data <path>` flags added to existing jamcrest binary
- Template mode: loads data JS object, spreads vars into globalThis, evaluates
  template JS expression, JSON-stringifies output to stdout
- Fixtures in test/fixtures/templating/{login,config,types,errors}/
- Bash tests: tpl-phase1-scaffold.sh, tpl-phase2-render.sh, tpl-phase3-types-errors.sh
- Makefile: cppcheck target

## Files changed
- src/cpp/cli_args.h — added template_path, data_path fields
- src/cpp/cli_args.cpp — parse --template and --data; mutual-exclusion validation
- src/cpp/main.cpp — help text, template-mode implementation; fixed const ref in args loop
- Makefile — added cppcheck target
- test/run-all.sh — extended glob to include tpl-phase*.sh
- test/lib.sh — fixed assert_output_contains to use grep -q -- (handles -- patterns)

## Files added
- test/tpl-phase1-scaffold.sh
- test/tpl-phase2-render.sh
- test/tpl-phase3-types-errors.sh
- test/fixtures/templating/login/{template.req.js,data.js,expected.json,matcher.js}
- test/fixtures/templating/config/{template.req.js,data.js,expected.json}
- test/fixtures/templating/types/{template.req.js,data.js,expected.json}
- test/fixtures/templating/errors/{undef-template.req.js,undef-data.js,bad-syntax.req.js}
- ai-context/PROGRESS.md
