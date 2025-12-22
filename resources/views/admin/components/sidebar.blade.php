<aside id="sidebar" class="fixed inset-y-0 left-0 z-50 w-64 bg-gradient-to-b from-gray-900 to-gray-800 text-white transform transition-transform duration-300 ease-in-out lg:translate-x-0 -translate-x-full lg:static lg:inset-0 shadow-2xl">
    <div class="flex flex-col h-full">
        <!-- Logo -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-700">
            <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center shadow-lg">
                    <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
                    </svg>
                </div>
                <div>
                    <h1 class="text-lg font-bold">KIU Admin</h1>
                    <p class="text-xs text-gray-400">Material App</p>
                </div>
            </div>
            <button onclick="toggleSidebar()" class="lg:hidden text-gray-400 hover:text-white">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
            </button>
        </div>
        
        <!-- Navigation -->
        <nav class="flex-1 overflow-y-auto py-4 px-3">
            <!-- Dashboard -->
            <a href="{{ route('admin.dashboard') }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.dashboard') ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                </svg>
                <span class="text-sm font-medium">Dashboard</span>
            </a>
            
            <!-- Categories Section -->
            <div class="mt-6 mb-2">
                <div class="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Categories</div>
            </div>
            
            <a href="{{ route('admin.categories.index', ['level' => 1]) }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.categories.*') && request()->get('level') == 1 ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
                </svg>
                <span class="text-sm font-medium">Main</span>
                <span class="ml-auto text-xs bg-blue-500 text-white px-2 py-0.5 rounded-full">L1</span>
            </a>
            
            <a href="{{ route('admin.categories.index', ['level' => 2]) }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.categories.*') && request()->get('level') == 2 ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
                </svg>
                <span class="text-sm font-medium">Sub</span>
                <span class="ml-auto text-xs bg-green-500 text-white px-2 py-0.5 rounded-full">L2</span>
            </a>
            
            <a href="{{ route('admin.categories.index', ['level' => 3]) }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.categories.*') && request()->get('level') == 3 ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
                </svg>
                <span class="text-sm font-medium">3rd Level</span>
                <span class="ml-auto text-xs bg-purple-500 text-white px-2 py-0.5 rounded-full">L3</span>
            </a>
            
            <!-- Content Section -->
            <div class="mt-6 mb-2">
                <div class="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Content</div>
            </div>
            
            <a href="{{ route('admin.contents.index') }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.contents.*') ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                <span class="text-sm font-medium">Materials</span>
            </a>
            
            <!-- Users Section -->
            <div class="mt-6 mb-2">
                <div class="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Management</div>
            </div>
            
            <a href="{{ route('admin.users.index') }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.users.*') ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
                </svg>
                <span class="text-sm font-medium">Users</span>
            </a>
            
            <!-- API Section -->
            <div class="mt-6 mb-2">
                <div class="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Developer</div>
            </div>
            
            <a href="{{ route('admin.api.index') }}" class="flex items-center px-3 py-2.5 mb-1 rounded-lg transition-all {{ request()->routeIs('admin.api.*') ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-300 hover:bg-gray-700 hover:text-white' }}">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
                </svg>
                <span class="text-sm font-medium">API Docs</span>
            </a>
        </nav>
        
        <!-- User Info -->
        <div class="border-t border-gray-700 p-4">
            <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white font-bold shadow-lg">
                    {{ substr(Auth::user()->name, 0, 1) }}
                </div>
                <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-white truncate">{{ Auth::user()->name }}</p>
                    <p class="text-xs text-gray-400 truncate">{{ Auth::user()->email }}</p>
                </div>
                <form method="POST" action="{{ route('admin.logout') }}" class="inline">
                    @csrf
                    <button type="submit" class="text-gray-400 hover:text-red-400 transition-colors" title="Logout">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                        </svg>
                    </button>
                </form>
            </div>
        </div>
    </div>
</aside>

<!-- Overlay for mobile -->
<div id="sidebar-overlay" class="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden hidden" onclick="toggleSidebar()" style="display: none;"></div>

<script>
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebar-overlay');
    const isHidden = sidebar.classList.contains('-translate-x-full');
    
    if (isHidden) {
        sidebar.classList.remove('-translate-x-full');
        overlay.style.display = 'block';
    } else {
        sidebar.classList.add('-translate-x-full');
        overlay.style.display = 'none';
    }
}
</script>
