<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Mobile App API Routes - Version 1
| Base URL: /api/v1
|
*/

// API Version 1
Route::prefix('v1')->group(function () {
    
    // Public Routes (No Authentication Required)
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])->name('api.register');
        Route::post('/login', [AuthController::class, 'login'])->name('api.login');
    });
    
    // Protected Routes (Require Authentication)
    Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
        
        // Authentication & User Profile
        Route::prefix('auth')->group(function () {
            Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');
            Route::post('/logout-all', [AuthController::class, 'logoutAll'])->name('api.logout-all');
            Route::post('/refresh-token', [AuthController::class, 'refreshToken'])->name('api.refresh-token');
            Route::get('/user', [AuthController::class, 'user'])->name('api.user');
            Route::post('/update-profile', [AuthController::class, 'updateProfile'])->name('api.update-profile');
        });
        
        // Categories (with user access control)
        Route::prefix('categories')->group(function () {
            Route::get('/', [\App\Http\Controllers\Api\CategoryController::class, 'index'])->name('api.categories.index');
            Route::get('/tree', [\App\Http\Controllers\Api\CategoryController::class, 'tree'])->name('api.categories.tree');
            Route::get('/{id}', [\App\Http\Controllers\Api\CategoryController::class, 'show'])->name('api.categories.show');
            Route::get('/{parentId}/subcategories', [\App\Http\Controllers\Api\CategoryController::class, 'subcategories'])->name('api.categories.subcategories');
        });
        
        // Contents/Materials (with user access control)
        Route::prefix('contents')->group(function () {
            Route::get('/', [\App\Http\Controllers\Api\ContentController::class, 'all'])->name('api.contents.all');
            Route::get('/search', [\App\Http\Controllers\Api\ContentController::class, 'search'])->name('api.contents.search');
            Route::get('/type/{type}', [\App\Http\Controllers\Api\ContentController::class, 'byType'])->name('api.contents.by-type');
            Route::get('/{id}', [\App\Http\Controllers\Api\ContentController::class, 'show'])->name('api.contents.show');
        });
        
        // Get contents by category (works for all 3 levels)
        Route::get('/categories/{categoryId}/contents', [\App\Http\Controllers\Api\ContentController::class, 'index'])->name('api.categories.contents');
        
        // Help & Support
        Route::prefix('support')->group(function () {
            Route::get('/faqs', [\App\Http\Controllers\Api\SupportController::class, 'faqs'])->name('api.support.faqs');
            Route::post('/submit', [\App\Http\Controllers\Api\SupportController::class, 'submit'])->name('api.support.submit');
            Route::get('/tickets', [\App\Http\Controllers\Api\SupportController::class, 'myTickets'])->name('api.support.tickets');
            Route::get('/tickets/{id}', [\App\Http\Controllers\Api\SupportController::class, 'show'])->name('api.support.show');
        });
        
        // Notifications
        Route::prefix('notifications')->group(function () {
            Route::get('/', [\App\Http\Controllers\Api\NotificationController::class, 'index'])->name('api.notifications.index');
            Route::get('/count', [\App\Http\Controllers\Api\NotificationController::class, 'count'])->name('api.notifications.count');
            Route::post('/mark-all-read', [\App\Http\Controllers\Api\NotificationController::class, 'markAllAsRead'])->name('api.notifications.mark-all-read');
            Route::post('/{id}/mark-read', [\App\Http\Controllers\Api\NotificationController::class, 'markAsRead'])->name('api.notifications.mark-read');
            Route::get('/{id}', [\App\Http\Controllers\Api\NotificationController::class, 'show'])->name('api.notifications.show');
        });
    });
});

// API Health Check
Route::get('/health', function () {
    return response()->json([
        'success' => true,
        'message' => 'API is running',
        'version' => 'v1',
        'timestamp' => now()->toIso8601String(),
    ]);
})->name('api.health');

