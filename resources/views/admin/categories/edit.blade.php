@extends('admin.layouts.app')

@section('title', 'Edit Category')
@section('page-title', 'Edit Category')

@section('content')
<div class="max-w-3xl">
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">Edit Category</h2>

        <form action="{{ route('admin.categories.update', $category->id) }}" method="POST" enctype="multipart/form-data" class="space-y-6">
            @csrf
            @method('PUT')

            <!-- Title -->
            <div>
                <label for="title" class="block text-sm font-medium text-gray-700 mb-2">
                    Category Title <span class="text-red-500">*</span>
                </label>
                <input 
                    type="text" 
                    id="title" 
                    name="title" 
                    value="{{ old('title', $category->title) }}"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('title') border-red-500 @enderror"
                    placeholder="Enter category title"
                >
                @error('title')
                    <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                @enderror
            </div>

            <!-- Parent Category (if level > 1) -->
            @if($category->level > 1 && count($parentCategories) > 0)
                <div>
                    <label for="parent_id" class="block text-sm font-medium text-gray-700 mb-2">
                        Parent Category
                    </label>
                    <select 
                        id="parent_id" 
                        name="parent_id" 
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent @error('parent_id') border-red-500 @enderror"
                    >
                        <option value="">Select Parent Category</option>
                        @foreach($parentCategories as $parent)
                            <option value="{{ $parent->id }}" {{ old('parent_id', $category->parent_id) == $parent->id ? 'selected' : '' }}>
                                {{ $parent->title }}
                            </option>
                        @endforeach
                    </select>
                    @error('parent_id')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            @endif

            <!-- Current Image -->
            @if($category->image)
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Current Image</label>
                    <img src="{{ asset('storage/' . $category->image) }}" alt="{{ $category->title }}" class="w-32 h-32 object-cover rounded-lg border border-gray-300">
                </div>
            @endif

            <!-- New Image -->
            <div>
                <label for="image" class="block text-sm font-medium text-gray-700 mb-2">
                    {{ $category->image ? 'Replace Image' : 'Category Image' }}
                </label>
                <div class="mt-1 flex items-center space-x-5">
                    <div class="flex-1">
                        <input 
                            type="file" 
                            id="image" 
                            name="image" 
                            accept="image/*"
                            onchange="previewImage(this)"
                            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                        >
                        <p class="mt-1 text-xs text-gray-500">PNG, JPG, GIF or WEBP (Max. 2MB)</p>
                    </div>
                    <div id="imagePreview" class="hidden">
                        <img id="preview" src="" alt="Preview" class="w-32 h-32 object-cover rounded-lg border border-gray-300">
                    </div>
                </div>
                @error('image')
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
                    {{ old('is_active', $category->is_active) ? 'checked' : '' }}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                >
                <label for="is_active" class="ml-2 block text-sm text-gray-700">
                    Active (Category will be visible in the app)
                </label>
            </div>

            <!-- Submit Buttons -->
            <div class="flex items-center justify-end space-x-4 pt-4 border-t border-gray-200">
                <a href="{{ route('admin.categories.index', ['level' => $category->level, 'parent_id' => $category->parent_id]) }}" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                    Cancel
                </a>
                <button type="submit" class="px-6 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors">
                    Update Category
                </button>
            </div>
        </form>
    </div>
</div>

<script>
    function previewImage(input) {
        const preview = document.getElementById('preview');
        const previewDiv = document.getElementById('imagePreview');
        
        if (input.files && input.files[0]) {
            const reader = new FileReader();
            
            reader.onload = function(e) {
                preview.src = e.target.result;
                previewDiv.classList.remove('hidden');
            }
            
            reader.readAsDataURL(input.files[0]);
        } else {
            previewDiv.classList.add('hidden');
        }
    }
</script>
@endsection

