<?php

declare(strict_types=1);

$token = 'folony-production-artisan-20260814';

if (($_GET['token'] ?? '') !== $token) {
    http_response_code(404);
    echo 'Not found';
    exit;
}

header('Content-Type: text/plain; charset=utf-8');
@set_time_limit(300);

function line(string $message = ''): void
{
    echo $message . "\n";
    @ob_flush();
    @flush();
}

function findLaravelRoot(): string
{
    $candidates = [
        __DIR__,
        dirname(__DIR__),
    ];

    foreach ($candidates as $candidate) {
        if (is_file($candidate . DIRECTORY_SEPARATOR . 'artisan')) {
            return $candidate;
        }
    }

    throw new RuntimeException('Laravel root/artisan tidak ditemukan. Upload file ini ke folder public Laravel.');
}

function runCommand(string $command, string $cwd): int
{
    line('$ ' . $command);

    $output = [];
    $exitCode = 0;
    exec($command . ' 2>&1', $output, $exitCode);

    if ($output !== []) {
        line(implode("\n", $output));
    }

    line('exit code: ' . $exitCode);
    line();

    return $exitCode;
}

try {
    $root = findLaravelRoot();
    chdir($root);

    line('Folony Activity production artisan one-time runner');
    line('Laravel root: ' . $root);
    line('Started at: ' . date('c'));
    line();

    $commands = [
        'php artisan migrate --force',
        'php artisan storage:link',
        'php artisan optimize:clear',
    ];

    foreach ($commands as $command) {
        $exitCode = runCommand($command, $root);
        if ($exitCode !== 0 && $command !== 'php artisan storage:link') {
            throw new RuntimeException('Command gagal: ' . $command);
        }
    }

    line('DONE');

    if (@unlink(__FILE__)) {
        line('production-artisan-once-20260814.php sudah terhapus otomatis.');
    } else {
        line('PENTING: hapus file production-artisan-once-20260814.php setelah selesai.');
    }
} catch (Throwable $error) {
    http_response_code(500);
    line('ERROR: ' . $error->getMessage());
    line('File: ' . $error->getFile() . ':' . $error->getLine());
}
