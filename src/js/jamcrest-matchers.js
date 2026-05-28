// Matcher factories for jamcrest. All factories return tagged functions.
// Tag: fn.__jamcrest = true, fn.describe = "<description>"

function _make(describe, test) {
    var fn = function(v) { return test(v); };
    fn.__jamcrest = true;
    fn.describe = describe;
    return fn;
}

// ---- Type matchers (Phase 5) ----

function any() {
    return _make('any()', function(v) { return v !== undefined && v !== null; });
}

function anything() {
    return _make('anything()', function() { return true; });
}

function anyBoolean() {
    return _make('anyBoolean()', function(v) { return typeof v === 'boolean'; });
}

function anyString() {
    return _make('anyString()', function(v) { return typeof v === 'string'; });
}

function anyNumber() {
    return _make('anyNumber()', function(v) { return typeof v === 'number' && !isNaN(v); });
}

function anyArray() {
    return _make('anyArray()', function(v) { return Array.isArray(v); });
}

function anyObject() {
    return _make('anyObject()', function(v) {
        return typeof v === 'object' && v !== null && !Array.isArray(v);
    });
}

function isA(typeName) {
    return _make('isA(' + typeName + ')', function(v) {
        if (typeName === 'array')   return Array.isArray(v);
        if (typeName === 'null')    return v === null;
        return typeof v === typeName;
    });
}

function notANumber() {
    return _make('notANumber()', function(v) { return typeof v === 'number' && isNaN(v); });
}

function notNullValue() {
    return _make('notNullValue()', function(v) { return v !== null && v !== undefined; });
}

function blankOrNull() {
    return _make('blankOrNull()', function(v) {
        return v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
    });
}

// ---- Comparison matchers (Phase 6) ----

function equalTo(expected) {
    return _make('equalTo(' + expected + ')', function(v) { return v === expected; });
}

function greaterThan(n) {
    return _make('greaterThan(' + n + ')', function(v) { return typeof v === 'number' && v > n; });
}

function greaterThanOrEqualTo(n) {
    return _make('greaterThanOrEqualTo(' + n + ')', function(v) { return typeof v === 'number' && v >= n; });
}

function lessThan(n) {
    return _make('lessThan(' + n + ')', function(v) { return typeof v === 'number' && v < n; });
}

function lessThanOrEqualTo(n) {
    return _make('lessThanOrEqualTo(' + n + ')', function(v) { return typeof v === 'number' && v <= n; });
}

function closeTo(operand, error) {
    return _make('closeTo(' + operand + ', ' + error + ')', function(v) {
        return typeof v === 'number' && Math.abs(v - operand) <= error;
    });
}

function equalToIgnoringCase(s) {
    return _make('equalToIgnoringCase(' + s + ')', function(v) {
        return typeof v === 'string' && v.toLowerCase() === s.toLowerCase();
    });
}

// ---- String matchers (Phase 6) ----

function containsString(s) {
    return _make('containsString(' + s + ')', function(v) {
        return typeof v === 'string' && v.indexOf(s) !== -1;
    });
}

function startsWith(s) {
    return _make('startsWith(' + s + ')', function(v) {
        return typeof v === 'string' && v.indexOf(s) === 0;
    });
}

function endsWith(s) {
    return _make('endsWith(' + s + ')', function(v) {
        return typeof v === 'string' && v.slice(-s.length) === s;
    });
}

function startsWithIgnoringCase(s) {
    return _make('startsWithIgnoringCase(' + s + ')', function(v) {
        return typeof v === 'string' && v.toLowerCase().indexOf(s.toLowerCase()) === 0;
    });
}

function emptyString() {
    return _make('emptyString()', function(v) { return v === ''; });
}

function hasLength(n) {
    return _make('hasLength(' + n + ')', function(v) {
        return (typeof v === 'string' || Array.isArray(v)) && v.length === n;
    });
}

function matchesPattern(re) {
    var regex = (re instanceof RegExp) ? re : new RegExp(re);
    return _make('matchesPattern(' + regex + ')', function(v) {
        return typeof v === 'string' && regex.test(v);
    });
}

// Alias
var matchesRegex = matchesPattern;

// ---- Collection / array matchers (Phase 7) ----

function empty() {
    return _make('empty()', function(v) {
        if (typeof v === 'string') return v.length === 0;
        if (Array.isArray(v)) return v.length === 0;
        if (typeof v === 'object' && v !== null) return Object.keys(v).length === 0;
        return false;
    });
}

function emptyArray() {
    return _make('emptyArray()', function(v) { return Array.isArray(v) && v.length === 0; });
}

function arrayWithSize(n) {
    return _make('arrayWithSize(' + n + ')', function(v) { return Array.isArray(v) && v.length === n; });
}

function arrayContaining() {
    var expected = Array.prototype.slice.call(arguments);
    return _make('arrayContaining(' + expected + ')', function(v) {
        if (!Array.isArray(v)) return false;
        for (var i = 0; i < expected.length; i++) {
            var exp = expected[i];
            var found = false;
            for (var j = 0; j < v.length; j++) {
                var match = _matchValue(v[j], exp);
                if (match) { found = true; break; }
            }
            if (!found) return false;
        }
        return true;
    });
}

function arrayContainingInAnyOrder() {
    var expected = Array.prototype.slice.call(arguments);
    return _make('arrayContainingInAnyOrder', function(v) {
        if (!Array.isArray(v)) return false;
        var remaining = v.slice();
        for (var i = 0; i < expected.length; i++) {
            var exp = expected[i];
            var foundIdx = -1;
            for (var j = 0; j < remaining.length; j++) {
                if (_matchValue(remaining[j], exp)) { foundIdx = j; break; }
            }
            if (foundIdx === -1) return false;
            remaining.splice(foundIdx, 1);
        }
        return true;
    });
}

// Sort copies of both arrays with cmp, then element-wise compare (matchers allowed in expected).
function anySorted(expected, cmp) {
    return _make('anySorted', function(v) {
        if (!Array.isArray(v)) return false;
        var sortedInput    = v.slice().sort(cmp);
        var sortedExpected = expected.slice().sort(cmp);
        if (sortedInput.length !== sortedExpected.length) return false;
        for (var i = 0; i < sortedExpected.length; i++) {
            if (!_matchValue(sortedInput[i], sortedExpected[i])) return false;
        }
        return true;
    });
}

// Internal helper: match a single value against a matcher-or-literal
function _matchValue(input, matcher) {
    if (typeof matcher === 'function' && matcher.__jamcrest) {
        return !!matcher(input);
    }
    if (matcher === null) return input === null;
    if (typeof matcher === 'number' && isNaN(matcher)) return typeof input === 'number' && isNaN(input);
    if (typeof matcher !== 'object') return input === matcher;
    // Deep structural match delegated back to jamcrest.compare
    var r = jamcrest.compare(input, matcher, {});
    return r.match;
}
