---
name: opus-plan
description: use Claude Opus to plan development for Claude Sonnet
allowed-tools: java, bash
---

Rather than implementing any code, output should be a markdown file in `./ai-context`
that contains a phased implementation plan where each phase fits in the Claude Sonnet 4.6 context window.

No changes should be made, other than writing one new plan document.

After each phase Claude Sonnet should write to ./ai-context/PROGRESS.md so we can /clear and continue with a fresh context.

For C or C++ code:

Build should be with make, we should use musl where possible (no external libs needed)
all warnings should be fixed
plan should include adding cppcheck to the Makefile and fixing all issues
Code should include snip tests, per https://tp23.org/snip-testing.html
There shoudl be abash test framework for integration testing
tests hould use .../fixtures for test data and config
