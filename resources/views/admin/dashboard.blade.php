@extends('admin.layouts.app')

@section('title', 'Dashboard')

@section('content')
<div class="space-y-6">
    <!-- Welcome Header -->
    <div class="bg-gradient-to-r from-blue-600 to-blue-700 rounded-xl shadow-lg p-6 text-white">
        <div class="flex items-center justify-between">
            <div>
                <h1 class="text-2xl font-bold mb-1">Welcome back, {{ Auth::user()->name }}! 👋</h1>
                <p class="text-blue-100">Here's what's happening with your app today</p>
            </div>
            <div class="hidden md:block">
                <div class="text-right">
                    <p class="text-sm text-blue-200">{{ now()->format('l') }}</p>
                    <p class="text-lg font-semibold">{{ now()->format('M d, Y') }}</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <!-- Total Categories -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-600">Total Categories</p>
                    <p class="text-3xl font-bold text-gray-900 mt-1">{{ $stats['totalCategories'] }}</p>
                </div>
                <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
                    </svg>
                </div>
            </div>
            <div class="flex items-center mt-3 text-xs">
                <span class="text-green-600 font-medium">{{ $stats['activeCategories'] }} Active</span>
                <span class="text-gray-400 mx-2">•</span>
                <span class="text-red-600 font-medium">{{ $stats['inactiveCategories'] }} Inactive</span>
            </div>
        </div>

        <!-- Total Users -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-600">Total Users</p>
                    <p class="text-3xl font-bold text-gray-900 mt-1">{{ $stats['totalUsers'] }}</p>
                </div>
                <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
                    </svg>
                </div>
            </div>
            <div class="mt-3">
                <a href="{{ route('admin.users.index') }}" class="text-xs text-blue-600 hover:text-blue-800 font-medium">Manage Users →</a>
            </div>
        </div>

        <!-- Total Contents -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-600">Total Materials</p>
                    <p class="text-3xl font-bold text-gray-900 mt-1">{{ $stats['totalContents'] }}</p>
                </div>
                <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                    </svg>
                </div>
            </div>
            <div class="mt-3">
                <a href="{{ route('admin.contents.index') }}" class="text-xs text-blue-600 hover:text-blue-800 font-medium">View Contents →</a>
            </div>
        </div>

        <!-- API Status -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-sm font-medium text-gray-600">API Status</p>
                    <p class="text-3xl font-bold text-green-600 mt-1">Active</p>
                </div>
                <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
                    </svg>
                </div>
            </div>
            <div class="mt-3">
                <a href="{{ route('admin.api.index') }}" class="text-xs text-blue-600 hover:text-blue-800 font-medium">View Docs →</a>
            </div>
        </div>
    </div>

    <!-- Category Breakdown -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Level 1 -->
        <a href="{{ route('admin.categories.index', ['level' => 1]) }}" class="bg-white rounded-lg shadow-sm border-l-4 border-blue-500 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-xs font-semibold text-gray-500 uppercase">Main Categories</p>
                    <p class="text-2xl font-bold text-gray-900 mt-1">{{ $stats['mainCategories'] }}</p>
                </div>
                <span class="text-xs bg-blue-100 text-blue-700 px-3 py-1 rounded-full font-medium">Level 1</span>
            </div>
        </a>

        <!-- Level 2 -->
        <a href="{{ route('admin.categories.index', ['level' => 2]) }}" class="bg-white rounded-lg shadow-sm border-l-4 border-green-500 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-xs font-semibold text-gray-500 uppercase">Sub Categories</p>
                    <p class="text-2xl font-bold text-gray-900 mt-1">{{ $stats['subCategories'] }}</p>
                </div>
                <span class="text-xs bg-green-100 text-green-700 px-3 py-1 rounded-full font-medium">Level 2</span>
            </div>
        </a>

        <!-- Level 3 -->
        <a href="{{ route('admin.categories.index', ['level' => 3]) }}" class="bg-white rounded-lg shadow-sm border-l-4 border-purple-500 p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-xs font-semibold text-gray-500 uppercase">3rd Level Categories</p>
                    <p class="text-2xl font-bold text-gray-900 mt-1">{{ $stats['thirdLevelCategories'] }}</p>
                </div>
                <span class="text-xs bg-purple-100 text-purple-700 px-3 py-1 rounded-full font-medium">Level 3</span>
            </div>
        </a>
    </div>

    <!-- Recent Activity -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Categories -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Recent Categories</h3>
            </div>
            <div class="p-6">
                @forelse($recentCategories as $category)
                <div class="flex items-center justify-between py-3 {{ !$loop->last ? 'border-b border-gray-100' : '' }}">
                    <div class="flex items-center space-x-3">
                        @if($category->image)
                        <img src="{{ asset('storage/' . $category->image) }}" alt="{{ $category->title }}" class="w-10 h-10 rounded-lg object-cover">
                        @else
                        <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center text-white font-bold">
                            {{ substr($category->title, 0, 1) }}
                        </div>
                        @endif
                        <div>
                            <p class="text-sm font-medium text-gray-900">{{ $category->title }}</p>
                            <p class="text-xs text-gray-500">
                                {{ $category->parent ? $category->parent->title . ' → ' : '' }}
                                Level {{ $category->level }}
                            </p>
                        </div>
                    </div>
                    <span class="text-xs {{ $category->is_active ? 'text-green-600' : 'text-gray-400' }} font-medium">
                        {{ $category->is_active ? 'Active' : 'Inactive' }}
                    </span>
                </div>
                @empty
                <div class="text-center py-8 text-gray-500">
                    <svg class="w-12 h-12 mx-auto text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path>
                    </svg>
                    <p class="text-sm">No categories yet</p>
                </div>
                @endforelse
            </div>
        </div>

        <!-- Recent Users -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Recent Users</h3>
            </div>
            <div class="p-6">
                @forelse($recentUsers as $user)
                <div class="flex items-center justify-between py-3 {{ !$loop->last ? 'border-b border-gray-100' : '' }}">
                    <div class="flex items-center space-x-3">
                        <div class="w-10 h-10 bg-gradient-to-br from-green-500 to-blue-600 rounded-full flex items-center justify-center text-white font-bold">
                            {{ substr($user->name, 0, 1) }}
                        </div>
                        <div>
                            <p class="text-sm font-medium text-gray-900">{{ $user->name }}</p>
                            <p class="text-xs text-gray-500">KIU ID: {{ $user->kiu_id }}</p>
                        </div>
                    </div>
                    <a href="{{ route('admin.users.category-access', $user->id) }}" class="text-xs text-blue-600 hover:text-blue-800 font-medium">Manage →</a>
                </div>
                @empty
                <div class="text-center py-8 text-gray-500">
                    <svg class="w-12 h-12 mx-auto text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                    </svg>
                    <p class="text-sm">No users yet</p>
                </div>
                @endforelse
            </div>
        </div>
    </div>

    <!-- Quick Actions -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
            <a href="{{ route('admin.categories.create', ['level' => 1]) }}" class="flex flex-col items-center justify-center p-4 border border-gray-200 rounded-lg hover:bg-blue-50 hover:border-blue-500 transition-all">
                <svg class="w-8 h-8 text-blue-600 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                </svg>
                <span class="text-sm font-medium text-gray-700">Add Category</span>
            </a>

            <a href="{{ route('admin.contents.create') }}" class="flex flex-col items-center justify-center p-4 border border-gray-200 rounded-lg hover:bg-green-50 hover:border-green-500 transition-all">
                <svg class="w-8 h-8 text-green-600 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                <span class="text-sm font-medium text-gray-700">Add Content</span>
            </a>

            <a href="{{ route('admin.users.create') }}" class="flex flex-col items-center justify-center p-4 border border-gray-200 rounded-lg hover:bg-purple-50 hover:border-purple-500 transition-all">
                <svg class="w-8 h-8 text-purple-600 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
                </svg>
                <span class="text-sm font-medium text-gray-700">Add User</span>
            </a>

            <a href="{{ route('admin.api.index') }}" class="flex flex-col items-center justify-center p-4 border border-gray-200 rounded-lg hover:bg-yellow-50 hover:border-yellow-500 transition-all">
                <svg class="w-8 h-8 text-yellow-600 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
                </svg>
                <span class="text-sm font-medium text-gray-700">API Docs</span>
            </a>
        </div>
    </div>
</div>
@endsection
