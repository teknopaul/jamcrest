# Jamcrest 

`jamcrest` is a tool for validating JavaScript objects with an API similar to Hamcrest, the Java matchers API.

The tool is passed a JavaScript object to validate and another JavaScript object that it should use to match.

JavaScript input will be a JSON strings, the matcher need not be.

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
{
  name : "Alice",
  id : 1234
}
```

Will pass.  N.B. this matcher could be a JSON object.

When it is not a requirement that an object be _exactly_ identical a Hamcrest style matcher can be provided instead.

```js
{
  name : "Alice",
  id : anyNumber()
}
```
N.B. this matcher could _not_ be a JSON object.


## Matching operation

Cli code is written in C++ and the internal JavaScript library is `v8`.
The input JSON is converted to JavaScript.

The two JSON oject's attriburtes to be compared are iterated through ensuring that the input Object matches the matcher Object.

If an attribute is in the input that is not in the matcher JavaScript it is ignored (set --ingnore-unknown or --ignore-properties).
If an array has a single matcher that is a matcher function, it is applied to all elements in the array.
In order to compare arrays that may come in the input in a different order the array may be sorted first,

```js  
fruit: anySorted(["apples", "bananas", "cantaloupes"], comparator) //  N.B both the input and the test array are sorted with comparator at runtime.
```

`anySorted` accepts any `(a, b) => number` comparator. Jamcrest provides built-in comparator factories:

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

N.B. Flags based on Jackson validator API (although Jackson is not involved)

# Command line interface

```bash
curl http://someapi/ | jamcrest --matcher ./api-matcher.js
```

The matchers are based on the https://hamcrest.org API, but are not identical as they are not implemented in Java.

Hamcrest matchers supported by Jamcrest.  (implemented in `src/js/jamcrest-matchers.js`)

- aMapWithSize()
- anEmptyMap()
- any()
  - any + JavaScript types anyBoolean(), anyString(), anyArray(), anyObject(), anyNumber()
- anyOf()
- anything()
- arrayContaining()
- arrayContainingInAnyOrder()
- arrayWithSize()
- blankOrNull()
- closeTo(double operand, double error)
- containsString()
- either()
- empty()
- emptyArray()
- emptyString()
- endsWith()
- equalToIgnoringCase()
- greaterThan()
- greaterThanOrEqualTo()
- hasKey()
- hasLength()
- hasProperty()
- in()
- isA()
- lessThan()
- matchesPattern() matchesRegex()
- not()
- notANumber()
- notNullValue()
- startsWith()
- startsWithIgnoringCase()

N.B. all the JavaScript implementations of the functions above returns a function that actually implements the matcher.
for example `lessThan(5)`  returns a function that validates that input value is `< 5` at runtime.

## Comparator factories (for use with `anySorted`)

These return plain `(a, b) => number` comparator functions, not matcher functions.
Use them as the second argument to `anySorted`.

- `localeCompare(locale?, options?)` — locale-aware string comparator. `locale` is a BCP 47 language tag (e.g. `"fr-FR"`). `options` are passed directly to `Intl.Collator`.
- `compareByField(path, subComparator?)` — sort objects by the value at a dot-notation field path (e.g. `"profile.score"` or `"person.address.zip"`). Numeric fields sort numerically; all other types sort as strings. Optionally compose with another comparator (e.g. `localeCompare`) for the extracted value.

