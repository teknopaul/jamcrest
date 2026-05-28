package io.github.teknopaul.jamcrest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * CLI entry point: reads JSON from stdin and matcher JS from a file or the second argument.
 *
 * <pre>
 * java -jar jamcrest.jar --matcher PATH [--ignore-unknown] [--quiet]
 * java -jar jamcrest.jar JSON MATCHER_JS
 * </pre>
 *
 * <p>Exit codes: 0 = match, 1 = no-match, 2 = error
 */
public class JamcrestCli {

    /** Runs the CLI. */
    public static void main(String[] args) throws IOException {
        // Two-argument inline form: java -jar jamcrest.jar '<json>' '<matcherJs>'
        if (args.length == 2 && !args[0].startsWith("--")) {
            run(args[0], args[1], false, false);
            return;
        }

        // Flag-based form matching the C++ CLI interface
        String matcherPath = null;
        boolean ignoreUnknown = false;
        boolean quiet = false;
        boolean help = false;
        boolean version = false;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--help"             -> help = true;
                case "--version"          -> version = true;
                case "--ignore-unknown",
                     "--ignore-properties" -> ignoreUnknown = true;
                case "--quiet"            -> quiet = true;
                case "--matcher" -> {
                    if (i + 1 >= args.length) {
                        System.err.println("jamcrest: --matcher requires a path argument");
                        System.exit(2);
                    }
                    matcherPath = args[++i];
                }
                default -> {
                    System.err.println("jamcrest: unknown flag: " + args[i]);
                    System.err.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]");
                    System.exit(2);
                }
            }
        }

        if (version) { System.out.println("jamcrest 0.1.0"); return; }
        if (help) {
            System.out.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]");
            System.out.println("       Reads JSON from stdin, matches against matcher JS file.");
            System.out.println("       Exit: 0=match  1=no-match  2=error");
            System.out.println();
            System.out.println("       jamcrest '<json>' '<matcherJs>'");
            System.out.println("       Inline form — both inputs as string arguments.");
            return;
        }
        if (matcherPath == null) {
            System.err.println("jamcrest: --matcher is required");
            System.err.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]");
            System.exit(2);
        }

        byte[] stdinBytes = System.in.readAllBytes();
        if (stdinBytes.length == 0) {
            System.err.println("jamcrest: empty input on stdin");
            System.exit(2);
        }
        String jsonInput = new String(stdinBytes, StandardCharsets.UTF_8);
        String matcherJs = Files.readString(Path.of(matcherPath), StandardCharsets.UTF_8);

        run(jsonInput, matcherJs, ignoreUnknown, quiet);
    }

    private static void run(String jsonInput, String matcherJs, boolean ignoreUnknown, boolean quiet) {
        Jamcrest.Result result;
        try {
            result = Jamcrest.match(jsonInput, matcherJs, ignoreUnknown);
        } catch (IllegalArgumentException e) {
            System.err.println("jamcrest: " + e.getMessage());
            System.exit(2);
            return;
        } catch (Exception e) {
            System.err.println("jamcrest: runtime error: " + e.getMessage());
            System.exit(2);
            return;
        }

        if (!result.match() && !quiet && result.diagnostic() != null) {
            System.err.println(result.diagnostic());
        }

        System.exit(result.match() ? 0 : 1);
    }
}
