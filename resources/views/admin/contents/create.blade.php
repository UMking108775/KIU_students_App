@extends('admin.layouts.app')

@section('title', 'Add Content')
@section('page-title', 'Add Content')

@section('content')
<div class="max-w-3xl">
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">Add New Content</h2>

        <form action="{{ route('admin.contents.store') }}" method="POST" class="space-y-6">
            @csrf

            <!-- Category Selection -->
            <div>
                <label for="category_id" class="block text-sm font-medium text-gray-700 mb-2">
                    Select Category <span class="text-red-500">*</span>
                </label>
                <select 
                    id="category_id" 
                    name="category_id" 
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('category_id') border-red-500 @enderror"
                >
                    <option value="">Choose a category...</option>
                    @foreach($categories as $category)
                        <option value="{{ $category['id'] }}" {{ old('category_id') == $category['id'] ? 'selected' : '' }}>
                            {{ $category['title'] }}
                        </option>
                    @endforeach
                </select>
                <p class="mt-1 text-xs text-gray-500">You can select any category from level 1, 2, or 3</p>
                @error('category_id')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Content Type -->
            <div>
                <label for="content_type" class="block text-sm font-medium text-gray-700 mb-2">
                    Content Type <span class="text-red-500">*</span>
                </label>
                <div class="grid grid-cols-2 gap-4" id="content-type-container">
                    <label class="content-type-option relative flex items-center p-4 border-2 rounded-lg cursor-pointer transition-colors {{ old('content_type', 'pdf') == 'pdf' ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-blue-300' }}">
                        <input 
                            type="radio" 
                            name="content_type" 
                            value="pdf" 
                            {{ old('content_type', 'pdf') == 'pdf' ? 'checked' : '' }}
                            class="sr-only content-type-radio"
                            required
                        >
                        <div class="flex items-center">
                            <div class="bg-red-100 rounded-lg p-3 mr-3">
                                <svg class="w-6 h-6 text-red-600" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd"></path>
                                </svg>
                            </div>
                            <div>
                                <div class="font-medium text-gray-900">PDF</div>
                                <div class="text-sm text-gray-500">Document file</div>
                            </div>
                        </div>
                    </label>

                    <label class="content-type-option relative flex items-center p-4 border-2 rounded-lg cursor-pointer transition-colors {{ old('content_type') == 'audio' ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-blue-300' }}">
                        <input 
                            type="radio" 
                            name="content_type" 
                            value="audio" 
                            {{ old('content_type') == 'audio' ? 'checked' : '' }}
                            class="sr-only content-type-radio"
                            required
                        >
                        <div class="flex items-center">
                            <div class="bg-purple-100 rounded-lg p-3 mr-3">
                                <svg class="w-6 h-6 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                                    <path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"></path>
                                </svg>
                            </div>
                            <div>
                                <div class="font-medium text-gray-900">Audio</div>
                                <div class="text-sm text-gray-500">Audio file</div>
                            </div>
                        </div>
                    </label>
                </div>
                @error('content_type')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Backblaze URL -->
            <div>
                <label for="backblaze_url" class="block text-sm font-medium text-gray-700 mb-2">
                    Backblaze URL <span class="text-red-500">*</span>
                </label>
                <input 
                    type="url" 
                    id="backblaze_url" 
                    name="backblaze_url" 
                    value="{{ old('backblaze_url') }}"
                    required
                    placeholder="https://..."
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('backblaze_url') border-red-500 @enderror"
                >
                <p class="mt-1 text-xs text-gray-500">Enter the full Backblaze URL for the content file</p>
                @error('backblaze_url')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Title -->
            <div>
                <label for="title" class="block text-sm font-medium text-gray-700 mb-2">
                    Content Title <span class="text-red-500">*</span>
                </label>
                <input 
                    type="text" 
                    id="title" 
                    name="title" 
                    value="{{ old('title') }}"
                    required
                    placeholder="Enter content title"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('title') border-red-500 @enderror"
                >
                @error('title')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Active Status -->
            <div class="flex items-center">
                <input 
                    type="checkbox" 
                    id="is_active" 
                    name="is_active" 
                    value="1"
                    {{ old('is_active', true) ? 'checked' : '' }}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                >
                <label for="is_active" class="ml-2 block text-sm text-gray-700">
                    Active (Content will be visible in the app)
                </label>
            </div>

            <!-- Submit Buttons -->
            <div class="flex items-center justify-end space-x-4 pt-4 border-t border-gray-200">
                <a href="{{ route('admin.contents.index') }}" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                    Cancel
                </a>
                <button type="submit" class="px-6 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors">
                    Add Content
                </button>
            </div>
        </form>
    </div>
</div>

<script>
    // Handle content type radio button selection
    document.addEventListener('DOMContentLoaded', function() {
        const radioButtons = document.querySelectorAll('.content-type-radio');
        const options = document.querySelectorAll('.content-type-option');
        
        radioButtons.forEach(function(radio) {
            radio.addEventListener('change', function() {
                // Remove active styling from all options
                options.forEach(function(option) {
                    option.classList.remove('border-blue-500', 'bg-blue-50');
                    option.classList.add('border-gray-200');
                });
                
                // Add active styling to selected option
                const selectedOption = this.closest('.content-type-option');
                if (selectedOption) {
                    selectedOption.classList.add('border-blue-500', 'bg-blue-50');
                    selectedOption.classList.remove('border-gray-200');
                }
            });
        });
        
        // Initialize on page load
        radioButtons.forEach(function(radio) {
            if (radio.checked) {
                const selectedOption = radio.closest('.content-type-option');
                if (selectedOption) {
                    selectedOption.classList.add('border-blue-500', 'bg-blue-50');
                    selectedOption.classList.remove('border-gray-200');
                }
            }
        });
    });
</script>
@endsection

