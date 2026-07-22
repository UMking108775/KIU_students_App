@extends('admin.layouts.app')

@section('title', 'Manage Users')

@section('content')
<div class="max-w-7xl mx-auto">
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
        <div>
            <h1 class="text-2xl font-bold text-gray-800">Manage Users</h1>
            <p class="text-sm text-gray-500 mt-1">Manage user accounts and category access permissions</p>
        </div>
        <a href="{{ route('admin.users.create') }}" class="bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white px-5 py-2.5 rounded-lg flex items-center shadow-lg shadow-blue-500/25 transition-all duration-200">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
            </svg>
            Add New User
        </a>
    </div>

    <!-- Advanced Filter Bar -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-5 mb-6">
        <form method="GET" action="{{ route('admin.users.index') }}" id="filterForm">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
                <!-- Search -->
                <div class="lg:col-span-2">
                    <label class="block text-xs font-medium text-gray-500 uppercase mb-1.5">Search</label>
                    <div class="relative">
                        <input 
                            type="text" 
                            name="search" 
                            value="{{ $search ?? '' }}"
                            placeholder="Name, KIU ID, or WhatsApp..." 
                            class="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                        >
                        <svg class="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                        </svg>
                    </div>
                </div>

                <!-- Date From -->
                <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase mb-1.5">From Date</label>
                    <input 
                        type="date" 
                        name="date_from" 
                        value="{{ $dateFrom ?? '' }}"
                        class="w-full px-3 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                    >
                </div>

                <!-- Date To -->
                <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase mb-1.5">To Date</label>
                    <input 
                        type="date" 
                        name="date_to" 
                        value="{{ $dateTo ?? '' }}"
                        class="w-full px-3 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                    >
                </div>

                <!-- Access Filter -->
                <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase mb-1.5">Access Status</label>
                    <select 
                        name="access_filter" 
                        class="w-full px-3 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                    >
                        <option value="">All Users</option>
                        <option value="has_access" {{ ($accessFilter ?? '') === 'has_access' ? 'selected' : '' }}>Has Access</option>
                        <option value="no_access" {{ ($accessFilter ?? '') === 'no_access' ? 'selected' : '' }}>No Access</option>
                    </select>
                </div>

                <!-- Per Page -->
                <div>
                    <label class="block text-xs font-medium text-gray-500 uppercase mb-1.5">Show</label>
                    <select 
                        name="per_page" 
                        class="w-full px-3 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                        onchange="document.getElementById('filterForm').submit()"
                    >
                        <option value="10" {{ ($perPage ?? 15) == 10 ? 'selected' : '' }}>10 per page</option>
                        <option value="25" {{ ($perPage ?? 15) == 25 ? 'selected' : '' }}>25 per page</option>
                        <option value="50" {{ ($perPage ?? 15) == 50 ? 'selected' : '' }}>50 per page</option>
                        <option value="100" {{ ($perPage ?? 15) == 100 ? 'selected' : '' }}>100 per page</option>
                    </select>
                </div>
            </div>

            <!-- Filter Actions -->
            <div class="flex items-center justify-between mt-4 pt-4 border-t border-gray-100">
                <div class="text-sm text-gray-500">
                    <span class="font-medium text-gray-700">{{ $users->total() }}</span> users found
                </div>
                <div class="flex gap-2">
                    @if($search || $dateFrom || $dateTo || $accessFilter)
                    <a href="{{ route('admin.users.index') }}" class="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors">
                        Clear Filters
                    </a>
                    @endif
                    <button type="submit" class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors">
                        Apply Filters
                    </button>
                </div>
            </div>
        </form>
    </div>

    <!-- Bulk Actions Toolbar (Hidden by default) -->
    <div id="bulkActionsBar" class="hidden bg-gradient-to-r from-indigo-600 to-purple-600 rounded-xl shadow-lg p-4 mb-4 sticky top-4 z-10">
        <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
                <div class="flex items-center space-x-2 text-white">
                    <span class="flex items-center justify-center w-8 h-8 bg-white/20 rounded-full text-sm font-bold" id="selectedCount">0</span>
                    <span class="font-medium">users selected</span>
                </div>
                <button 
                    type="button" 
                    onclick="deselectAll()"
                    class="px-3 py-1.5 text-sm font-medium text-white/80 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
                >
                    Deselect All
                </button>
            </div>
            <div class="flex items-center space-x-3">
                <button 
                    type="button" 
                    onclick="openCategoryModal()"
                    class="px-4 py-2 text-sm font-medium text-indigo-700 bg-white hover:bg-gray-100 rounded-lg transition-colors flex items-center shadow-md"
                >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                    </svg>
                    Assign Categories
                </button>
            </div>
        </div>
    </div>

    <!-- Users Table -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-4 py-3 text-left w-12">
                            <input 
                                type="checkbox" 
                                id="selectAllCheckbox"
                                onchange="toggleSelectAll(this)"
                                class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-2 focus:ring-indigo-500 cursor-pointer"
                            >
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">KIU ID</th>
                        <th class="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Name</th>
                        <th class="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">WhatsApp</th>
                        <th class="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Category Access</th>
                        <th class="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Created</th>
                        <th class="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase tracking-wider">Actions</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($users as $user)
                    <tr class="hover:bg-gray-50 transition-colors user-row" data-user-id="{{ $user->id }}" data-assigned-categories="{{ json_encode($user->accessibleLevel1Categories->pluck('id')) }}">
                        <td class="px-4 py-4">
                            <input 
                                type="checkbox" 
                                class="user-checkbox w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-2 focus:ring-indigo-500 cursor-pointer"
                                value="{{ $user->id }}"
                                onchange="updateSelection()"
                            >
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm font-semibold text-gray-900 font-mono">{{ $user->kiu_id }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex items-center">
                                <div class="w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-xs mr-3">
                                    {{ strtoupper(substr($user->name, 0, 1)) }}
                                </div>
                                <div class="text-sm font-medium text-gray-900">{{ $user->name }}</div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-gray-600">{{ $user->whatsapp_number }}</div>
                        </td>
                        <td class="px-6 py-4">
                            @if($user->accessibleLevel1Categories->count() > 0)
                            <div class="flex flex-wrap gap-1.5 max-w-xs">
                                @foreach($user->accessibleLevel1Categories as $lvl1Cat)
                                <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800 border border-emerald-200 shadow-sm" title="{{ $lvl1Cat->title }}">
                                    <svg class="w-3 h-3 mr-1 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                    </svg>
                                    {{ $lvl1Cat->title }}
                                </span>
                                @endforeach
                            </div>
                            @elseif($user->categories_count > 0)
                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                </svg>
                                {{ $user->categories_count }} subcategories
                            </span>
                            @else
                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                                </svg>
                                No access
                            </span>
                            @endif
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm text-gray-500">{{ $user->created_at->format('M d, Y') }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <div class="flex justify-end gap-1">
                                <a href="{{ route('admin.users.category-access', $user->id) }}" class="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors" title="Manage Category Access">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                                    </svg>
                                </a>
                                <a href="{{ route('admin.users.edit', $user->id) }}" class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors" title="Edit">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
                                    </svg>
                                </a>
                                <form method="POST" action="{{ route('admin.users.destroy', $user->id) }}" class="inline" onsubmit="return confirm('Are you sure you want to delete this user?');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                                        </svg>
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="7" class="px-6 py-12 text-center">
                            <div class="flex flex-col items-center">
                                <svg class="w-16 h-16 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
                                </svg>
                                <p class="text-gray-500 font-medium">No users found</p>
                                <p class="text-sm text-gray-400 mt-1">Try adjusting your filters or add a new user</p>
                            </div>
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <!-- Pagination -->
        @if($users->hasPages())
        <div class="px-6 py-4 border-t border-gray-200 bg-gray-50">
            <div class="flex items-center justify-between">
                <div class="text-sm text-gray-600">
                    Showing <span class="font-medium">{{ $users->firstItem() }}</span> to <span class="font-medium">{{ $users->lastItem() }}</span> of <span class="font-medium">{{ $users->total() }}</span> results
                </div>
                <div>
                    {{ $users->appends(request()->query())->links() }}
                </div>
            </div>
        </div>
        @endif
    </div>
</div>

<!-- Category Assignment Modal -->
<div id="categoryModal" class="fixed inset-0 z-50 hidden overflow-y-auto">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:p-0">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-gray-900/60 backdrop-blur-sm transition-opacity" onclick="closeCategoryModal()"></div>

        <!-- Modal Panel -->
        <div class="relative inline-block align-bottom bg-white rounded-2xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
            <form method="POST" action="{{ route('admin.users.bulk-category-access') }}" id="bulkCategoryForm">
                @csrf
                <input type="hidden" name="user_ids[]" id="selectedUserIds">
                
                <!-- Modal Header -->
                <div class="bg-gradient-to-r from-indigo-600 to-purple-600 px-6 py-5">
                    <div class="flex items-center justify-between">
                        <div>
                            <h3 class="text-xl font-bold text-white">Assign Category Access</h3>
                            <p class="text-indigo-200 text-sm mt-1">For <span id="modalSelectedCount" class="font-semibold text-white">0</span> selected users</p>
                        </div>
                        <button type="button" onclick="closeCategoryModal()" class="text-white/80 hover:text-white transition-colors">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                            </svg>
                        </button>
                    </div>
                </div>

                <!-- Action Toggle -->
                <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
                    <label class="block text-sm font-medium text-gray-700 mb-3">Action Type</label>
                    <div class="flex gap-4">
                        <label class="flex items-center cursor-pointer">
                            <input type="radio" name="action" value="grant" checked class="w-4 h-4 text-green-600 border-gray-300 focus:ring-green-500">
                            <span class="ml-2 text-sm font-medium text-gray-700 flex items-center">
                                <svg class="w-4 h-4 mr-1 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                </svg>
                                Grant Access
                            </span>
                        </label>
                        <label class="flex items-center cursor-pointer">
                            <input type="radio" name="action" value="revoke" class="w-4 h-4 text-red-600 border-gray-300 focus:ring-red-500">
                            <span class="ml-2 text-sm font-medium text-gray-700 flex items-center">
                                <svg class="w-4 h-4 mr-1 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                                </svg>
                                Revoke Access
                            </span>
                        </label>
                    </div>
                </div>

                <!-- Categories List -->
                <div class="px-6 py-4 max-h-96 overflow-y-auto">
                    <div class="flex items-center justify-between mb-4">
                        <label class="block text-sm font-medium text-gray-700">Select Categories (Level 1)</label>
                        <div class="flex gap-2">
                            <button type="button" onclick="selectAllCategories()" class="text-xs text-blue-600 hover:text-blue-800 font-medium">Select All</button>
                            <span class="text-gray-300">|</span>
                            <button type="button" onclick="deselectAllCategories()" class="text-xs text-gray-600 hover:text-gray-800 font-medium">Deselect All</button>
                        </div>
                    </div>
                    
                    @if($mainCategories->count() > 0)
                    <div class="space-y-2">
                        @foreach($mainCategories as $category)
                        <label class="flex items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-lg cursor-pointer transition-colors border border-gray-200 hover:border-gray-300">
                            <input 
                                type="checkbox" 
                                name="category_ids[]" 
                                value="{{ $category->id }}"
                                class="category-checkbox w-5 h-5 text-indigo-600 border-gray-300 rounded focus:ring-2 focus:ring-indigo-500"
                            >
                            <div class="ml-3 flex items-center flex-1">
                                @if($category->image)
                                <img src="{{ asset('storage/' . $category->image) }}" alt="{{ $category->title }}" class="w-10 h-10 rounded-lg object-cover mr-3 border border-gray-200">
                                @else
                                <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center mr-3">
                                    <span class="text-white font-bold text-lg">{{ substr($category->title, 0, 1) }}</span>
                                </div>
                                @endif
                                <div>
                                    <span class="font-medium text-gray-900">{{ $category->title }}</span>
                                    @if($category->children_count ?? false)
                                    <span class="text-xs text-gray-500 ml-2">(includes {{ $category->children_count }} subcategories)</span>
                                    @endif
                                </div>
                            </div>
                            <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded-full font-medium">L1</span>
                        </label>
                        @endforeach
                    </div>
                    @else
                    <div class="text-center py-8">
                        <svg class="w-12 h-12 text-gray-300 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path>
                        </svg>
                        <p class="text-gray-500">No categories available</p>
                    </div>
                    @endif
                </div>

                <!-- Modal Footer -->
                <div class="px-6 py-4 bg-gray-50 border-t border-gray-200 flex justify-between items-center">
                    <p class="text-xs text-gray-500">
                        <svg class="w-4 h-4 inline mr-1 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
                        </svg>
                        Subcategories will also be affected
                    </p>
                    <div class="flex gap-3">
                        <button type="button" onclick="closeCategoryModal()" class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
                            Cancel
                        </button>
                        <button type="submit" class="px-5 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors flex items-center">
                            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                            Apply Changes
                        </button>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
// Selection state
let selectedUsers = new Set();

function updateSelection() {
    selectedUsers = new Set();
    document.querySelectorAll('.user-checkbox:checked').forEach(checkbox => {
        selectedUsers.add(checkbox.value);
    });
    updateBulkActionsBar();
}

function updateBulkActionsBar() {
    const bar = document.getElementById('bulkActionsBar');
    const count = selectedUsers.size;
    document.getElementById('selectedCount').textContent = count;
    
    if (count > 0) {
        bar.classList.remove('hidden');
    } else {
        bar.classList.add('hidden');
    }
    
    // Update select all checkbox state
    const allCheckboxes = document.querySelectorAll('.user-checkbox');
    const selectAllCheckbox = document.getElementById('selectAllCheckbox');
    if (allCheckboxes.length > 0) {
        selectAllCheckbox.checked = selectedUsers.size === allCheckboxes.length;
        selectAllCheckbox.indeterminate = selectedUsers.size > 0 && selectedUsers.size < allCheckboxes.length;
    }
}

function toggleSelectAll(checkbox) {
    const checkboxes = document.querySelectorAll('.user-checkbox');
    checkboxes.forEach(cb => {
        cb.checked = checkbox.checked;
    });
    updateSelection();
}

function deselectAll() {
    document.querySelectorAll('.user-checkbox').forEach(cb => {
        cb.checked = false;
    });
    document.getElementById('selectAllCheckbox').checked = false;
    updateSelection();
}

// Modal functions
function openCategoryModal() {
    if (selectedUsers.size === 0) {
        alert('Please select at least one user');
        return;
    }
    
    // Update hidden inputs with selected user IDs
    const form = document.getElementById('bulkCategoryForm');
    
    // Remove existing hidden inputs
    form.querySelectorAll('input[name="user_ids[]"]').forEach(input => input.remove());
    
    // Add new hidden inputs for each selected user
    const selectedUserIdsArray = Array.from(selectedUsers);
    selectedUserIdsArray.forEach(userId => {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'user_ids[]';
        input.value = userId;
        form.appendChild(input);
    });

    // Collect assigned level 1 category IDs for selected users
    let categoryLists = [];
    selectedUserIdsArray.forEach(userId => {
        const row = document.querySelector(`.user-row[data-user-id="${userId}"]`);
        if (row && row.dataset.assignedCategories) {
            try {
                const cats = JSON.parse(row.dataset.assignedCategories);
                categoryLists.push(cats.map(id => Number(id)));
            } catch (e) {
                console.error(e);
            }
        }
    });

    // Determine which category checkboxes should be checked by default
    let activeCategoryIds = new Set();
    if (categoryLists.length === 1) {
        // Single user selected: pre-select all assigned categories for this user
        categoryLists[0].forEach(id => activeCategoryIds.add(id));
    } else if (categoryLists.length > 1) {
        // Multiple users selected: pre-select categories shared by ALL selected users
        const commonCats = categoryLists.reduce((acc, current) => {
            return acc.filter(id => current.includes(id));
        });
        commonCats.forEach(id => activeCategoryIds.add(id));
    }

    // Update category checkboxes state in modal
    document.querySelectorAll('.category-checkbox').forEach(cb => {
        cb.checked = activeCategoryIds.has(Number(cb.value));
    });
    
    document.getElementById('modalSelectedCount').textContent = selectedUsers.size;
    document.getElementById('categoryModal').classList.remove('hidden');
    document.body.style.overflow = 'hidden';
}

function closeCategoryModal() {
    document.getElementById('categoryModal').classList.add('hidden');
    document.body.style.overflow = '';
}

function selectAllCategories() {
    document.querySelectorAll('.category-checkbox').forEach(cb => {
        cb.checked = true;
    });
}

function deselectAllCategories() {
    document.querySelectorAll('.category-checkbox').forEach(cb => {
        cb.checked = false;
    });
}

// Close modal on Escape key
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeCategoryModal();
    }
});

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    updateSelection();
});
</script>
@endsection

