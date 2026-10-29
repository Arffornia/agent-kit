<?php
// Turns a deptrac JSON report into violations with a "how to fix" line each (agent-kit guard).
// Usage: vendor/bin/deptrac analyse --no-progress --formatter=json --output=build/deptrac.json; php tools/deptrac-explain.php build/deptrac.json
// Exit code 1 when there is at least one (non-baselined) violation.

$hints = [
    'Controller>Model' => 'Controllers must not touch models. Move the lookup into a Service method that calls a Repository, and pass ids/DTOs in and Resources out.',
    'Controller>Eloquent' => 'No Eloquent, query builder or DB facade in controllers. Add a Repository method for the query and call it from a Service.',
    'Controller>Repository' => 'Controllers call Services, not Repositories. Add a Service method that wraps the repository call (transactions and rules live there).',
    'Controller>HttpClient' => 'Outgoing HTTP belongs in a Service (timeouts, retries, Http::fake in tests). Move the call to app/Services and inject the service.',
    '*>HttpClient' => 'Only Services may use the Http facade / HTTP client. Move the call into a Service and inject it.',
    'Service>Eloquent' => 'Services do not build queries. Add a Repository method (with lockForUpdate if it guards money or stock) and call it.',
    'Model>Service' => 'Models must not call Services (cycles, hidden side effects). Move the logic into the Service that uses the model.',
    'Model>Repository' => 'Models must not call Repositories. Invert it: the Repository returns models.',
    'Repository>Service' => 'Repositories are the bottom layer: no calls up to Services. Move orchestration into the Service.',
    '*>Controller' => 'Nothing depends on a controller. Extract the shared code into a Service.',
];

$file = $argv[1] ?? 'build/deptrac.json';
$data = json_decode((string) @file_get_contents($file), true);
if (!is_array($data)) {
    fwrite(STDERR, "deptrac-explain: cannot read $file. Run deptrac with --formatter=json --output=$file first.\n");
    exit(2);
}
$count = 0;
foreach (($data['files'] ?? []) as $path => $info) {
    foreach (($info['messages'] ?? []) as $m) {
        if (($m['type'] ?? 'error') !== 'error') {
            continue;
        }
        $count++;
        $msg = $m['message'] ?? '';
        $hint = 'See deptrac.yaml ruleset: depend only on the layers listed for your layer.';
        if (preg_match('/\((\w+) on (\w+)\)\s*$/', $msg, $mm)) {
            $hint = $hints["{$mm[1]}>{$mm[2]}"] ?? $hints["*>{$mm[2]}"] ?? $hint;
        }
        $rel = preg_replace('#^' . preg_quote(getcwd() . '/', '#') . '#', '', $path);
        printf("%s:%d: %s\n  fix: %s\n", $rel, $m['line'] ?? 0, $msg, $hint);
    }
}
$report = $data['Report'] ?? [];
printf("deptrac: %d violation(s), %d baselined.\n", $count, $report['Skipped violations'] ?? 0);
if ($count > 0) {
    echo "Do not add these to deptrac.baseline.yaml: fix them. The baseline only holds pre-existing debt.\n";
}
exit($count > 0 ? 1 : 0);
