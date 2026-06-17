package io.github.teknopaul.jamcrest;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Value;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Jamcrest JSON matcher backed by GraalVM JS.
 *
 * <p>Embeds the same JavaScript matchers as the C++ jamcrest binary.
 * Each instance holds a GraalVM JS context with the matcher library pre-loaded;
 * close it when done.
 *
 * <p>Instance usage (efficient for repeated calls):
 * <pre>{@code
 *   try (Jamcrest jmc = new Jamcrest()) {
 *       Result r = jmc.compare(jsonInput, matcherJs);
 *   }
 * }</pre>
 *
 * <p>One-shot static usage:
 * <pre>{@code
 *   Result r = Jamcrest.match(jsonInput, matcherJs);
 * }</pre>
 *
 * <p>Not thread-safe. Use one instance per thread or synchronize externally.
 */
public class Jamcrest implements AutoCloseable {

    /** Outcome of a match operation. {@code diagnostic} is null on success. */
    public record Result(boolean match, String diagnostic) {}

    private static final String[] JS_RESOURCES = {
        "/js/jamcrest-matchers.js",
        "/js/jamcrest-impl.js",
        "/js/jamcrest-bootstrap.js"
    };

    private final Context ctx;
    private List<String> arraySortKeys = List.of();

    /**
     * Sets the field names used to auto-sort object arrays before comparison.
     * Keys are applied in priority order: first key is primary sort, subsequent keys break ties.
     * Objects missing a key sort before objects that have it.
     *
     * <p>This option is intended for use when matchers are auto-generated and array order is
     * non-deterministic.  It is incompatible with jamcrest matcher functions inside arrays —
     * combining both is a user error and will cause a runtime exception.
     *
     * @param keys field names to sort by, in priority order
     * @return {@code this} for fluent chaining
     */
    public Jamcrest withArraySortKeys(String... keys) {
        this.arraySortKeys = keys == null ? List.of() : List.of(keys);
        return this;
    }

    /** Creates a new instance, loading the embedded JS matcher library into a fresh GraalVM context. */
    public Jamcrest() {
        ctx = Context.newBuilder("js")
                .allowAllAccess(false)
                .build();
        try {
            for (String resource : JS_RESOURCES) {
                ctx.eval("js", loadResource(resource));
            }
        } catch (IOException e) {
            ctx.close();
            throw new RuntimeException("Failed to load embedded JS resources", e);
        }
    }

    /**
     * Match {@code jsonInput} against {@code matcherJs}.
     *
     * @param jsonInput  the JSON to test, as a string
     * @param matcherJs  the matcher expression (same syntax as C++ --matcher files)
     * @return a {@link Result} with {@code match=true} on success, or {@code diagnostic} text on failure
     * @throws IllegalArgumentException if {@code jsonInput} is not valid JSON
     */
    public Result compare(String jsonInput, String matcherJs) {
        return compare(jsonInput, matcherJs, false);
    }

    /**
     * Match {@code jsonInput} against {@code matcherJs}.
     *
     * @param jsonInput      the JSON to test, as a string
     * @param matcherJs      the matcher expression
     * @param ignoreUnknown  when true, extra keys in the input JSON are not reported as mismatches
     * @return a {@link Result}
     * @throws IllegalArgumentException if {@code jsonInput} is not valid JSON
     */
    public Result compare(String jsonInput, String matcherJs, boolean ignoreUnknown) {
        // Validate and parse JSON input into a live JS value
        Value parsed;
        try {
            parsed = ctx.eval("js", "JSON.parse(" + jsStringLiteral(jsonInput) + ")");
        } catch (PolyglotException e) {
            throw new IllegalArgumentException("invalid JSON: " + e.getMessage(), e);
        }

        // Strip trailing whitespace and semicolons, mirroring C++ find_last_not_of(" \t\r\n;")
        String stripped = stripMatcherTrailing(matcherJs);

        // Evaluate matcher expression into globalThis.__matcher
        try {
            ctx.eval("js", "globalThis.__matcher = (" + stripped + ");");
        } catch (PolyglotException e) {
            throw new IllegalArgumentException("invalid matcher JS: " + e.getMessage(), e);
        }

        // Expose parsed JSON value as a JS binding so it passes through as a native JS object
        ctx.getBindings("js").putMember("__input", parsed);

        String optsJson = buildOptsJson(ignoreUnknown);
        Value result = ctx.eval("js",
                "jamcrest.compare(__input, globalThis.__matcher, " + optsJson + ")");

        boolean match = result.getMember("match").asBoolean();
        Value diagVal = result.getMember("diagnostic");
        String diagnostic = (diagVal == null || diagVal.isNull()) ? null : diagVal.asString();

        return new Result(match, diagnostic);
    }

    /**
     * Match {@code jsonInput} against {@code matcherJs} with named variables injected into the
     * global JS context before matching.
     *
     * <p>{@code contextArgs} must be an even-length sequence of alternating {@code String} names
     * and Java primitive wrapper values ({@code Boolean}, {@code Integer}, {@code Long},
     * {@code Double}, {@code String}).  Each pair sets {@code globalThis[name] = value} in the
     * JS context before the matcher runs, so the matcher template may reference the names directly.
     *
     * <pre>{@code
     *   jmc.compare(json, "({age: greaterThan(minAge)})", true, "minAge", 18);
     * }</pre>
     *
     * @param jsonInput      the JSON to test
     * @param matcherJs      the matcher expression
     * @param ignoreUnknown  when true, extra keys in the input are not reported as mismatches
     * @param contextArgs    interleaved name/value pairs to inject into the JS global context
     * @return a {@link Result}
     * @throws IllegalArgumentException if contextArgs are malformed or contain unsupported types
     */
    public Result compare(String jsonInput, String matcherJs, boolean ignoreUnknown, Object... contextArgs) {
        if (contextArgs.length % 2 != 0) {
            throw new IllegalArgumentException("contextArgs must be an even number of name/value pairs");
        }
        Value bindings = ctx.getBindings("js");
        for (int i = 0; i < contextArgs.length; i += 2) {
            if (!(contextArgs[i] instanceof String name)) {
                throw new IllegalArgumentException(
                    "contextArgs[" + i + "] must be a String name, got: " +
                    (contextArgs[i] == null ? "null" : contextArgs[i].getClass().getName()));
            }
            Object val = contextArgs[i + 1];
            if (val instanceof Boolean || val instanceof Integer || val instanceof Long ||
                val instanceof Double || val instanceof Float || val instanceof String) {
                bindings.putMember(name, val);
            } else {
                throw new IllegalArgumentException(
                    "contextArgs[" + (i + 1) + "] for \"" + name + "\": unsupported type " +
                    (val == null ? "null" : val.getClass().getName()) +
                    " — only String and primitive wrappers (Boolean, Integer, Long, Double) are allowed");
            }
        }
        return compare(jsonInput, matcherJs, ignoreUnknown);
    }

    /**
     * Evaluates {@code jsObjectExpr} as a JS object and copies all its enumerable own properties
     * into {@code globalThis}.  Equivalent to the CLI {@code --args=EXPR} flag.
     *
     * <p>Useful for injecting non-string values (booleans, numbers, nested objects) into the
     * global context before calling {@link #compare}.  Call as many times as needed; properties
     * accumulate.
     *
     * <pre>{@code
     *   jmc.putGlobalsFromJs("{minAge: 18, active: true}");
     *   jmc.compare(json, "({age: greaterThan(minAge), active: active})", false);
     * }</pre>
     *
     * @param jsObjectExpr a JS expression that evaluates to an object
     * @throws IllegalArgumentException if the expression is not valid JS or does not yield an object
     */
    public void putGlobalsFromJs(String jsObjectExpr) {
        try {
            ctx.eval("js",
                "(function(__o){for(var __k in __o)globalThis[__k]=__o[__k];})(" + jsObjectExpr + ");");
        } catch (PolyglotException e) {
            throw new IllegalArgumentException("invalid --args expression: " + e.getMessage(), e);
        }
    }

    @Override
    public void close() {
        ctx.close();
    }

    // --- Static convenience methods ---

    /**
     * One-shot match: creates a context, runs the comparison, and closes the context.
     * Use the instance API for repeated calls.
     *
     * @param jsonInput the JSON to test, as a string
     * @param matcherJs the matcher expression
     * @return a {@link Result}
     */
    public static Result match(String jsonInput, String matcherJs) {
        try (Jamcrest jmc = new Jamcrest()) {
            return jmc.compare(jsonInput, matcherJs);
        }
    }

    /**
     * One-shot match with the {@code ignoreUnknown} flag.
     *
     * @param jsonInput      the JSON to test, as a string
     * @param matcherJs      the matcher expression
     * @param ignoreUnknown  when true, extra keys in the input are not reported as mismatches
     * @return a {@link Result}
     */
    public static Result match(String jsonInput, String matcherJs, boolean ignoreUnknown) {
        try (Jamcrest jmc = new Jamcrest()) {
            return jmc.compare(jsonInput, matcherJs, ignoreUnknown);
        }
    }

    /**
     * One-shot match with global context variables.
     *
     * @param jsonInput      the JSON to test, as a string
     * @param matcherJs      the matcher expression
     * @param ignoreUnknown  when true, extra keys in the input are not reported as mismatches
     * @param contextArgs    interleaved name/value pairs injected into the JS global context
     * @return a {@link Result}
     */
    public static Result match(String jsonInput, String matcherJs, boolean ignoreUnknown, Object... contextArgs) {
        try (Jamcrest jmc = new Jamcrest()) {
            return jmc.compare(jsonInput, matcherJs, ignoreUnknown, contextArgs);
        }
    }

    // --- Helpers ---

    /**
     * Mirrors C++ {@code find_last_not_of(" \t\r\n;")} — strips any trailing mix of
     * whitespace and semicolons so {@code matcher = {...};} is accepted like {@code ({...})}.
     */
    private static String stripMatcherTrailing(String s) {
        int end = s.length() - 1;
        while (end >= 0) {
            char c = s.charAt(end);
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ';') {
                end--;
            } else {
                break;
            }
        }
        return end < 0 ? "" : s.substring(0, end + 1);
    }

    private String buildOptsJson(boolean ignoreUnknown) {
        StringBuilder sb = new StringBuilder("{\"ignoreUnknown\":").append(ignoreUnknown);
        sb.append(",\"arraySortKeys\":[");
        for (int i = 0; i < arraySortKeys.size(); i++) {
            if (i > 0) sb.append(',');
            sb.append(jsStringLiteral(arraySortKeys.get(i)));
        }
        sb.append("]}");
        return sb.toString();
    }

    /** Encodes a Java string as a JS string literal, escaping the minimum required characters. */
    private static String jsStringLiteral(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\' -> sb.append("\\\\");
                case '"'  -> sb.append("\\\"");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\0' -> sb.append("\\u0000");
                default   -> sb.append(c);
            }
        }
        sb.append('"');
        return sb.toString();
    }

    private static String loadResource(String path) throws IOException {
        try (InputStream is = Jamcrest.class.getResourceAsStream(path)) {
            if (is == null) throw new IOException("Embedded resource not found: " + path);
            return new String(is.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
