<?php

return [
    // FGG_ENVIRONMENT is a server setting, never a client-supplied URL.
    'environment' => env('FGG_ENVIRONMENT', env('APP_ENV', 'local') === 'production' ? 'production' : 'staging'),
];
