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
}
