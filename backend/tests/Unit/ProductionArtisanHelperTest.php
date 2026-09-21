<?php

namespace Tests\Unit;

use Illuminate\Filesystem\Filesystem;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Process\Process;

class ProductionArtisanHelperTest extends TestCase
{
    private string $root;

    private string $source;

    private string $token;

    private string $appEnv = 'production';

    protected function setUp(): void
    {
        parent::setUp();
        $this->source = dirname(__DIR__, 3).'/scripts/templates/production-artisan-once.php.template';
        preg_match('/\$expectedToken = \'([^\']+)\'/', file_get_contents($this->source), $matches);
        $this->token = $matches[1];
        $this->root = sys_get_temp_dir().'/folony-helper-test-'.bin2hex(random_bytes(8));
        foreach (['public', 'vendor', 'bootstrap', 'storage/framework'] as $directory) {
            mkdir($this->root.'/'.$directory, 0777, true);
        }
        touch($this->root.'/artisan');
        file_put_contents($this->root.'/vendor/autoload.php', '<?php');
        copy($this->source, $this->root.'/public/helper.php');
        file_put_contents($this->root.'/bootstrap/app.php', <<<'PHP'
<?php
return new class {
    public function make($class) { return $this; }
    public function bootstrap() {}
    public function get($key) {
        return ['app.env' => getenv('TEST_APP_ENV') ?: 'production', 'app.debug' => false,
            'app.url' => 'https://absent.folony.co.id', 'fgg.environment' => 'production'][$key] ?? null;
    }
    public function call($command, $arguments) {
        file_put_contents(__DIR__ . '/../commands.jsonl', json_encode([$command, $arguments]) . "\n", FILE_APPEND);
        return $command === getenv('FAIL_COMMAND') ? 1 : 0;
    }
    public function output() { return "command output\n"; }
};
PHP);
    }

    protected function tearDown(): void
    {
        if (str_starts_with($this->root, sys_get_temp_dir().'/folony-helper-test-')) {
            (new Filesystem)->deleteDirectory($this->root);
        }
        parent::tearDown();
    }

    private function runHelper(string $method, ?string $token = null, string $host = 'absent.folony.co.id', string $fail = ''): string
    {
        $code = '$_SERVER["REQUEST_METHOD"]='.var_export($method, true).';'
            .'$_SERVER["HTTP_HOST"]='.var_export($host, true).';'
            .'$_GET["token"]='.var_export($token ?? $this->token, true).';'
            .'register_shutdown_function(function(){echo "\nSTATUS=" . http_response_code();});'
            .'require '.var_export($this->root.'/public/helper.php', true).';';
        $process = new Process([PHP_BINARY, '-r', $code], $this->root, ['FAIL_COMMAND' => $fail, 'TEST_APP_ENV' => $this->appEnv]);
        $process->mustRun();

        return $process->getOutput();
    }

    public function test_get_is_a_preview_and_invalid_credentials_cannot_execute(): void
    {
        $this->assertStringContainsString('Jalankan Artisan Production', $this->runHelper('GET'));
        $this->assertStringContainsString('STATUS=404', $this->runHelper('POST', 'wrong'));
        $this->assertStringContainsString('STATUS=404', $this->runHelper('POST', null, 'staging-absent.folony.co.id'));
        $this->assertFileDoesNotExist($this->root.'/commands.jsonl');
    }

    public function test_post_runs_only_deployment_commands_then_disables_itself(): void
    {
        $this->assertStringContainsString('DONE - Migrasi dan cache selesai.', $this->runHelper('POST'));
        $commands = array_map(fn ($line) => json_decode($line, true), file($this->root.'/commands.jsonl', FILE_IGNORE_NEW_LINES));
        $this->assertSame(['migrate', 'optimize:clear', 'storage:link'], array_column($commands, 0));
        $this->assertTrue($commands[0][1]['--force']);
        $this->assertFileDoesNotExist($this->root.'/public/helper.php');
        copy($this->source, $this->root.'/public/helper.php');
        $this->assertStringContainsString('STATUS=410', $this->runHelper('POST'));
        $this->assertCount(3, file($this->root.'/commands.jsonl'));
    }

    public function test_failure_stops_later_commands_and_can_be_retried(): void
    {
        $this->assertStringContainsString('STATUS=500', $this->runHelper('POST', fail: 'migrate'));
        $this->assertCount(1, file($this->root.'/commands.jsonl'));
        $this->assertFileExists($this->root.'/public/helper.php');
        $this->assertStringContainsString('DONE - Migrasi dan cache selesai.', $this->runHelper('POST'));
    }

    public function test_wrong_environment_stops_before_any_deployment_command(): void
    {
        $this->appEnv = 'staging';
        $this->assertStringContainsString('STATUS=409', $this->runHelper('POST'));
        $this->assertFileDoesNotExist($this->root.'/commands.jsonl');
    }

    public function test_existing_public_storage_is_preserved(): void
    {
        mkdir($this->root.'/public/storage');
        $this->runHelper('POST');
        $this->assertCount(2, file($this->root.'/commands.jsonl'));
        $this->assertDirectoryExists($this->root.'/public/storage');
    }
}
