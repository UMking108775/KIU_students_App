<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    /**
     * Display a listing of support tickets.
     */
    public function index(Request $request)
    {
        $status = $request->get('status', 'all');
        $search = $request->get('search');

        $query = SupportTicket::with(['user', 'responder']);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('subject', 'like', "%{$search}%")
                  ->orWhere('message', 'like', "%{$search}%")
                  ->orWhereHas('user', function ($userQuery) use ($search) {
                      $userQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('kiu_id', 'like', "%{$search}%");
                  });
            });
        }

        $tickets = $query->orderBy('created_at', 'desc')->paginate(15);

        $stats = [
            'all' => SupportTicket::count(),
            'pending' => SupportTicket::where('status', 'pending')->count(),
            'in_progress' => SupportTicket::where('status', 'in_progress')->count(),
            'resolved' => SupportTicket::where('status', 'resolved')->count(),
        ];

        return view('admin.support.index', compact('tickets', 'status', 'search', 'stats'));
    }

    /**
     * Display the specified support ticket.
     */
    public function show(string $id)
    {
        $ticket = SupportTicket::with(['user', 'responder'])->findOrFail($id);
        return view('admin.support.show', compact('ticket'));
    }

    /**
     * Update ticket status and add admin response.
     */
    public function update(Request $request, string $id)
    {
        $ticket = SupportTicket::findOrFail($id);

        $validated = $request->validate([
            'status' => 'required|in:pending,in_progress,resolved,closed',
            'admin_response' => 'required|string',
        ]);

        $validated['responded_at'] = now();
        $validated['responded_by'] = auth()->id();

        $ticket->update($validated);

        return redirect()->route('admin.support.show', $ticket->id)
            ->with('success', 'Response sent successfully!');
    }

    /**
     * Update only ticket status.
     */
    public function updateStatus(Request $request, string $id)
    {
        $ticket = SupportTicket::findOrFail($id);

        $validated = $request->validate([
            'status' => 'required|in:pending,in_progress,resolved,closed',
        ]);

        $ticket->update($validated);

        return redirect()->back()
            ->with('success', 'Ticket status updated successfully!');
    }
}

