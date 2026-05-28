package io.github.teknopaul.jamcrest;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Value;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

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

    public record Result(boolean match, String diagnostic) {}

    private static final String[] JS_RESOURCES = {
        "/js/jamcrest-matchers.js",
        "/js/jamcrest-impl.js",
        "/js/jamcrest-bootstrap.js"
    };

    private final Context ctx;

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

        String optsJson = "{\"ignoreUnknown\":" + ignoreUnknown + "}";
        Value result = ctx.eval("js",
                "jamcrest.compare(__input, globalThis.__matcher, " + optsJson + ")");

        boolean match = result.getMember("match").asBoolean();
        Value diagVal = result.getMember("diagnostic");
        String diagnostic = (diagVal == null || diagVal.isNull()) ? null : diagVal.asString();

        return new Result(match, diagnostic);
    }

    @Override
    public void close() {
        ctx.close();
    }

    // --- Static convenience methods ---

    public static Result match(String jsonInput, String matcherJs) {
        try (Jamcrest jmc = new Jamcrest()) {
            return jmc.compare(jsonInput, matcherJs);
        }
    }

    public static Result match(String jsonInput, String matcherJs, boolean ignoreUnknown) {
        try (Jamcrest jmc = new Jamcrest()) {
            return jmc.compare(jsonInput, matcherJs, ignoreUnknown);
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
