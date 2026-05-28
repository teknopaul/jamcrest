var jamcrest = (function() {

    // Produce a short human-readable summary of a value.
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

    // Accumulate all mismatches into `errors` array rather than stopping at first.
    function deepEqual(input, matcher, path, errors) {
        // Matcher function dispatch
        if (typeof matcher === 'function' && matcher.__jamcrest) {
            if (!matcher(input)) {
                var desc = matcher.describe || String(matcher);
                errors.push('at ' + path + ': expected ' + desc +
                            ' got ' + typeof input + '(' + preview(input) + ')');
            }
            return;
        }

        // null
        if (matcher === null) {
            if (input !== null)
                errors.push('at ' + path + ': expected null got ' + preview(input));
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
                errors.push('at ' + path + ': expected ' + preview(matcher) + ' got ' + preview(input));
            return;
        }

        // Array
        if (Array.isArray(matcher)) {
            // Single-matcher-applied-to-all rule
            if (matcher.length === 1 && typeof matcher[0] === 'function' && matcher[0].__jamcrest) {
                if (!Array.isArray(input)) {
                    errors.push('at ' + path + ': expected array got ' + typeof input + '(' + preview(input) + ')');
                    return;
                }
                for (var i = 0; i < input.length; i++)
                    deepEqual(input[i], matcher[0], path + '[' + i + ']', errors);
                return;
            }
            if (!Array.isArray(input)) {
                errors.push('at ' + path + ': expected array got ' + typeof input + '(' + preview(input) + ')');
                return;
            }
            if (input.length !== matcher.length) {
                errors.push('at ' + path + ': expected array length ' + matcher.length + ' got ' + input.length);
                // Still compare up to min length so element errors are visible too
            }
            var minLen = Math.min(input.length, matcher.length);
            for (var j = 0; j < minLen; j++)
                deepEqual(input[j], matcher[j], path + '[' + j + ']', errors);
            return;
        }

        // Object
        if (typeof input !== 'object' || input === null || Array.isArray(input)) {
            errors.push('at ' + path + ': expected object got ' + typeof input + '(' + preview(input) + ')');
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
        deepEqual._ignoreUnknown = !!(opts && opts.ignoreUnknown);
        var errors = [];
        deepEqual(input, matcher, '$', errors);
        if (errors.length === 0) return { match: true };
        return { match: false, diagnostic: errors.join('\n') };
    }

    return { compare: compare };
})();
