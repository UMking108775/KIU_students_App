@extends('admin.layouts.app')

@section('title', 'Edit Notification')

@section('content')
<div class="max-w-3xl mx-auto">
    <div class="mb-6">
        <a href="{{ route('admin.notifications.index') }}" class="text-blue-600 hover:text-blue-800 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Notifications
        </a>
    </div>

    <div class="bg-white rounded-lg shadow-md p-6">
        <h1 class="text-2xl font-bold text-gray-800 mb-6">Edit Notification</h1>

        <form method="POST" action="{{ route('admin.notifications.update', $notification->id) }}">
            @csrf
            @method('PUT')

            <!-- Title -->
            <div class="mb-4">
                <label for="title" class="block text-sm font-medium text-gray-700 mb-2">Title *</label>
                <input 
                    type="text" 
                    name="title" 
                    id="title" 
                    value="{{ old('title', $notification->title) }}"
                    required
                    maxlength="255"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('title') border-red-500 @enderror"
                    placeholder="e.g., New Study Material Available"
                >
                @error('title')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Message -->
            <div class="mb-4">
                <label for="message" class="block text-sm font-medium text-gray-700 mb-2">Message *</label>
                <textarea 
                    name="message" 
                    id="message" 
                    rows="5"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('message') border-red-500 @enderror"
                    placeholder="Enter the notification message..."
                >{{ old('message', $notification->message) }}</textarea>
                @error('message')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Type and Priority -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <!-- Type -->
                <div>
                    <label for="type" class="block text-sm font-medium text-gray-700 mb-2">Type *</label>
                    <select name="type" id="type" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('type') border-red-500 @enderror">
                        <option value="info" {{ old('type', $notification->type) === 'info' ? 'selected' : '' }}>Info (Blue)</option>
                        <option value="success" {{ old('type', $notification->type) === 'success' ? 'selected' : '' }}>Success (Green)</option>
                        <option value="warning" {{ old('type', $notification->type) === 'warning' ? 'selected' : '' }}>Warning (Yellow)</option>
                        <option value="error" {{ old('type', $notification->type) === 'error' ? 'selected' : '' }}>Error (Red)</option>
                        <option value="announcement" {{ old('type', $notification->type) === 'announcement' ? 'selected' : '' }}>Announcement (Purple)</option>
                    </select>
                    @error('type')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <!-- Priority -->
                <div>
                    <label for="priority" class="block text-sm font-medium text-gray-700 mb-2">Priority</label>
                    <input 
                        type="number" 
                        name="priority" 
                        id="priority" 
                        value="{{ old('priority', $notification->priority) }}"
                        min="0"
                        max="100"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('priority') border-red-500 @enderror"
                        placeholder="0 (default)"
                    >
                    <p class="mt-1 text-xs text-gray-500">0-100, higher = appears first</p>
                    @error('priority')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            </div>

            <!-- Action URL and Text -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <!-- Action URL -->
                <div>
                    <label for="action_url" class="block text-sm font-medium text-gray-700 mb-2">Action URL (Optional)</label>
                    <input 
                        type="url" 
                        name="action_url" 
                        id="action_url" 
                        value="{{ old('action_url', $notification->action_url) }}"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('action_url') border-red-500 @enderror"
                        placeholder="https://example.com/page"
                    >
                    <p class="mt-1 text-xs text-gray-500">URL to open when user taps notification</p>
                    @error('action_url')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <!-- Action Text -->
                <div>
                    <label for="action_text" class="block text-sm font-medium text-gray-700 mb-2">Action Button Text (Optional)</label>
                    <input 
                        type="text" 
                        name="action_text" 
                        id="action_text" 
                        value="{{ old('action_text', $notification->action_text) }}"
                        maxlength="50"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('action_text') border-red-500 @enderror"
                        placeholder="e.g., View Details"
                    >
                    <p class="mt-1 text-xs text-gray-500">Button text for action (max 50 chars)</p>
                    @error('action_text')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            </div>

            <!-- Schedule -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <!-- Scheduled At -->
                <div>
                    <label for="scheduled_at" class="block text-sm font-medium text-gray-700 mb-2">Schedule For (Optional)</label>
                    <input 
                        type="datetime-local" 
                        name="scheduled_at" 
                        id="scheduled_at" 
                        value="{{ old('scheduled_at', $notification->scheduled_at ? $notification->scheduled_at->format('Y-m-d\TH:i') : '') }}"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('scheduled_at') border-red-500 @enderror"
                    >
                    <p class="mt-1 text-xs text-gray-500">Leave empty to send immediately</p>
                    @error('scheduled_at')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <!-- Expires At -->
                <div>
                    <label for="expires_at" class="block text-sm font-medium text-gray-700 mb-2">Expires At (Optional)</label>
                    <input 
                        type="datetime-local" 
                        name="expires_at" 
                        id="expires_at" 
                        value="{{ old('expires_at', $notification->expires_at ? $notification->expires_at->format('Y-m-d\TH:i') : '') }}"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('expires_at') border-red-500 @enderror"
                    >
                    <p class="mt-1 text-xs text-gray-500">Notification will expire after this date</p>
                    @error('expires_at')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            </div>

            <!-- Active Status -->
            <div class="mb-6">
                <label class="flex items-center">
                    <input 
                        type="checkbox" 
                        name="is_active" 
                        value="1"
                        {{ old('is_active', $notification->is_active) ? 'checked' : '' }}
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
                    Update Notification
                </button>
                <a 
                    href="{{ route('admin.notifications.index') }}" 
                    class="bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Cancel
                </a>
            </div>
        </form>
    </div>
</div>
@endsection

