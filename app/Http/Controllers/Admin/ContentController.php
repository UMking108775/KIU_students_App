<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Content;
use Illuminate\Http\Request;

class ContentController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $query = Content::with('category');

        // Filter by category if provided
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        // Filter by content type if provided
        if ($request->filled('content_type')) {
            $query->where('content_type', $request->content_type);
        }

        // Filter by active status if provided
        if ($request->filled('is_active')) {
            $query->where('is_active', $request->is_active);
        }

        $contents = $query->orderBy('created_at', 'desc')->paginate(15);
        $categories = Category::where('is_active', true)->orderBy('title')->get();

        return view('admin.contents.index', compact('contents', 'categories'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        // Get all active categories (all levels)
        $categories = Category::where('is_active', true)
            ->orderBy('level')
            ->orderBy('title')
            ->get()
            ->map(function ($category) {
                $prefix = str_repeat('— ', $category->level - 1);
                return [
                    'id' => $category->id,
                    'title' => $prefix . $category->title . ' (Level ' . $category->level . ')',
                    'level' => $category->level,
                ];
            });

        return view('admin.contents.create', compact('categories'));
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'content_type' => 'required|in:pdf,audio',
            'backblaze_url' => 'required|url|max:500',
            'title' => 'required|string|max:255',
            'is_active' => 'boolean',
        ]);

        $validated['is_active'] = $request->has('is_active');

        Content::create($validated);

        return redirect()->route('admin.contents.index')
            ->with('success', 'Content created successfully!');
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        $content = Content::with('category')->findOrFail($id);
        return view('admin.contents.show', compact('content'));
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        $content = Content::findOrFail($id);
        
        // Get all active categories (all levels)
        $categories = Category::where('is_active', true)
            ->orderBy('level')
            ->orderBy('title')
            ->get()
            ->map(function ($category) {
                $prefix = str_repeat('— ', $category->level - 1);
                return [
                    'id' => $category->id,
                    'title' => $prefix . $category->title . ' (Level ' . $category->level . ')',
                    'level' => $category->level,
                ];
            });

        return view('admin.contents.edit', compact('content', 'categories'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $content = Content::findOrFail($id);

        $validated = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'content_type' => 'required|in:pdf,audio',
            'backblaze_url' => 'required|url|max:500',
            'title' => 'required|string|max:255',
            'is_active' => 'boolean',
        ]);

        $validated['is_active'] = $request->has('is_active');

        $content->update($validated);

        return redirect()->route('admin.contents.index')
            ->with('success', 'Content updated successfully!');
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        $content = Content::findOrFail($id);
        $content->delete();

        return redirect()->route('admin.contents.index')
            ->with('success', 'Content deleted successfully!');
    }
}
