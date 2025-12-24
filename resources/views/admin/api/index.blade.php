@extends('admin.layouts.app')

@section('title', 'API Documentation')
@section('page-title', 'API Documentation')

@section('content')
<div class="space-y-6">
    <!-- Header -->
    <div class="bg-gradient-to-r from-blue-600 to-blue-700 rounded-lg shadow-lg p-6 text-white">
        <h2 class="text-3xl font-bold mb-2">Mobile App API Documentation</h2>
        <p class="text-blue-100">RESTful API endpoints for the KIU Students Material mobile application</p>
        <div class="mt-4 flex items-center space-x-4">
            <div class="bg-blue-800 bg-opacity-50 rounded-lg px-4 py-2">
                <div class="text-xs text-blue-200">Base URL</div>
                <div class="font-mono text-sm">{{ $baseUrl }}</div>
            </div>
            <div class="bg-blue-800 bg-opacity-50 rounded-lg px-4 py-2">
                <div class="text-xs text-blue-200">Version</div>
                <div class="font-mono text-sm">v1</div>
            </div>
            <div class="bg-blue-800 bg-opacity-50 rounded-lg px-4 py-2">
                <div class="text-xs text-blue-200">Format</div>
                <div class="font-mono text-sm">JSON</div>
            </div>
        </div>
    </div>

    <!-- Authentication Guide -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 class="text-xl font-bold text-gray-900 mb-4">🔐 Authentication</h3>
        <div class="space-y-3 text-sm">
            <p class="text-gray-700">Protected endpoints require authentication using Bearer tokens.</p>
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <div class="text-xs text-gray-500 mb-2">Authorization Header</div>
                <code class="text-sm text-gray-900">Authorization: Bearer {your_token_here}</code>
            </div>
            <div class="flex items-start space-x-2 text-gray-600">
                <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                <span>Tokens expire after 30 days</span>
            </div>
            <div class="flex items-start space-x-2 text-gray-600">
                <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                <span>Rate limit: 60 requests per minute for protected endpoints</span>
            </div>
        </div>
    </div>

    <!-- Authentication Endpoints -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <h3 class="text-lg font-bold text-gray-900">Authentication Endpoints</h3>
        </div>
        
        <div class="divide-y divide-gray-200">
            @foreach($endpoints['authentication'] as $endpoint)
                <div class="p-6 hover:bg-gray-50 transition-colors">
                    <!-- Endpoint Header -->
                    <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                            <span class="inline-flex items-center px-3 py-1 rounded-md text-xs font-bold
                                {{ $endpoint['method'] === 'GET' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800' }}">
                                {{ $endpoint['method'] }}
                            </span>
                            <code class="text-sm font-mono text-gray-900">{{ $endpoint['endpoint'] }}</code>
                        </div>
                        @if($endpoint['auth_required'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
                                </svg>
                                Auth Required
                            </span>
                        @else
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                Public
                            </span>
                        @endif
                    </div>

                    <!-- Description -->
                    <p class="text-sm text-gray-600 mb-4">{{ $endpoint['description'] }}</p>

                    <!-- Parameters -->
                    @if(count($endpoint['parameters']) > 0)
                        <div class="mb-4">
                            <div class="text-xs font-semibold text-gray-700 mb-2">Request Parameters</div>
                            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                                @foreach($endpoint['parameters'] as $param => $rules)
                                    <div class="flex items-start">
                                        <code class="text-xs font-mono text-blue-600 mr-2">{{ $param }}</code>
                                        <span class="text-xs text-gray-600">{{ $rules }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    <!-- Response Example -->
                    <div>
                        <div class="text-xs font-semibold text-gray-700 mb-2">Success Response (200/201)</div>
                        <div class="bg-gray-900 rounded-lg p-4 overflow-x-auto">
                            <pre class="text-xs text-green-400 font-mono">{{ json_encode($endpoint['response'], JSON_PRETTY_PRINT) }}</pre>
                        </div>
                    </div>

                    <!-- Test Button -->
                    <div class="mt-4 flex items-center space-x-2">
                        <button onclick="copyEndpoint('{{ $baseUrl }}{{ $endpoint['endpoint'] }}')" class="inline-flex items-center px-3 py-1.5 bg-gray-200 text-gray-700 text-xs font-medium rounded hover:bg-gray-300 transition-colors">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                            </svg>
                            Copy URL
                        </button>
                        <span class="text-xs text-gray-500">{{ $baseUrl }}{{ $endpoint['endpoint'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>

    <!-- Categories Endpoints -->
    @if(isset($endpoints['categories']))
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <h3 class="text-lg font-bold text-gray-900">Categories Endpoints</h3>
            <p class="text-sm text-gray-600 mt-1">Manage hierarchical categories (3 levels) with user access control</p>
        </div>
        
        <div class="divide-y divide-gray-200">
            @foreach($endpoints['categories'] as $endpoint)
                <div class="p-6 hover:bg-gray-50 transition-colors">
                    <!-- Endpoint Header -->
                    <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                            <span class="inline-flex items-center px-3 py-1 rounded-md text-xs font-bold
                                {{ $endpoint['method'] === 'GET' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800' }}">
                                {{ $endpoint['method'] }}
                            </span>
                            <code class="text-sm font-mono text-gray-900">{{ $endpoint['endpoint'] }}</code>
                        </div>
                        @if($endpoint['auth_required'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
                                </svg>
                                Auth Required
                            </span>
                        @else
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                Public
                            </span>
                        @endif
                    </div>

                    <!-- Description -->
                    <p class="text-sm text-gray-600 mb-4">{{ $endpoint['description'] }}</p>

                    <!-- Parameters -->
                    @if(count($endpoint['parameters']) > 0)
                        <div class="mb-4">
                            <div class="text-xs font-semibold text-gray-700 mb-2">Request Parameters</div>
                            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                                @foreach($endpoint['parameters'] as $param => $rules)
                                    <div class="flex items-start">
                                        <code class="text-xs font-mono text-blue-600 mr-2">{{ $param }}</code>
                                        <span class="text-xs text-gray-600">{{ $rules }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    <!-- Response Example -->
                    <div>
                        <div class="text-xs font-semibold text-gray-700 mb-2">Success Response (200)</div>
                        <div class="bg-gray-900 rounded-lg p-4 overflow-x-auto">
                            <pre class="text-xs text-green-400 font-mono">{{ json_encode($endpoint['response'], JSON_PRETTY_PRINT) }}</pre>
                        </div>
                    </div>

                    <!-- Test Button -->
                    <div class="mt-4 flex items-center space-x-2">
                        <button onclick="copyEndpoint('{{ $baseUrl }}{{ $endpoint['endpoint'] }}')" class="inline-flex items-center px-3 py-1.5 bg-gray-200 text-gray-700 text-xs font-medium rounded hover:bg-gray-300 transition-colors">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                            </svg>
                            Copy URL
                        </button>
                        <span class="text-xs text-gray-500">{{ $baseUrl }}{{ $endpoint['endpoint'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
    @endif

    <!-- Contents/Materials Endpoints -->
    @if(isset($endpoints['contents']))
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <h3 class="text-lg font-bold text-gray-900">Contents/Materials Endpoints</h3>
            <p class="text-sm text-gray-600 mt-1">Access study materials with automatic permission filtering (works for all 3 category levels)</p>
        </div>
        
        <div class="divide-y divide-gray-200">
            @foreach($endpoints['contents'] as $endpoint)
                <div class="p-6 hover:bg-gray-50 transition-colors">
                    <!-- Endpoint Header -->
                    <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                            <span class="inline-flex items-center px-3 py-1 rounded-md text-xs font-bold bg-blue-100 text-blue-800">
                                {{ $endpoint['method'] }}
                            </span>
                            <code class="text-sm font-mono text-gray-900">{{ $endpoint['endpoint'] }}</code>
                        </div>
                        @if($endpoint['auth_required'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
                                </svg>
                                Auth Required
                            </span>
                        @endif
                    </div>

                    <!-- Description -->
                    <p class="text-sm text-gray-600 mb-4">{{ $endpoint['description'] }}</p>

                    <!-- Parameters -->
                    @if(count($endpoint['parameters']) > 0)
                        <div class="mb-4">
                            <div class="text-xs font-semibold text-gray-700 mb-2">Request Parameters</div>
                            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                                @foreach($endpoint['parameters'] as $param => $rules)
                                    <div class="flex items-start">
                                        <code class="text-xs font-mono text-blue-600 mr-2">{{ $param }}</code>
                                        <span class="text-xs text-gray-600">{{ $rules }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    <!-- Response Example -->
                    <div>
                        <div class="text-xs font-semibold text-gray-700 mb-2">Success Response (200)</div>
                        <div class="bg-gray-900 rounded-lg p-4 overflow-x-auto">
                            <pre class="text-xs text-green-400 font-mono">{{ json_encode($endpoint['response'], JSON_PRETTY_PRINT) }}</pre>
                        </div>
                    </div>

                    <!-- Test Button -->
                    <div class="mt-4 flex items-center space-x-2">
                        <button onclick="copyEndpoint('{{ $baseUrl }}{{ $endpoint['endpoint'] }}')" class="inline-flex items-center px-3 py-1.5 bg-gray-200 text-gray-700 text-xs font-medium rounded hover:bg-gray-300 transition-colors">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                            </svg>
                            Copy URL
                        </button>
                        <span class="text-xs text-gray-500">{{ $baseUrl }}{{ $endpoint['endpoint'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
    @endif

    <!-- Support/Help Endpoints -->
    @if(isset($endpoints['support']))
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <h3 class="text-lg font-bold text-gray-900">Help & Support Endpoints</h3>
            <p class="text-sm text-gray-600 mt-1">FAQs and support ticket management for users</p>
        </div>
        
        <div class="divide-y divide-gray-200">
            @foreach($endpoints['support'] as $endpoint)
                <div class="p-6 hover:bg-gray-50 transition-colors">
                    <!-- Endpoint Header -->
                    <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                            <span class="inline-flex items-center px-3 py-1 rounded-md text-xs font-bold {{ $endpoint['method'] === 'GET' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800' }}">
                                {{ $endpoint['method'] }}
                            </span>
                            <code class="text-sm font-mono text-gray-900">{{ $endpoint['endpoint'] }}</code>
                        </div>
                        @if($endpoint['auth_required'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
                                </svg>
                                Auth Required
                            </span>
                        @endif
                    </div>

                    <!-- Description -->
                    <p class="text-sm text-gray-600 mb-4">{{ $endpoint['description'] }}</p>

                    <!-- Parameters -->
                    @if(count($endpoint['parameters']) > 0)
                        <div class="mb-4">
                            <div class="text-xs font-semibold text-gray-700 mb-2">Request Parameters</div>
                            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                                @foreach($endpoint['parameters'] as $param => $rules)
                                    <div class="flex items-start">
                                        <code class="text-xs font-mono text-blue-600 mr-2">{{ $param }}</code>
                                        <span class="text-xs text-gray-600">{{ $rules }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    <!-- Response Example -->
                    <div>
                        <div class="text-xs font-semibold text-gray-700 mb-2">Success Response (200/201)</div>
                        <div class="bg-gray-900 rounded-lg p-4 overflow-x-auto">
                            <pre class="text-xs text-green-400 font-mono">{{ json_encode($endpoint['response'], JSON_PRETTY_PRINT) }}</pre>
                        </div>
                    </div>

                    <!-- Test Button -->
                    <div class="mt-4 flex items-center space-x-2">
                        <button onclick="copyEndpoint('{{ $baseUrl }}{{ $endpoint['endpoint'] }}')" class="inline-flex items-center px-3 py-1.5 bg-gray-200 text-gray-700 text-xs font-medium rounded hover:bg-gray-300 transition-colors">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                            </svg>
                            Copy URL
                        </button>
                        <span class="text-xs text-gray-500">{{ $baseUrl }}{{ $endpoint['endpoint'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
    @endif

    <!-- Notifications Endpoints -->
    @if(isset($endpoints['notifications']))
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <h3 class="text-lg font-bold text-gray-900">Notifications Endpoints</h3>
            <p class="text-sm text-gray-600 mt-1">Fetch push notifications with scheduling and priority support</p>
        </div>
        
        <div class="divide-y divide-gray-200">
            @foreach($endpoints['notifications'] as $endpoint)
                <div class="p-6 hover:bg-gray-50 transition-colors">
                    <!-- Endpoint Header -->
                    <div class="flex items-start justify-between mb-4">
                        <div class="flex items-center space-x-3">
                            <span class="inline-flex items-center px-3 py-1 rounded-md text-xs font-bold bg-blue-100 text-blue-800">
                                {{ $endpoint['method'] }}
                            </span>
                            <code class="text-sm font-mono text-gray-900">{{ $endpoint['endpoint'] }}</code>
                        </div>
                        @if($endpoint['auth_required'])
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
                                </svg>
                                Auth Required
                            </span>
                        @endif
                    </div>

                    <!-- Description -->
                    <p class="text-sm text-gray-600 mb-4">{{ $endpoint['description'] }}</p>

                    <!-- Parameters -->
                    @if(count($endpoint['parameters']) > 0)
                        <div class="mb-4">
                            <div class="text-xs font-semibold text-gray-700 mb-2">Request Parameters</div>
                            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                                @foreach($endpoint['parameters'] as $param => $rules)
                                    <div class="flex items-start">
                                        <code class="text-xs font-mono text-blue-600 mr-2">{{ $param }}</code>
                                        <span class="text-xs text-gray-600">{{ $rules }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    <!-- Response Example -->
                    <div>
                        <div class="text-xs font-semibold text-gray-700 mb-2">Success Response (200)</div>
                        <div class="bg-gray-900 rounded-lg p-4 overflow-x-auto">
                            <pre class="text-xs text-green-400 font-mono">{{ json_encode($endpoint['response'], JSON_PRETTY_PRINT) }}</pre>
                        </div>
                    </div>

                    <!-- Test Button -->
                    <div class="mt-4 flex items-center space-x-2">
                        <button onclick="copyEndpoint('{{ $baseUrl }}{{ $endpoint['endpoint'] }}')" class="inline-flex items-center px-3 py-1.5 bg-gray-200 text-gray-700 text-xs font-medium rounded hover:bg-gray-300 transition-colors">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                            </svg>
                            Copy URL
                        </button>
                        <span class="text-xs text-gray-500">{{ $baseUrl }}{{ $endpoint['endpoint'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
    @endif

    <!-- Error Responses -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 class="text-xl font-bold text-gray-900 mb-4">⚠️ Error Responses</h3>
        <div class="space-y-4">
            <!-- 422 Validation Error -->
            <div>
                <div class="text-sm font-semibold text-gray-700 mb-2">422 - Validation Error</div>
                <div class="bg-gray-900 rounded-lg p-4">
                    <pre class="text-xs text-red-400 font-mono">{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "kiu_id": ["KIU ID is required"]
  }
}</pre>
                </div>
            </div>

            <!-- 401 Unauthorized -->
            <div>
                <div class="text-sm font-semibold text-gray-700 mb-2">401 - Unauthorized</div>
                <div class="bg-gray-900 rounded-lg p-4">
                    <pre class="text-xs text-red-400 font-mono">{
  "success": false,
  "message": "Invalid KIU ID or password"
}</pre>
                </div>
            </div>

            <!-- 500 Server Error -->
            <div>
                <div class="text-sm font-semibold text-gray-700 mb-2">500 - Server Error</div>
                <div class="bg-gray-900 rounded-lg p-4">
                    <pre class="text-xs text-red-400 font-mono">{
  "success": false,
  "message": "Internal server error"
}</pre>
                </div>
            </div>
        </div>
    </div>

    <!-- Best Practices -->
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 class="text-lg font-bold text-blue-900 mb-4">💡 Best Practices</h3>
        <ul class="space-y-2 text-sm text-blue-800">
            <li class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                Always include proper error handling in your mobile app
            </li>
            <li class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                Store tokens securely using encrypted storage
            </li>
            <li class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                Implement token refresh before expiry
            </li>
            <li class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                Handle rate limiting gracefully with exponential backoff
            </li>
            <li class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                Use HTTPS only for all API requests
            </li>
        </ul>
    </div>
</div>

<script>
function copyEndpoint(url) {
    navigator.clipboard.writeText(url).then(function() {
        alert('Endpoint URL copied to clipboard!');
    }, function(err) {
        console.error('Could not copy text: ', err);
    });
}
</script>
@endsection

