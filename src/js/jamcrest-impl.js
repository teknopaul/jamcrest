var jamcrest = (function() {

    function deepEqual(input, matcher, path) {
        // Matcher functions are dispatched in Phase 5; plain values compared here.
        if (typeof matcher === 'function' && matcher.__jamcrest) {
            var ok = matcher(input);
            if (ok) return { match: true };
            var desc = matcher.describe || String(matcher);
            return {
                match: false,
                diagnostic: 'at ' + path + ': expected ' + desc +
                            ' got ' + typeof input + '(' + preview(input) + ')'
            };
        }

        // null
        if (matcher === null) {
            if (input === null) return { match: true };
            return { match: false, diagnostic: 'at ' + path + ': expected null got ' + preview(input) };
        }

        // NaN equality
        if (typeof matcher === 'number' && isNaN(matcher)) {
            if (typeof input === 'number' && isNaN(input)) return { match: true };
            return { match: false, diagnostic: 'at ' + path + ': expected NaN got ' + preview(input) };
        }

        // Primitives
        if (typeof matcher !== 'object') {
            if (input === matcher) return { match: true };
            return {
                match: false,
                diagnostic: 'at ' + path + ': expected ' + preview(matcher) + ' got ' + preview(input)
            };
        }

        // Array
        if (Array.isArray(matcher)) {
            // Single-matcher-applied-to-all rule (Phase 7)
            if (matcher.length === 1 && typeof matcher[0] === 'function' && matcher[0].__jamcrest) {
                if (!Array.isArray(input)) {
                    return { match: false, diagnostic: 'at ' + path + ': expected array got ' + typeof input };
                }
                for (var i = 0; i < input.length; i++) {
                    var r = deepEqual(input[i], matcher[0], path + '[' + i + ']');
                    if (!r.match) return r;
                }
                return { match: true };
            }
            if (!Array.isArray(input)) {
                return { match: false, diagnostic: 'at ' + path + ': expected array got ' + typeof input };
            }
            if (input.length !== matcher.length) {
                return {
                    match: false,
                    diagnostic: 'at ' + path + ': expected array length ' + matcher.length +
                                ' got ' + input.length
                };
            }
            for (var j = 0; j < matcher.length; j++) {
                var rj = deepEqual(input[j], matcher[j], path + '[' + j + ']');
                if (!rj.match) return rj;
            }
            return { match: true };
        }

        // Object
        if (typeof input !== 'object' || input === null || Array.isArray(input)) {
            return { match: false, diagnostic: 'at ' + path + ': expected object got ' + typeof input };
        }

        var matcherKeys = Object.keys(matcher);
        var inputKeys   = Object.keys(input);

        // Extra keys in input are a mismatch in strict mode (ignoreUnknown wired in compare())
        // We check here via a flag set on this call
        if (!deepEqual._ignoreUnknown) {
            for (var k = 0; k < inputKeys.length; k++) {
                if (!matcher.hasOwnProperty(inputKeys[k])) {
                    return {
                        match: false,
                        diagnostic: 'at ' + path + ': unexpected key "' + inputKeys[k] + '" in input'
                    };
                }
            }
        }

        for (var m = 0; m < matcherKeys.length; m++) {
            var key = matcherKeys[m];
            if (!input.hasOwnProperty(key)) {
                return {
                    match: false,
                    diagnostic: 'at ' + path + '.' + key + ': key missing in input'
                };
            }
            var rk = deepEqual(input[key], matcher[key], path + '.' + key);
            if (!rk.match) return rk;
        }
        return { match: true };
    }

    function preview(v) {
        if (v === null) return 'null';
        if (typeof v === 'string') return '"' + v.substring(0, 40) + '"';
        if (typeof v === 'object') return Array.isArray(v) ? '[array]' : '{object}';
        return String(v);
    }

    function compare(input, matcher, opts) {
        opts = opts || {};
        deepEqual._ignoreUnknown = !!(opts && opts.ignoreUnknown);
        return deepEqual(input, matcher, '$');
    }

    return { compare: compare };
})();
