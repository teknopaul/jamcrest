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
