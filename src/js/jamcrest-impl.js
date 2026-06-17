var jamcrest = (function() {

    var _opts = {};

    function _getOpts() { return _opts; }

    // Compound comparator built from an ordered list of field-name keys.
    // Objects missing a key sort before objects that have it.
    function _buildArraySortCmp(keys) {
        return function(a, b) {
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                var va = (a !== null && typeof a === 'object') ? a[k] : undefined;
                var vb = (b !== null && typeof b === 'object') ? b[k] : undefined;
                if (va === undefined && vb === undefined) continue;
                if (va === undefined) return -1;
                if (vb === undefined) return 1;
                var n = (typeof va === 'number' && typeof vb === 'number')
                    ? (va - vb)
                    : (String(va) < String(vb) ? -1 : String(va) > String(vb) ? 1 : 0);
                if (n !== 0) return n;
            }
            return 0;
        };
    }

    // Short summary of an expected (matcher-side) value — always shows content.
    function preview(v) {
        if (v === null) return 'null';
        if (v === undefined) return 'undefined';
        if (typeof v === 'string') {
            var s = JSON.stringify(v);
            return s.length > 60 ? s.substring(0, 57) + '..."' : s;
        }
        if (typeof v === 'object') {
            try {
                var j = JSON.stringify(v);
                return j.length > 60 ? j.substring(0, 57) + '...' : j;
            } catch (e) { return Array.isArray(v) ? '[array]' : '{object}'; }
        }
        return String(v);
    }

    // Describe the actual (input-side) value for a "got X" message.
    // Objects and arrays show only their type — never their content —
    // because in real payloads they can be arbitrarily large.
    function describeActual(v) {
        if (v === null) return 'null';
        if (v === undefined) return 'undefined';
        if (Array.isArray(v)) return 'array';
        if (typeof v === 'object') return 'object';
        return typeof v + '(' + preview(v) + ')';
    }

    // Accumulate all mismatches into `errors` array rather than stopping at first.
    function deepEqual(input, matcher, path, errors) {
        // Matcher function dispatch
        if (typeof matcher === 'function' && matcher.__jamcrest) {
            if (!matcher(input)) {
                var desc = matcher.describe || String(matcher);
                errors.push('at ' + path + ': expected ' + desc + ' got ' + describeActual(input));
            }
            return;
        }

        // null
        if (matcher === null) {
            if (input !== null)
                errors.push('at ' + path + ': expected null got ' + describeActual(input));
            return;
        }

        // NaN
        if (typeof matcher === 'number' && isNaN(matcher)) {
            if (typeof input !== 'number' || !isNaN(input))
                errors.push('at ' + path + ': expected NaN got ' + preview(input));
            return;
        }

        // Primitives
        if (typeof matcher !== 'object') {
            if (input !== matcher)
                errors.push('at ' + path + ': expected ' + preview(matcher) + ' got ' + describeActual(input));
            return;
        }

        // Array
        if (Array.isArray(matcher)) {
            // Single-matcher-applied-to-all rule
            if (matcher.length === 1 && typeof matcher[0] === 'function' && matcher[0].__jamcrest) {
                if (!Array.isArray(input)) {
                    errors.push('at ' + path + ': expected array got ' + describeActual(input));
                    return;
                }
                for (var i = 0; i < input.length; i++)
                    deepEqual(input[i], matcher[0], path + '[' + i + ']', errors);
                return;
            }
            if (!Array.isArray(input)) {
                errors.push('at ' + path + ': expected array got ' + describeActual(input));
                return;
            }
            var cmpInput = input;
            var cmpMatcher = matcher;
            var sortKeys = deepEqual._arraySortKeys;
            if (sortKeys && sortKeys.length > 0 && input.length > 0) {
                if (typeof matcher[0] === 'function') {
                    throw new Error('arraySortKeys cannot be combined with matcher functions in arrays at ' + path);
                }
                var firstElem = input[0];
                if (firstElem !== null && typeof firstElem === 'object' && !Array.isArray(firstElem)) {
                    var cmp = _buildArraySortCmp(sortKeys);
                    cmpInput = input.slice().sort(cmp);
                    cmpMatcher = matcher.slice().sort(cmp);
                }
            }
            if (cmpInput.length !== cmpMatcher.length) {
                errors.push('at ' + path + ': expected array length ' + cmpMatcher.length + ' got ' + cmpInput.length);
                // Still compare up to min length so element errors are visible too
            }
            var minLen = Math.min(cmpInput.length, cmpMatcher.length);
            for (var j = 0; j < minLen; j++)
                deepEqual(cmpInput[j], cmpMatcher[j], path + '[' + j + ']', errors);
            return;
        }

        // Object
        if (typeof input !== 'object' || input === null || Array.isArray(input)) {
            errors.push('at ' + path + ': expected object got ' + describeActual(input));
            return;
        }

        var matcherKeys = Object.keys(matcher);
        var inputKeys   = Object.keys(input);

        if (!deepEqual._ignoreUnknown) {
            for (var k = 0; k < inputKeys.length; k++) {
                if (!matcher.hasOwnProperty(inputKeys[k]))
                    errors.push('at ' + path + ': unexpected key "' + inputKeys[k] + '" in input');
            }
        }

        for (var m = 0; m < matcherKeys.length; m++) {
            var key = matcherKeys[m];
            if (!input.hasOwnProperty(key)) {
                errors.push('at ' + path + '.' + key + ': key missing in input' +
                            ' (expected ' + preview(matcher[key]) + ')');
            } else {
                deepEqual(input[key], matcher[key], path + '.' + key, errors);
            }
        }
    }

    function compare(input, matcher, opts) {
        opts = opts || {};
        _opts = opts;
        deepEqual._ignoreUnknown = !!(opts && opts.ignoreUnknown);
        deepEqual._arraySortKeys = (opts.arraySortKeys && opts.arraySortKeys.length) ? opts.arraySortKeys : null;
        var errors = [];
        deepEqual(input, matcher, '$', errors);
        if (errors.length === 0) return { match: true };
        return { match: false, diagnostic: errors.join('\n') };
    }

    return { compare: compare, _getOpts: _getOpts };
})();
