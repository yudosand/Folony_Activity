<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Services\Admin\AdminMetricsService;
use Illuminate\Support\Arr;
use Illuminate\View\View;

class AdminDashboardController extends Controller
{
    public function __invoke(AdminMetricsService $metricsService): View
    {
        $connectionName = config('database.default');
        $connection = config('database.connections.' . $connectionName, []);
        $databaseLabel = match ($connectionName) {
            'sqlite' => Arr::get($connection, 'database', 'sqlite'),
            default => Arr::get($connection, 'database', '-'),
        };

        return view('admin.dashboard', [
            'summary' => $metricsService->dashboardSummary(),
            'dataSource' => [
                'environment' => app()->environment(),
                'app_url' => config('app.url'),
                'connection' => $connectionName,
                'database' => $databaseLabel,
                'is_live_shared_source' => $connectionName !== 'sqlite',
            ],
        ]);
    }
}
