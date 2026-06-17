package io.github.teknopaul.jamcrest;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class JamcrestTest {

    @Test
    void primitiveEqualityMatch() {
        var r = Jamcrest.match("{\"a\":1}", "({a: 1})");
        assertTrue(r.match());
        assertNull(r.diagnostic());
    }

    @Test
    void primitiveEqualityMismatch() {
        var r = Jamcrest.match("{\"a\":2}", "({a: 1})");
        assertFalse(r.match());
        assertNotNull(r.diagnostic());
        assertTrue(r.diagnostic().contains("$.a"));
    }

    @Test
    void anyStringMatcher() {
        var r = Jamcrest.match("{\"name\":\"Alice\"}", "({name: anyString()})");
        assertTrue(r.match());
    }

    @Test
    void greaterThanMatcher() {
        var r = Jamcrest.match("{\"age\":30}", "({age: greaterThan(18)})");
        assertTrue(r.match());
    }

    @Test
    void greaterThanMatcherFail() {
        var r = Jamcrest.match("{\"age\":10}", "({age: greaterThan(18)})");
        assertFalse(r.match());
        assertTrue(r.diagnostic().contains("greaterThan(18)"));
    }

    @Test
    void nestedObject() {
        var r = Jamcrest.match(
            "{\"user\":{\"name\":\"Bob\",\"active\":true}}",
            "({user: {name: anyString(), active: true}})"
        );
        assertTrue(r.match());
    }

    @Test
    void arrayMatcher() {
        var r = Jamcrest.match("[1,2,3]", "([1, 2, 3])");
        assertTrue(r.match());
    }

    @Test
    void arrayContainingMatcher() {
        // arrayContaining as root matcher checks the whole array, not element-by-element
        var r = Jamcrest.match("[1,2,3,4]", "arrayContaining(2, 4)");
        assertTrue(r.match());
    }

    @Test
    void ignoreUnknownFlag() {
        try (var jmc = new Jamcrest()) {
            var r = jmc.compare("{\"a\":1,\"extra\":\"ignored\"}", "({a: 1})", true);
            assertTrue(r.match());
        }
    }

    @Test
    void unknownKeyReportedByDefault() {
        var r = Jamcrest.match("{\"a\":1,\"extra\":\"x\"}", "({a: 1})");
        assertFalse(r.match());
        assertTrue(r.diagnostic().contains("extra"));
    }

    @Test
    void containsStringMatcher() {
        var r = Jamcrest.match("{\"msg\":\"hello world\"}", "({msg: containsString(\"hello\")})");
        assertTrue(r.match());
    }

    @Test
    void notMatcher() {
        var r = Jamcrest.match("{\"v\":5}", "({v: not(greaterThan(10))})");
        assertTrue(r.match());
    }

    @Test
    void multipleErrorsAccumulated() {
        var r = Jamcrest.match("{\"a\":1,\"b\":2}", "({a: 9, b: 9})");
        assertFalse(r.match());
        // Both mismatches should appear in the diagnostic
        assertTrue(r.diagnostic().contains("$.a"));
        assertTrue(r.diagnostic().contains("$.b"));
    }

    @Test
    void trailingSemicolonInMatcher() {
        // The C++ version strips trailing semicolons; Java should too
        var r = Jamcrest.match("{\"x\":1}", "({x: 1});");
        assertTrue(r.match());
    }

    @Test
    void invalidJsonThrows() {
        assertThrows(IllegalArgumentException.class, () ->
            Jamcrest.match("not-valid-json", "({})"));
    }

    @Test
    void instanceReuse() {
        try (var jmc = new Jamcrest()) {
            assertTrue(jmc.compare("{\"n\":1}", "({n: 1})").match());
            assertFalse(jmc.compare("{\"n\":2}", "({n: 1})").match());
            assertTrue(jmc.compare("{\"n\":3}", "({n: greaterThan(2)})").match());
        }
    }

    // --- allOf ---

    @Test
    void allOfMatches() {
        // allOf applied to a field value — classic range check
        var r = Jamcrest.match("{\"age\":25}", "({age: allOf(greaterThan(18), lessThan(30))})");
        assertTrue(r.match());
    }

    @Test
    void allOfFailsWhenOneMatcherFails() {
        var r = Jamcrest.match("{\"age\":35}", "({age: allOf(greaterThan(18), lessThan(30))})");
        assertFalse(r.match());
    }

    @Test
    void allOfWithStringMatchers() {
        var r = Jamcrest.match(
            "{\"tag\":\"hello-world\"}",
            "({tag: allOf(startsWith(\"hello\"), endsWith(\"world\"))})"
        );
        assertTrue(r.match());
    }

    // --- contextArgs / global variable injection ---

    @Test
    void varStringInjected() {
        var r = Jamcrest.match("{\"name\":\"Alice\"}", "({name: expectedName})", false, "expectedName", "Alice");
        assertTrue(r.match());
    }

    @Test
    void varStringMismatch() {
        var r = Jamcrest.match("{\"name\":\"Bob\"}", "({name: expectedName})", false, "expectedName", "Alice");
        assertFalse(r.match());
    }

    @Test
    void varBooleanInjected() {
        var r = Jamcrest.match("{\"active\":true}", "({active: isActive})", false, "isActive", true);
        assertTrue(r.match());
    }

    @Test
    void varIntegerInjected() {
        var r = Jamcrest.match("{\"age\":30}", "({age: greaterThan(minAge)})", false, "minAge", 18);
        assertTrue(r.match());
    }

    @Test
    void varDoubleInjected() {
        var r = Jamcrest.match("{\"score\":9.5}", "({score: greaterThan(minScore)})", false, "minScore", 9.0);
        assertTrue(r.match());
    }

    @Test
    void multipleVarsInjected() {
        var r = Jamcrest.match(
            "{\"name\":\"Alice\",\"age\":30}",
            "({name: expectedName, age: greaterThan(minAge)})",
            false, "expectedName", "Alice", "minAge", 18);
        assertTrue(r.match());
    }

    @Test
    void oddContextArgCountThrows() {
        assertThrows(IllegalArgumentException.class, () ->
            Jamcrest.match("{\"a\":1}", "({a:1})", false, "onlyName"));
    }

    @Test
    void nonStringNameThrows() {
        assertThrows(IllegalArgumentException.class, () ->
            Jamcrest.match("{\"a\":1}", "({a:1})", false, 42, "value"));
    }

    @Test
    void putGlobalsFromJsBoolean() {
        try (var jmc = new Jamcrest()) {
            jmc.putGlobalsFromJs("{isActive: true, minAge: 18}");
            var r = jmc.compare("{\"active\":true,\"age\":25}", "({active: isActive, age: greaterThan(minAge)})", false);
            assertTrue(r.match());
        }
    }

    @Test
    void putGlobalsFromJsString() {
        try (var jmc = new Jamcrest()) {
            jmc.putGlobalsFromJs("{expectedName: \"Alice\"}");
            var r = jmc.compare("{\"name\":\"Alice\"}", "({name: expectedName})", false);
            assertTrue(r.match());
        }
    }

    @Test
    void putGlobalsFromJsInvalidExprThrows() {
        try (var jmc = new Jamcrest()) {
            assertThrows(IllegalArgumentException.class, () ->
                jmc.putGlobalsFromJs("this is not valid js !!!"));
        }
    }

    // --- arraySortKeys ---

    @Test
    void arraySortKeysSortsObjectArrayBeforeComparison() {
        // Input has objects in a different order than the matcher; sort by "id" aligns them.
        try (var jmc = new Jamcrest().withArraySortKeys("id")) {
            var r = jmc.compare(
                "[{\"id\":2,\"name\":\"Bob\"},{\"id\":1,\"name\":\"Alice\"}]",
                "([{id:1,name:\"Alice\"},{id:2,name:\"Bob\"}])",
                false);
            assertTrue(r.match(), r.diagnostic());
        }
    }

    @Test
    void arraySortKeysMultiKeyTieBreaker() {
        // Primary key "game" ties; secondary key "name" breaks it.
        try (var jmc = new Jamcrest().withArraySortKeys("game", "name")) {
            var r = jmc.compare(
                "[{\"game\":\"chess\",\"name\":\"Zara\"},{\"game\":\"chess\",\"name\":\"Alice\"}]",
                "([{game:\"chess\",name:\"Alice\"},{game:\"chess\",name:\"Zara\"}])",
                false);
            assertTrue(r.match(), r.diagnostic());
        }
    }

    @Test
    void arraySortKeysDoesNotSortPrimitiveArrays() {
        // Arrays of primitives should not be sorted; order mismatch should fail.
        try (var jmc = new Jamcrest().withArraySortKeys("id")) {
            var r = jmc.compare("[2,1,3]", "([1,2,3])", false);
            assertFalse(r.match());
        }
    }

    @Test
    void arraySortKeysNestedArray() {
        // Sort keys apply to arrays nested inside objects too.
        try (var jmc = new Jamcrest().withArraySortKeys("id")) {
            var r = jmc.compare(
                "{\"items\":[{\"id\":3},{\"id\":1},{\"id\":2}]}",
                "({items:[{id:1},{id:2},{id:3}]})",
                false);
            assertTrue(r.match(), r.diagnostic());
        }
    }

    @Test
    void arraySortKeysWithoutFlagOrderMatters() {
        // Without the flag, order is significant and this should fail.
        var r = Jamcrest.match(
            "[{\"id\":2},{\"id\":1}]",
            "([{id:1},{id:2}])");
        assertFalse(r.match());
    }
}
