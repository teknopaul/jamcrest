# Jamcrest 

`jamcrest` is a tool for validating JavaScript objects with an API similar to Hamcrest, the Java matchers API.

![jamcrest.png](jamcrest.png)

The tool is passed a JavaScript object to validate and another JavaScript object that it should use to match.

JavaScript input will be a JSON strings, the matcher is a similar JavaScript object that is JSON augmented with Hamcrest style matchers.

The default matching type is that the objects reopresent identical JavaScript objects.

e.g. for an input

```json
{
  "id" : 1234,
  "name" : "Alice"
}
```

a Jamcrest matcher

```js
matcher = {
  "name": "Alice",
  "id": 1234
};
```

Will pass.  N.B. this matcher could be a JSON object.

When it is not a requirement that an object be _exactly_ identical a Hamcrest style matcher can be provided instead.

```js
matcher = {
  "name": "Alice",
  "id": anyNumber()
};
```
N.B. this matcher could _not_ be a JSON object, its a JavsScript object.


## Matching operation

Cli code is written in C++ and the internal JavaScript library is `v8`.
The input JSON is converted to JavaScript.

The two JSON oject's attriburtes to be compared are iterated through ensuring that the input Object matches the matcher Object.

If an attribute is in the input, that is not in the matcher JavaScript, it is ignored (set `--ingnore-unknown` or `--ignore-properties`).
If an array has a single matcher that is a matcher function, it is applied to all elements in the array.
In order to compare arrays that may come in the input in a different order the array may be sorted first,

N.B. Cli flags are based on Jackson validator API terms (although Jackson is not involved)

```js  
fruit: anySorted(["apples", "bananas", "cantaloupes"], comparator) //  N.B both the input and the test array are sorted with comparator at runtime.
```

`anySorted` accepts any `(a, b) => number` comparator. 

Jamcrest provides built-in comparator factories:

```js
// Locale-aware string sort (default locale)
tags: anySorted(["apple", "banana"], localeCompare())

// Explicit locale
tags: anySorted(["café", "éclair", "zèbre"], localeCompare("fr-FR"))

// Locale with Intl.Collator options
tags: anySorted(["a", "b"], localeCompare("en", { sensitivity: "base" }))

// Sort objects by a top-level field
people: anySorted([{id:1}, {id:2}, {id:3}], compareByField("id"))

// Sort by a nested field using dot-notation path
users: anySorted([{profile:{score:10}}, {profile:{score:50}}], compareByField("profile.score"))

// Compose: sort objects by a string field, locale-aware
people: anySorted([{name:"Alice"}, {name:"Bob"}], compareByField("name", localeCompare("en")))
```



# Command line interface

```bash
curl http://someapi/ | jamcrest --matcher ./api-matcher.js
```



# Hamcrest matchers 

The matchers are based on the https://hamcrest.org API, but are not identical as they are not implemented in Java. 

Matchers supported by Jamcrestare  based on [Hamcrest 2.2](https://hamcrest.org/JavaHamcrest/javadoc/2.2/org/hamcrest/Matchers.html)

(implemented in [jamcrest-matchers.js](src/js/jamcrest-matchers.js)

- `aMapWithSize(n)` — matches when the object has exactly `n` keys.
- `anEmptyMap()` — matches when the object has zero keys.
- `any()` — matches any non-null, non-undefined value. N.B. in Jamcrest `any()` takes no argument; use `isA(type)` to match by type.
  - JavaScript type variants: `anyBoolean()`, `anyString()`, `anyNumber()`, `anyArray()`, `anyObject()`
- `anyOf(...matchers)` — matches if the value satisfies ANY of the specified matchers.
- `anything()` — always matches, regardless of the value (including null).
- `arrayContaining(...items)` — matches when the array contains each specified item (in order, extra elements allowed).
- `arrayContainingInAnyOrder(...items)` — order-agnostic version of `arrayContaining`.
- `arrayWithSize(n)` — matches when the array length equals `n`.
- `blankOrNull()` — matches when the value is null, undefined, or a whitespace-only string. N.B. Hamcrest equivalent is `blankOrNullString()`.
- `closeTo(operand, error)` — matches when the number is within `+/- error` of `operand`.
- `containsString(s)` — matches when the string contains `s` anywhere.
- `either(m).or(m2)` — matches when either matcher matches the value.
- `empty()` — matches when a string, array, or object is empty.
- `emptyArray()` — matches when the array has zero elements.
- `emptyString()` — matches when the string has zero length.
- `endsWith(s)` — matches when the string ends with `s`.
- `equalToIgnoringCase(s)` — matches when the string equals `s`, ignoring case.
- `greaterThan(n)` — matches when the number is greater than `n`.
- `greaterThanOrEqualTo(n)` — matches when the number is greater than or equal to `n`.
- `hasKey(k)` — matches when the object contains the key `k`.
- `hasLength(n)` — matches when the string or array has length `n`.
- `hasProperty(k, matcher?)` — matches when the object has property `k`, optionally satisfying a matcher.
- `inCollection(collection)` — matches when the value is found within the specified array. N.B. Hamcrest equivalent is `in()`; `in` is a reserved word in JavaScript.
- `isA(type)` — matches when the value is of the specified JavaScript type (e.g. `"string"`, `"number"`, `"array"`, `"null"`).
- `lessThan(n)` — matches when the number is less than `n`.
- `lessThanOrEqualTo(n)` — matches when the number is less than or equal to `n`.
- `matchesPattern(re)` / `matchesRegex(re)` — matches when the string matches the given regular expression.
- `not(matcher)` — inverts the logic of the wrapped matcher.
- `notANumber()` — matches when the value is `NaN`.
- `notNullValue()` — matches when the value is not null or undefined.
- `startsWith(s)` — matches when the string starts with `s`.
- `startsWithIgnoringCase(s)` — matches when the string starts with `s`, ignoring case.

N.B. All functions above return a matcher function. For example `lessThan(5)` returns a function that validates the input value is `< 5` at runtime.

## Comparator factories (for use with `anySorted`)

These return plain `(a, b) => number` comparator functions, not matcher functions.
Use them as the second argument to `anySorted`.

- `localeCompare(locale?, options?)` — locale-aware string comparator. `locale` is a BCP 47 language tag (e.g. `"fr-FR"`). `options` are passed directly to `Intl.Collator`.
- `compareByField(path, subComparator?)` — sort objects by the value at a dot-notation field path (e.g. `"profile.score"` or `"person.address.zip"`). Numeric fields sort numerically; all other types sort as strings. Optionally compose with another comparator (e.g. `localeCompare`) for the extracted value.

