<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (ValidationException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => 'Validation failed.',
                    'errors' => $exception->errors(),
                ], 422);
            }

            return null;
        });

        $exceptions->render(function (AuthenticationException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => 'Unauthenticated.',
                ], 401);
            }

            return null;
        });

        $exceptions->render(function (AuthorizationException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => $exception->getMessage() !== ''
                        ? $exception->getMessage()
                        : 'Forbidden.',
                ], 403);
            }

            return null;
        });

        $exceptions->render(function (HttpExceptionInterface $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => $exception->getMessage() !== ''
                        ? $exception->getMessage()
                        : 'HTTP error.',
                ], $exception->getStatusCode());
            }

            return null;
        });
    })->create();
