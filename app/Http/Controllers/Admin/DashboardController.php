<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    /**
     * Display the admin dashboard.
     */
    public function index()
    {
        $stats = [
            'totalCategories' => Category::count(),
            'activeCategories' => Category::where('is_active', true)->count(),
            'inactiveCategories' => Category::where('is_active', false)->count(),
            'mainCategories' => Category::where('level', 1)->count(),
            'subCategories' => Category::where('level', 2)->count(),
            'thirdLevelCategories' => Category::where('level', 3)->count(),
            'totalUsers' => \App\Models\User::where('role', 'user')->count(),
            'totalContents' => \App\Models\Content::count(),
        ];

        // Recent categories
        $recentCategories = Category::with('parent')
            ->latest()
            ->take(5)
            ->get();

        // Recent users
        $recentUsers = \App\Models\User::where('role', 'user')
            ->latest()
            ->take(5)
            ->get();

        return view('admin.dashboard', compact('stats', 'recentCategories', 'recentUsers'));
    }
}
