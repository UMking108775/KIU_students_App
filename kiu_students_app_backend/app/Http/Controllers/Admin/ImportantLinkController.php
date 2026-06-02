<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ImportantLink;
use Illuminate\Http\Request;

class ImportantLinkController extends Controller
{
    /**
     * Display a listing of important links.
     */
    public function index()
    {
        $links = ImportantLink::orderBy('order')->orderBy('created_at', 'desc')->paginate(15);
        return view('admin.important-links.index', compact('links'));
    }

    /**
     * Show the form for creating a new important link.
     */
    public function create()
    {
        return view('admin.important-links.create');
    }

    /**
     * Store a newly created important link.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'video_link' => 'required|url',
            'description' => 'required|string',
            'order' => 'nullable|integer|min:0',
            'is_active' => 'boolean',
        ]);

        $validated['is_active'] = $request->has('is_active');
        $validated['order'] = $validated['order'] ?? 0;

        ImportantLink::create($validated);

        return redirect()->route('admin.important-links.index')
            ->with('success', 'Important link created successfully!');
    }

    /**
     * Show the form for editing the specified important link.
     */
    public function edit(string $id)
    {
        $link = ImportantLink::findOrFail($id);
        return view('admin.important-links.edit', compact('link'));
    }

    /**
     * Update the specified important link.
     */
    public function update(Request $request, string $id)
    {
        $link = ImportantLink::findOrFail($id);

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'video_link' => 'required|url',
            'description' => 'required|string',
            'order' => 'nullable|integer|min:0',
            'is_active' => 'boolean',
        ]);

        $validated['is_active'] = $request->has('is_active');
        $validated['order'] = $validated['order'] ?? $link->order;

        $link->update($validated);

        return redirect()->route('admin.important-links.index')
            ->with('success', 'Important link updated successfully!');
    }

    /**
     * Remove the specified important link.
     */
    public function destroy(string $id)
    {
        $link = ImportantLink::findOrFail($id);
        $link->delete();

        return redirect()->route('admin.important-links.index')
            ->with('success', 'Important link deleted successfully!');
    }
}
