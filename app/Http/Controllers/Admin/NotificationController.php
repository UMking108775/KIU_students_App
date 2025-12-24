<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * Display a listing of notifications.
     */
    public function index(Request $request)
    {
        $status = $request->get('status', 'all');
        $type = $request->get('type', 'all');

        $query = Notification::query();

        if ($status === 'active') {
            $query->where('is_active', true);
        } elseif ($status === 'inactive') {
            $query->where('is_active', false);
        }

        if ($type !== 'all') {
            $query->where('type', $type);
        }

        $notifications = $query->ordered()->paginate(15);

        $stats = [
            'all' => Notification::count(),
            'active' => Notification::where('is_active', true)->count(),
            'inactive' => Notification::where('is_active', false)->count(),
        ];

        return view('admin.notifications.index', compact('notifications', 'status', 'type', 'stats'));
    }

    /**
     * Show the form for creating a new notification.
     */
    public function create()
    {
        return view('admin.notifications.create');
    }

    /**
     * Store a newly created notification.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'type' => 'required|in:info,success,warning,error,announcement',
            'action_url' => 'nullable|url|max:255',
            'action_text' => 'nullable|string|max:50',
            'is_active' => 'boolean',
            'scheduled_at' => 'nullable|date|after_or_equal:now',
            'expires_at' => 'nullable|date|after:scheduled_at',
            'priority' => 'nullable|integer|min:0|max:100',
        ]);

        $validated['is_active'] = $request->has('is_active');
        $validated['priority'] = $validated['priority'] ?? 0;

        Notification::create($validated);

        return redirect()->route('admin.notifications.index')
            ->with('success', 'Notification created successfully!');
    }

    /**
     * Show the form for editing the specified notification.
     */
    public function edit(string $id)
    {
        $notification = Notification::findOrFail($id);
        return view('admin.notifications.edit', compact('notification'));
    }

    /**
     * Update the specified notification.
     */
    public function update(Request $request, string $id)
    {
        $notification = Notification::findOrFail($id);

        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'type' => 'required|in:info,success,warning,error,announcement',
            'action_url' => 'nullable|url|max:255',
            'action_text' => 'nullable|string|max:50',
            'is_active' => 'boolean',
            'scheduled_at' => 'nullable|date',
            'expires_at' => 'nullable|date|after:scheduled_at',
            'priority' => 'nullable|integer|min:0|max:100',
        ]);

        $validated['is_active'] = $request->has('is_active');
        $validated['priority'] = $validated['priority'] ?? $notification->priority;

        $notification->update($validated);

        return redirect()->route('admin.notifications.index')
            ->with('success', 'Notification updated successfully!');
    }

    /**
     * Remove the specified notification.
     */
    public function destroy(string $id)
    {
        $notification = Notification::findOrFail($id);
        $notification->delete();

        return redirect()->route('admin.notifications.index')
            ->with('success', 'Notification deleted successfully!');
    }
}

