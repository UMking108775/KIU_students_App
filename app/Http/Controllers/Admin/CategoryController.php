<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class CategoryController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $level = $request->get('level', 1);
        $parentId = $request->get('parent_id', null);

        $query = Category::query();

        if ($parentId) {
            $query->where('parent_id', $parentId);
            // Get the level from parent if not provided
            if (!$level) {
                $parent = Category::find($parentId);
                $level = $parent ? $parent->level + 1 : 1;
            }
        } else {
            $query->where('level', $level);
        }

        $categories = $query->with('parent', 'children')->orderBy('created_at', 'desc')->paginate(15);
        $parentCategory = $parentId ? Category::find($parentId) : null;

        return view('admin.categories.index', compact('categories', 'level', 'parentId', 'parentCategory'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create(Request $request)
    {
        $level = $request->get('level', 1);
        $parentId = $request->get('parent_id', null);

        $parentCategories = [];
        if ($level > 1) {
            $parentCategories = Category::where('level', $level - 1)->where('is_active', true)->get();
        }

        $parentCategory = $parentId ? Category::find($parentId) : null;

        return view('admin.categories.create', compact('level', 'parentId', 'parentCategories', 'parentCategory'));
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:2048',
            'parent_id' => 'nullable|exists:categories,id',
            'is_active' => 'boolean',
            'level' => 'required|integer|in:1,2,3',
        ]);

        // Determine level based on parent
        if ($request->filled('parent_id')) {
            $parent = Category::findOrFail($request->parent_id);
            $validated['level'] = $parent->level + 1;
        } else {
            $validated['level'] = 1;
        }

        // Handle image upload
        if ($request->hasFile('image')) {
            $validated['image'] = $request->file('image')->store('categories', 'public');
        }

        $validated['is_active'] = $request->has('is_active');

        $category = Category::create($validated);

        // Create automatic notification for new category
        if ($category->is_active) {
            $levelNames = [1 => 'Main Category', 2 => 'Sub Category', 3 => '3rd Level Category'];
            $levelName = $levelNames[$category->level] ?? 'Category';
            
            Notification::create([
                'title' => "New {$levelName} Added",
                'message' => "A new {$levelName} '{$category->title}' has been added. Check it out in the app!",
                'type' => 'success',
                'action_url' => null,
                'action_text' => null,
                'is_active' => true,
                'priority' => 15,
            ]);
        }

        $redirectParams = [];
        if ($request->filled('parent_id')) {
            $redirectParams['parent_id'] = $request->parent_id;
            $redirectParams['level'] = $validated['level'];
        } else {
            $redirectParams['level'] = 1;
        }

        return redirect()->route('admin.categories.index', $redirectParams)
            ->with('success', 'Category created successfully!');
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        $category = Category::with('parent', 'children')->findOrFail($id);
        return view('admin.categories.show', compact('category'));
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        $category = Category::findOrFail($id);
        $parentCategories = [];
        
        if ($category->level > 1) {
            $parentCategories = Category::where('level', $category->level - 1)
                ->where('is_active', true)
                ->where('id', '!=', $id)
                ->get();
        }

        return view('admin.categories.edit', compact('category', 'parentCategories'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $category = Category::findOrFail($id);

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:2048',
            'parent_id' => 'nullable|exists:categories,id',
            'is_active' => 'boolean',
        ]);

        // Handle image upload
        if ($request->hasFile('image')) {
            // Delete old image
            if ($category->image) {
                Storage::disk('public')->delete($category->image);
            }
            $validated['image'] = $request->file('image')->store('categories', 'public');
        }

        $validated['is_active'] = $request->has('is_active');

        // Update parent and level if changed
        if ($request->filled('parent_id') && $request->parent_id != $category->parent_id) {
            $parent = Category::findOrFail($request->parent_id);
            $validated['level'] = $parent->level + 1;
        } elseif (!$request->filled('parent_id') && $category->parent_id) {
            $validated['parent_id'] = null;
            $validated['level'] = 1;
        }

        $category->update($validated);

        $redirectParams = [];
        if ($category->parent_id) {
            $redirectParams['parent_id'] = $category->parent_id;
            $redirectParams['level'] = $category->level;
        } else {
            $redirectParams['level'] = 1;
        }

        return redirect()->route('admin.categories.index', $redirectParams)
            ->with('success', 'Category updated successfully!');
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        $category = Category::findOrFail($id);

        // Check if category has children
        if ($category->children()->count() > 0) {
            return redirect()->back()
                ->with('error', 'Cannot delete category with sub-categories. Please delete sub-categories first.');
        }

        // Delete image if exists
        if ($category->image) {
            Storage::disk('public')->delete($category->image);
        }

        $category->delete();

        return redirect()->back()->with('success', 'Category deleted successfully!');
    }
}
