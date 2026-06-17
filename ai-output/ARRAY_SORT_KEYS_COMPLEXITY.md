# Complexity Analysis: `arraySortKeys` Feature

## Feature Summary

Add an `--array-sort-keys=id,name,game` CLI flag (and equivalent Java API parameter) that automatically sorts any array whose elements are objects `{}` by the named keys — in priority order — before the comparison runs, without requiring explicit `anySorted()` in the matcher.

---

## Touchpoints

### 1. C++ CLI — Low complexity

**Files:** `cli_args.h`, `cli_args.cpp`, `main.cpp`

- Add `std::vector<std::string> array_sort_keys` field to `CliArgs`.
- Parse `--array-sort-keys=id,name,game` (or `--array-sort-keys id,name,game`) splitting on `,`.
- Serialize into the `opts_json` string that is already built in `main.cpp`:
  ```cpp
  // currently:
  "{\"ignoreUnknown\":" + (args.ignore_unknown ? "true" : "false") + "}"
  // becomes:
  "{\"ignoreUnknown\":..., \"arraySortKeys\":[\"id\",\"name\",\"game\"]}"
  ```
  This is mechanical string work — straightforward but tedious to get the JSON escaping right.

### 2. Java CLI — Low complexity

**Files:** `JamcrestCli.java`, `Jamcrest.java`

- Parse `--array-sort-keys` in `JamcrestCli` (same pattern as existing flags).
- Thread it through to `Jamcrest.compare()`, either as a new overload parameter or via a new `Options` record.
- Serialize into `optsJson` the same way as C++.

> **Note:** If the `contextArgs` varargs approach is kept, adding a new structural option (not a simple `boolean`) may be the nudge to introduce a proper `Options` object to both `JamcrestCli` and `Jamcrest` — small refactor, no risk.

### 3. JS core (`jamcrest-impl.js`) — Medium complexity

**This is the main work.**

The `deepEqual` function already uses a side-channel pattern (`deepEqual._ignoreUnknown = ...`) instead of threading opts through every recursive call. The same pattern would work for `arraySortKeys`:

```js
deepEqual._arraySortKeys = opts.arraySortKeys || null;
```

Inside the `Array` branch of `deepEqual`, before the element-wise loop:

1. Check if `_arraySortKeys` is set and non-empty.
2. Check if at least one element of the array is a plain object (not primitive, not a matcher function). If not, skip sorting — arrays of strings/numbers should be unaffected.
3. Build a compound comparator from the key list using the existing `compareByField` logic (already in `jamcrest-matchers.js`).
4. Sort **copies** of both `input` and `matcher` arrays by that comparator.

Gotcha: the `matcher` side may contain jamcrest matcher functions rather than plain objects. Sorting a mixed array of functions and objects by a field comparator could behave oddly. A safe approach: only sort if **all** matcher elements are plain objects (not matcher functions). If the matcher contains matcher functions, leave both arrays unsorted and let the existing logic handle it.

### 4. Cross-module opts threading — Medium complexity (the tricky part)

`_matchValue` in `jamcrest-matchers.js` calls back into `jamcrest.compare()`:

```js
// jamcrest-matchers.js line 222
var r = jamcrest.compare(input, matcher, {});  // <-- opts is always {}
return r.match;
```

This means nested object comparisons triggered through `_matchValue` will **not** see the sort keys — they are lost at the module boundary. Any array nested inside an object that is itself inside another array would be compared without sorting.

**Options:**

| Approach | Effort | Risk |
|---|---|---|
| Extend the side-channel: expose `jamcrest._currentOpts` and read it in `_matchValue` | Low | Slightly ugly but consistent with `deepEqual._ignoreUnknown` already doing this |
| Change `_matchValue` to forward opts explicitly — requires passing opts into every matcher call | Medium | Requires changing the `_make` function signature and all internal callers |
| Accept the limitation: only top-level arrays are sorted, nested arrays are not | Lowest | Surprising behaviour that would need to be documented clearly |

The side-channel approach is the least invasive and consistent with the existing code style.

---

## Sorting Logic Details

Given `arraySortKeys=id,name,game`, the comparator is:

```
sort by id asc → if equal, sort by name asc → if equal, sort by game asc
```

The existing `compareByField(path)` function in `jamcrest-matchers.js` already handles dot-notation paths and type-appropriate comparison (numeric vs. lexicographic). Building a compound comparator from the list is a small loop — the infrastructure is already there.

**Missing-key behaviour:** If an object does not have the key, `compareByField` already returns `''` (empty string). So objects missing the key sort before objects that have it. This is acceptable default behaviour but worth documenting.

---

## Risk Areas

| Risk | Severity | Mitigation |
|---|---|---|
| Sorting the matcher-side array when it contains matchers (functions) | Medium | Only sort when all elements are plain objects |
| Arrays of primitives accidentally sorted | Low | Gate on element type check before sorting |
| Lost sort keys in nested `_matchValue` callbacks | Medium | Side-channel pattern (see above) |
| C++ JSON serialisation of key list | Low | Straightforward string join with escaping |
| Rebuilding embedded JS (C++ uses xxd-compiled binary) | Low | Existing build process already handles this |

---

## Effort Estimate

| Layer | Complexity | Estimated effort |
|---|---|---|
| C++ CLI flag parsing + opts serialisation | Low | ~1h |
| Java CLI flag + `Jamcrest` API | Low | ~1h |
| JS `deepEqual` array-sort injection | Medium | ~2h |
| JS cross-module opts threading | Medium | ~1h |
| Tests | Medium | ~2h |
| **Total** | | **~7h** |

---

## Summary

The feature is **medium complexity overall**. The CLI changes on both sides are mechanical. The JS core change is self-contained but requires care around two points: (1) detecting when sorting is safe to apply (no matcher functions in the array), and (2) keeping sort keys visible to nested comparisons through the `_matchValue` → `jamcrest.compare` re-entry. The existing side-channel pattern (`deepEqual._ignoreUnknown`) gives a clear precedent for solving (2) without a larger refactor.
