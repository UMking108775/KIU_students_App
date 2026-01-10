@extends('admin.layouts.app')

@section('title', 'Edit FAQ')

@section('content')
<div class="max-w-3xl mx-auto">
    <div class="mb-6">
        <a href="{{ route('admin.faqs.index') }}" class="text-blue-600 hover:text-blue-800 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to FAQs
        </a>
    </div>

    <div class="bg-white rounded-lg shadow-md p-6">
        <h1 class="text-2xl font-bold text-gray-800 mb-6">Edit FAQ</h1>

        <form method="POST" action="{{ route('admin.faqs.update', $faq->id) }}">
            @csrf
            @method('PUT')

            <!-- Question -->
            <div class="mb-4">
                <label for="question" class="block text-sm font-medium text-gray-700 mb-2">Question *</label>
                <input 
                    type="text" 
                    name="question" 
                    id="question" 
                    value="{{ old('question', $faq->question) }}"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('question') border-red-500 @enderror"
                    placeholder="e.g., How do I download materials?"
                >
                @error('question')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Answer -->
            <div class="mb-4">
                <label for="answer" class="block text-sm font-medium text-gray-700 mb-2">Answer *</label>
                <textarea 
                    name="answer" 
                    id="answer" 
                    rows="6"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('answer') border-red-500 @enderror"
                    placeholder="Provide a detailed answer..."
                >{{ old('answer', $faq->answer) }}</textarea>
                @error('answer')
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
                    value="{{ old('order', $faq->order) }}"
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
                        {{ old('is_active', $faq->is_active) ? 'checked' : '' }}
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
                    Update FAQ
                </button>
                <a 
                    href="{{ route('admin.faqs.index') }}" 
                    class="bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Cancel
                </a>
            </div>
        </form>
    </div>
</div>
@endsection

