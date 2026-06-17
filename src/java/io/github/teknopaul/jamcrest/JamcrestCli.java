package io.github.teknopaul.jamcrest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

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
            run(args[0], args[1], false, false, List.of(), List.of(), List.of());
            return;
        }

        // Flag-based form matching the C++ CLI interface
        String matcherPath = null;
        boolean ignoreUnknown = false;
        boolean quiet = false;
        boolean help = false;
        boolean version = false;
        List<String[]> varPairs = new ArrayList<>();   // --var name=value
        List<String> argsExprs = new ArrayList<>();    // --args=EXPR
        List<String> arraySortKeys = new ArrayList<>(); // --array-sort-keys=id,name

        for (int i = 0; i < args.length; i++) {
            if (args[i].startsWith("--args=")) {
                argsExprs.add(args[i].substring(7));
                continue;
            }
            if (args[i].startsWith("--array-sort-keys=")) {
                for (String k : args[i].substring(18).split(",")) {
                    if (!k.isEmpty()) arraySortKeys.add(k);
                }
                continue;
            }
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
                case "--var" -> {
                    if (i + 1 >= args.length) {
                        System.err.println("jamcrest: --var requires a name=value argument");
                        System.exit(2);
                    }
                    String nv = args[++i];
                    int eq = nv.indexOf('=');
                    if (eq < 0) {
                        System.err.println("jamcrest: --var value must be in name=value format");
                        System.exit(2);
                    }
                    varPairs.add(new String[]{nv.substring(0, eq), nv.substring(eq + 1)});
                }
                case "--args" -> {
                    if (i + 1 >= args.length) {
                        System.err.println("jamcrest: --args requires a JS object expression");
                        System.exit(2);
                    }
                    argsExprs.add(args[++i]);
                }
                case "--array-sort-keys" -> {
                    if (i + 1 >= args.length) {
                        System.err.println("jamcrest: --array-sort-keys requires a comma-separated list of field names");
                        System.exit(2);
                    }
                    for (String k : args[++i].split(",")) {
                        if (!k.isEmpty()) arraySortKeys.add(k);
                    }
                }
                default -> {
                    System.err.println("jamcrest: unknown flag: " + args[i]);
                    System.err.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet] [--var name=value]... [--args=EXPR]");
                    System.exit(2);
                }
            }
        }

        if (version) { System.out.println("jamcrest 0.1.0"); return; }
        if (help) {
            System.out.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]");
            System.out.println("               [--var name=value]... [--args=EXPR]");
            System.out.println("       Reads JSON from stdin, matches against matcher JS file.");
            System.out.println("       --var name=value  Set a String variable in the matcher global context.");
            System.out.println("       --args=EXPR       Eval a JS object and spread its properties into global context.");
            System.out.println("       Exit: 0=match  1=no-match  2=error");
            System.out.println();
            System.out.println("       jamcrest '<json>' '<matcherJs>'");
            System.out.println("       Inline form — both inputs as string arguments.");
            return;
        }
        if (matcherPath == null) {
            System.err.println("jamcrest: --matcher is required");
            System.err.println("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet] [--var name=value]... [--args=EXPR]");
            System.exit(2);
        }

        byte[] stdinBytes = System.in.readAllBytes();
        if (stdinBytes.length == 0) {
            System.err.println("jamcrest: empty input on stdin");
            System.exit(2);
        }
        String jsonInput = new String(stdinBytes, StandardCharsets.UTF_8);
        String matcherJs = Files.readString(Path.of(matcherPath), StandardCharsets.UTF_8);

        run(jsonInput, matcherJs, ignoreUnknown, quiet, varPairs, argsExprs, arraySortKeys);
    }

    private static void run(String jsonInput, String matcherJs, boolean ignoreUnknown, boolean quiet,
                            List<String[]> varPairs, List<String> argsExprs, List<String> arraySortKeys) {
        Jamcrest.Result result;
        try (Jamcrest jmc = new Jamcrest()) {
            if (!arraySortKeys.isEmpty()) {
                jmc.withArraySortKeys(arraySortKeys.toArray(new String[0]));
            }
            for (String expr : argsExprs) {
                jmc.putGlobalsFromJs(expr);
            }
            Object[] contextArgs = new Object[varPairs.size() * 2];
            for (int i = 0; i < varPairs.size(); i++) {
                contextArgs[i * 2]     = varPairs.get(i)[0];
                contextArgs[i * 2 + 1] = varPairs.get(i)[1];
            }
            result = jmc.compare(jsonInput, matcherJs, ignoreUnknown, contextArgs);
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
