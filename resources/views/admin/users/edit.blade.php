@extends('admin.layouts.app')

@section('title', 'Edit User')

@section('content')
<div class="max-w-3xl mx-auto">
    <div class="mb-6">
        <a href="{{ route('admin.users.index') }}" class="text-blue-600 hover:text-blue-800 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Users
        </a>
    </div>

    <div class="bg-white rounded-lg shadow-md p-6">
        <h1 class="text-2xl font-bold text-gray-800 mb-6">Edit User</h1>

        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
            <div class="flex">
                <svg class="w-5 h-5 text-blue-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
                </svg>
                <div class="text-sm text-blue-800">
                    <p><strong>Current Email:</strong> <code>{{ $user->email }}</code></p>
                    <p class="mt-1"><strong>Note:</strong> Changing KIU ID will update email to <code>{new_kiu_id}@kiu.student.app</code></p>
                </div>
            </div>
        </div>

        <form method="POST" action="{{ route('admin.users.update', $user->id) }}">
            @csrf
            @method('PUT')

            <!-- KIU ID -->
            <div class="mb-4">
                <label for="kiu_id" class="block text-sm font-medium text-gray-700 mb-2">KIU ID *</label>
                <input 
                    type="text" 
                    name="kiu_id" 
                    id="kiu_id" 
                    value="{{ old('kiu_id', $user->kiu_id) }}"
                    required
                    pattern="[0-9]+"
                    title="Please enter only numbers"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('kiu_id') border-red-500 @enderror"
                    placeholder="Enter KIU ID (numbers only)"
                >
                @error('kiu_id')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Name -->
            <div class="mb-4">
                <label for="name" class="block text-sm font-medium text-gray-700 mb-2">Name *</label>
                <input 
                    type="text" 
                    name="name" 
                    id="name" 
                    value="{{ old('name', $user->name) }}"
                    required
                    minlength="3"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('name') border-red-500 @enderror"
                    placeholder="Enter full name"
                >
                @error('name')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- WhatsApp Number -->
            <div class="mb-4">
                <label for="whatsapp_number" class="block text-sm font-medium text-gray-700 mb-2">WhatsApp Number *</label>
                <input 
                    type="text" 
                    name="whatsapp_number" 
                    id="whatsapp_number" 
                    value="{{ old('whatsapp_number', $user->whatsapp_number) }}"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('whatsapp_number') border-red-500 @enderror"
                    placeholder="e.g., +923001234567"
                >
                @error('whatsapp_number')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                <p class="text-sm text-blue-800">
                    <strong>Note:</strong> Leave password fields empty if you don't want to change the password.
                </p>
            </div>

            <!-- Password -->
            <div class="mb-4">
                <label for="password" class="block text-sm font-medium text-gray-700 mb-2">New Password (Optional)</label>
                <input 
                    type="password" 
                    name="password" 
                    id="password" 
                    minlength="6"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('password') border-red-500 @enderror"
                    placeholder="Enter new password (minimum 6 characters)"
                >
                @error('password')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Confirm Password -->
            <div class="mb-6">
                <label for="password_confirmation" class="block text-sm font-medium text-gray-700 mb-2">Confirm New Password</label>
                <input 
                    type="password" 
                    name="password_confirmation" 
                    id="password_confirmation" 
                    minlength="6"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="Re-enter new password"
                >
            </div>

            <!-- Submit Buttons -->
            <div class="flex gap-3">
                <button 
                    type="submit" 
                    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Update User
                </button>
                <a 
                    href="{{ route('admin.users.index') }}" 
                    class="bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-lg font-medium"
                >
                    Cancel
                </a>
            </div>
        </form>
    </div>
</div>
@endsection

