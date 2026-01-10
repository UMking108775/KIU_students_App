@extends('admin.layouts.app')

@section('title', 'Manage Category Access')

@section('content')
<div class="max-w-7xl mx-auto">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-4">
        <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
                <a href="{{ route('admin.users.index') }}" class="text-gray-600 hover:text-gray-800">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                    </svg>
                </a>
                <div>
                    <h1 class="text-xl font-bold text-gray-800">Category Access Control</h1>
                    <p class="text-sm text-gray-600">
                        <span class="font-medium">{{ $user->name }}</span> 
                        <span class="text-gray-400">•</span> 
                        <span class="text-gray-500">{{ $user->kiu_id }}</span>
                    </p>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <span class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded">Total: {{ $mainCategories->count() }} main categories</span>
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-4 gap-4">
        <!-- Sidebar Controls -->
        <div class="lg:col-span-1">
            <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sticky top-4">
                <h3 class="font-semibold text-gray-800 mb-3 flex items-center">
                    <svg class="w-5 h-5 mr-2 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path>
                    </svg>
                    Quick Actions
                </h3>
                
                <div class="space-y-2 mb-4">
                    <button 
                        type="button" 
                        onclick="selectAll()"
                        class="w-full bg-green-600 hover:bg-green-700 text-white text-sm font-medium py-2 px-3 rounded-lg transition-colors flex items-center justify-center"
                    >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                        </svg>
                        Select All
                    </button>
                    
                    <button 
                        type="button" 
                        onclick="deselectAll()"
                        class="w-full bg-red-600 hover:bg-red-700 text-white text-sm font-medium py-2 px-3 rounded-lg transition-colors flex items-center justify-center"
                    >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                        </svg>
                        Deselect All
                    </button>
                </div>

                <div class="border-t border-gray-200 pt-3">
                    <h4 class="text-xs font-semibold text-gray-600 uppercase mb-2">Legend</h4>
                    <div class="space-y-2 text-xs">
                        <div class="flex items-center">
                            <span class="w-3 h-3 bg-blue-500 rounded mr-2"></span>
                            <span class="text-gray-700">Main Category</span>
                        </div>
                        <div class="flex items-center">
                            <span class="w-3 h-3 bg-green-500 rounded mr-2"></span>
                            <span class="text-gray-700">Sub Category</span>
                        </div>
                        <div class="flex items-center">
                            <span class="w-3 h-3 bg-purple-500 rounded mr-2"></span>
                            <span class="text-gray-700">3rd Level</span>
                        </div>
                    </div>
                </div>

                <div class="border-t border-gray-200 pt-3 mt-3">
                    <p class="text-xs text-gray-600">
                        <svg class="w-4 h-4 inline mr-1 text-yellow-600" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
                        </svg>
                        Unchecked categories will be hidden from user in the mobile app
                    </p>
                </div>
            </div>
        </div>

        <!-- Categories Form -->
        <div class="lg:col-span-3">
            <form method="POST" action="{{ route('admin.users.update-category-access', $user->id) }}" id="accessForm">
                @csrf
                @method('PUT')

                <div class="space-y-3">
                    @forelse($mainCategories as $mainCategory)
                    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
                        <!-- Level 1 - Main Category -->
                        <div class="bg-gradient-to-r from-blue-50 to-blue-100 border-b border-blue-200 p-3">
                            <label class="flex items-center cursor-pointer group">
                                    <input 
                                        type="checkbox" 
                                        name="categories[]" 
                                        value="{{ $mainCategory->id }}"
                                        id="category_{{ $mainCategory->id }}"
                                        class="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 cursor-pointer"
                                        {{ isset($userAccess[$mainCategory->id]) && $userAccess[$mainCategory->id] ? 'checked' : '' }}
                                        onchange="toggleChildren(this, 'level1_{{ $mainCategory->id }}')"
                                    >
                                <div class="ml-3 flex items-center flex-1 min-w-0">
                                    @if($mainCategory->image)
                                    <img src="{{ asset('storage/' . $mainCategory->image) }}" alt="{{ $mainCategory->title }}" class="w-10 h-10 rounded-lg object-cover mr-3 flex-shrink-0 border-2 border-blue-200">
                                    @else
                                    <div class="w-10 h-10 rounded-lg bg-blue-500 flex items-center justify-center mr-3 flex-shrink-0">
                                        <span class="text-white font-bold text-lg">{{ substr($mainCategory->title, 0, 1) }}</span>
                                    </div>
                                    @endif
                                    <div class="flex-1 min-w-0">
                                        <div class="flex items-center space-x-2">
                                            <span class="font-semibold text-gray-900 truncate">{{ $mainCategory->title }}</span>
                                            <span class="flex-shrink-0 text-xs bg-blue-600 text-white px-2 py-0.5 rounded-full font-medium">L1</span>
                                        </div>
                                        @if($mainCategory->children->count() > 0)
                                        <span class="text-xs text-gray-600">{{ $mainCategory->children->count() }} subcategories</span>
                                        @endif
                                    </div>
                                </div>
                            </label>
                        </div>

                        <!-- Level 2 & 3 - Sub Categories -->
                        @if($mainCategory->children->count() > 0)
                        <div class="p-3 level1_{{ $mainCategory->id }} bg-gray-50">
                            <div class="space-y-2">
                                @foreach($mainCategory->children as $subCategory)
                                <div class="bg-white rounded-md border border-gray-200 p-2">
                                    <label class="flex items-center cursor-pointer group">
                                            <input 
                                                type="checkbox" 
                                                name="categories[]" 
                                                value="{{ $subCategory->id }}"
                                                id="category_{{ $subCategory->id }}"
                                                class="w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-2 focus:ring-green-500 cursor-pointer"
                                                {{ isset($userAccess[$subCategory->id]) && $userAccess[$subCategory->id] ? 'checked' : '' }}
                                                onchange="toggleChildren(this, 'level2_{{ $subCategory->id }}')"
                                            >
                                        <div class="ml-2 flex items-center flex-1 min-w-0">
                                            @if($subCategory->image)
                                            <img src="{{ asset('storage/' . $subCategory->image) }}" alt="{{ $subCategory->title }}" class="w-7 h-7 rounded object-cover mr-2 flex-shrink-0">
                                            @else
                                            <div class="w-7 h-7 rounded bg-green-500 flex items-center justify-center mr-2 flex-shrink-0">
                                                <span class="text-white font-bold text-xs">{{ substr($subCategory->title, 0, 1) }}</span>
                                            </div>
                                            @endif
                                            <div class="flex-1 min-w-0 flex items-center space-x-2">
                                                <span class="text-sm font-medium text-gray-800 truncate">{{ $subCategory->title }}</span>
                                                <span class="flex-shrink-0 text-xs bg-green-600 text-white px-1.5 py-0.5 rounded-full font-medium">L2</span>
                                                @if($subCategory->children->count() > 0)
                                                <span class="flex-shrink-0 text-xs text-gray-500">({{ $subCategory->children->count() }})</span>
                                                @endif
                                            </div>
                                        </div>
                                    </label>

                                    <!-- Level 3 - 3rd Level Categories -->
                                    @if($subCategory->children->count() > 0)
                                    <div class="ml-6 mt-2 space-y-1 level2_{{ $subCategory->id }}">
                                        @foreach($subCategory->children as $thirdCategory)
                                        <label class="flex items-center cursor-pointer group hover:bg-purple-50 rounded p-1.5 transition-colors">
                                            <input 
                                                type="checkbox" 
                                                name="categories[]" 
                                                value="{{ $thirdCategory->id }}"
                                                id="category_{{ $thirdCategory->id }}"
                                                class="w-3.5 h-3.5 text-purple-600 border-gray-300 rounded focus:ring-2 focus:ring-purple-500 cursor-pointer"
                                                {{ isset($userAccess[$thirdCategory->id]) && $userAccess[$thirdCategory->id] ? 'checked' : '' }}
                                            >
                                            <div class="ml-2 flex items-center flex-1 min-w-0">
                                                @if($thirdCategory->image)
                                                <img src="{{ asset('storage/' . $thirdCategory->image) }}" alt="{{ $thirdCategory->title }}" class="w-6 h-6 rounded object-cover mr-2 flex-shrink-0">
                                                @else
                                                <div class="w-6 h-6 rounded bg-purple-500 flex items-center justify-center mr-2 flex-shrink-0">
                                                    <span class="text-white font-bold text-xs">{{ substr($thirdCategory->title, 0, 1) }}</span>
                                                </div>
                                                @endif
                                                <span class="text-xs text-gray-700 truncate">{{ $thirdCategory->title }}</span>
                                                <span class="ml-2 flex-shrink-0 text-xs bg-purple-600 text-white px-1.5 py-0.5 rounded-full font-medium">L3</span>
                                            </div>
                                        </label>
                                        @endforeach
                                    </div>
                                    @endif
                                </div>
                                @endforeach
                            </div>
                        </div>
                        @endif
                    </div>
                    @empty
                    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                        <svg class="w-16 h-16 text-gray-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path>
                        </svg>
                        <p class="text-gray-600 font-medium">No categories found</p>
                        <p class="text-sm text-gray-500 mt-1">Please create categories first before managing access</p>
                    </div>
                    @endforelse
                </div>

                @if($mainCategories->count() > 0)
                <!-- Sticky Bottom Bar -->
                <div class="sticky bottom-0 mt-4 bg-white rounded-lg shadow-lg border border-gray-200 p-4">
                    <div class="flex items-center justify-between">
                        <div class="text-sm text-gray-600">
                            <span id="selectedCount" class="font-semibold text-gray-900">0</span> categories selected
                        </div>
                        <div class="flex gap-2">
                            <a 
                                href="{{ route('admin.users.index') }}" 
                                class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                            >
                                Cancel
                            </a>
                            <button 
                                type="submit" 
                                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg text-sm font-medium transition-colors flex items-center"
                            >
                                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                </svg>
                                Save Changes
                            </button>
                        </div>
                    </div>
                </div>
                @endif
            </form>
        </div>
    </div>
</div>

<script>
function toggleChildren(checkbox, className) {
    const childrenContainer = document.querySelector('.' + className);
    if (childrenContainer) {
        const childCheckboxes = childrenContainer.querySelectorAll('input[type="checkbox"]');
        childCheckboxes.forEach(child => {
            child.checked = checkbox.checked;
        });
    }
    updateSelectedCount();
}

function selectAll() {
    document.querySelectorAll('input[type="checkbox"][name="categories[]"]').forEach(checkbox => {
        checkbox.checked = true;
    });
    updateSelectedCount();
}

function deselectAll() {
    document.querySelectorAll('input[type="checkbox"][name="categories[]"]').forEach(checkbox => {
        checkbox.checked = false;
    });
    updateSelectedCount();
}

function updateSelectedCount() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"][name="categories[]"]');
    const checkedCount = Array.from(checkboxes).filter(cb => cb.checked).length;
    const countElement = document.getElementById('selectedCount');
    if (countElement) {
        countElement.textContent = checkedCount;
    }
}

// Update count on page load and on any checkbox change
document.addEventListener('DOMContentLoaded', function() {
    updateSelectedCount();
    
    // Add change event to all checkboxes
    document.querySelectorAll('input[type="checkbox"][name="categories[]"]').forEach(checkbox => {
        checkbox.addEventListener('change', updateSelectedCount);
    });
});
</script>
@endsection

