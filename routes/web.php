<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\CategoryController;
use App\Http\Controllers\Admin\ContentController;

Route::get('/', function () {
    return redirect()->route('admin.login');
});

// Admin Authentication Routes
Route::prefix('admin')->name('admin.')->group(function () {
    // Public routes (no auth required)
    Route::get('/login', [AuthController::class, 'showLoginForm'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.post');
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    // Protected routes (require admin auth)
    Route::middleware(['auth', 'admin'])->group(function () {
        Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');
        
        // Category routes
        Route::resource('categories', CategoryController::class);
        
        // Content routes
        Route::resource('contents', ContentController::class);
        
        // User Management routes
        Route::resource('users', \App\Http\Controllers\Admin\UserController::class);
        Route::get('/users/{id}/category-access', [\App\Http\Controllers\Admin\UserController::class, 'categoryAccess'])->name('users.category-access');
        Route::put('/users/{id}/category-access', [\App\Http\Controllers\Admin\UserController::class, 'updateCategoryAccess'])->name('users.update-category-access');
        
        // Help & Support routes
        Route::resource('faqs', \App\Http\Controllers\Admin\FaqController::class);
        Route::get('/support', [\App\Http\Controllers\Admin\SupportController::class, 'index'])->name('support.index');
        Route::get('/support/{id}', [\App\Http\Controllers\Admin\SupportController::class, 'show'])->name('support.show');
        Route::put('/support/{id}', [\App\Http\Controllers\Admin\SupportController::class, 'update'])->name('support.update');
        Route::patch('/support/{id}/status', [\App\Http\Controllers\Admin\SupportController::class, 'updateStatus'])->name('support.update-status');
        
        // Notifications routes
        Route::resource('notifications', \App\Http\Controllers\Admin\NotificationController::class);
        
        // API Documentation
        Route::get('/api-docs', [\App\Http\Controllers\Admin\ApiController::class, 'index'])->name('api.index');
    });
});
