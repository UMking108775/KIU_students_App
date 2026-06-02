@extends('admin.layouts.app')

@section('title', 'Add Important Link')

@section('content')
<div class="max-w-3xl mx-auto">
    <div class="mb-6">
        <a href="{{ route('admin.important-links.index') }}" class="text-blue-600 hover:text-blue-800 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Important Links
        </a>
    </div>

    <div class="bg-white rounded-lg shadow-md p-6">
        <h1 class="text-2xl font-bold text-gray-800 mb-6">Add New Important Link</h1>

        <form method="POST" action="{{ route('admin.important-links.store') }}">
            @csrf

            <!-- Title -->
            <div class="mb-4">
                <label for="title" class="block text-sm font-medium text-gray-700 mb-2">Title *</label>
                <input 
                    type="text" 
                    name="title" 
                    id="title" 
                    value="{{ old('title') }}"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('title') border-red-500 @enderror"
                    placeholder="e.g., Campus Tour Video"
                >
                @error('title')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Video Link -->
            <div class="mb-4">
                <label for="video_link" class="block text-sm font-medium text-gray-700 mb-2">Video Link *</label>
                <input 
                    type="url" 
                    name="video_link" 
                    id="video_link" 
                    value="{{ old('video_link') }}"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('video_link') border-red-500 @enderror"
                    placeholder="https://www.youtube.com/watch?v=..."
                >
                <p class="mt-1 text-xs text-gray-500">Enter a valid URL (supports YouTube, Vimeo, and other platforms)</p>
                @error('video_link')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Description -->
            <div class="mb-4">
                <label for="description" class="block text-sm font-medium text-gray-700 mb-2">Description *</label>
                <textarea 
                    name="description" 
                    id="description" 
                    rows="6"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('description') border-red-500 @enderror"
                    placeholder="Provide a detailed description of the video content..."
                >{{ old('description') }}</textarea>
                @error('description')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Order -->
            <div class="mb-4">
                <label for="order" class="block text-sm font-medium text-gray-700 mb-2">Display Order</label>
                <input 
                    type="number" 
                    name="order" 
                    id="order" 
                    value="{{ old('order', 0) }}"
                    min="0"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('order') border-red-500 @enderror"
                    placeholder="0"
                >
                <p class="mt-1 text-xs text-gray-500">Lower numbers appear first. Default is 0.</p>
                @error('order')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Active Status -->
            <div class="mb-6">
                <label class="flex items-center">
                    <input 
                        type="checkbox" 
                        name="is_active" 
                        value="1"
                        {{ old('is_active', true) ? 'checked' : '' }}
                        class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                    >
                    <span class="ml-2 text-sm text-gray-700">Active (visible in mobile app)</span>
                </label>
            </div>

            <!-- Submit Buttons -->
            <div class="flex gap-3">
                <button 
                    type="submit" 
                    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Create Link
                </button>
                <a 
                    href="{{ route('admin.important-links.index') }}" 
                    class="bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Cancel
                </a>
            </div>
        </form>
    </div>
</div>
@endsection
