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
