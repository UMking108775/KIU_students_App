@extends('admin.layouts.app')

@section('title', 'Support Ticket Details')

@section('content')
<div class="max-w-4xl mx-auto space-y-6">
    <!-- Back Button -->
    <div>
        <a href="{{ route('admin.support.index') }}" class="text-blue-600 hover:text-blue-800 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Back to Tickets
        </a>
    </div>

    <!-- Ticket Details -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <!-- Header -->
        <div class="flex items-start justify-between mb-6 pb-6 border-b border-gray-200">
            <div>
                <h1 class="text-2xl font-bold text-gray-900">{{ $ticket->subject }}</h1>
                <div class="flex items-center gap-4 mt-2">
                    @if($ticket->status === 'pending')
                    <span class="px-3 py-1 text-sm font-medium rounded-full bg-yellow-100 text-yellow-800">Pending</span>
                    @elseif($ticket->status === 'in_progress')
                    <span class="px-3 py-1 text-sm font-medium rounded-full bg-blue-100 text-blue-800">In Progress</span>
                    @elseif($ticket->status === 'resolved')
                    <span class="px-3 py-1 text-sm font-medium rounded-full bg-green-100 text-green-800">Resolved</span>
                    @else
                    <span class="px-3 py-1 text-sm font-medium rounded-full bg-gray-100 text-gray-800">Closed</span>
                    @endif
                    <span class="text-sm text-gray-500">{{ $ticket->created_at->format('M d, Y \a\t h:i A') }}</span>
                </div>
            </div>
        </div>

        <!-- User Info -->
        <div class="mb-6 pb-6 border-b border-gray-200">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">User Information</h3>
            <div class="bg-gray-50 rounded-lg p-4">
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <p class="text-xs text-gray-500">Name</p>
                        <p class="text-sm font-medium text-gray-900">{{ $ticket->user->name }}</p>
                    </div>
                    <div>
                        <p class="text-xs text-gray-500">KIU ID</p>
                        <p class="text-sm font-medium text-gray-900">{{ $ticket->user->kiu_id }}</p>
                    </div>
                    <div>
                        <p class="text-xs text-gray-500">WhatsApp</p>
                        <p class="text-sm font-medium text-gray-900">{{ $ticket->user->whatsapp_number }}</p>
                    </div>
                    <div>
                        <p class="text-xs text-gray-500">Email</p>
                        <p class="text-sm font-medium text-gray-900">{{ $ticket->user->email }}</p>
                    </div>
                </div>
            </div>
        </div>

        <!-- User Message -->
        <div class="mb-6">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">User's Message</h3>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p class="text-gray-900 whitespace-pre-wrap">{{ $ticket->message }}</p>
            </div>
        </div>

        <!-- Admin Response Section -->
        @if($ticket->admin_response)
        <div class="mb-6">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">
                Admin Response
                @if($ticket->responder)
                <span class="text-xs text-gray-500 font-normal">(by {{ $ticket->responder->name }})</span>
                @endif
            </h3>
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                <p class="text-gray-900 whitespace-pre-wrap">{{ $ticket->admin_response }}</p>
                <p class="text-xs text-gray-500 mt-2">Responded on: {{ $ticket->responded_at->format('M d, Y \a\t h:i A') }}</p>
            </div>
        </div>
        @endif

        <!-- Response Form -->
        <div class="border-t border-gray-200 pt-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">
                @if($ticket->admin_response) Update Response @else Send Response @endif
            </h3>
            
            <form method="POST" action="{{ route('admin.support.update', $ticket->id) }}">
                @csrf
                @method('PUT')

                <!-- Status -->
                <div class="mb-4">
                    <label for="status" class="block text-sm font-medium text-gray-700 mb-2">Status *</label>
                    <select name="status" id="status" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
                        <option value="pending" {{ $ticket->status === 'pending' ? 'selected' : '' }}>Pending</option>
                        <option value="in_progress" {{ $ticket->status === 'in_progress' ? 'selected' : '' }}>In Progress</option>
                        <option value="resolved" {{ $ticket->status === 'resolved' ? 'selected' : '' }}>Resolved</option>
                        <option value="closed" {{ $ticket->status === 'closed' ? 'selected' : '' }}>Closed</option>
                    </select>
                </div>

                <!-- Admin Response -->
                <div class="mb-4">
                    <label for="admin_response" class="block text-sm font-medium text-gray-700 mb-2">Response *</label>
                    <textarea 
                        name="admin_response" 
                        id="admin_response" 
                        rows="6"
                        required
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="Type your response to the user..."
                    >{{ old('admin_response', $ticket->admin_response) }}</textarea>
                </div>

                <!-- Submit Button -->
                <button 
                    type="submit" 
                    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium"
                >
                    @if($ticket->admin_response) Update Response @else Send Response @endif
                </button>
            </form>
        </div>
    </div>
</div>
@endsection

