<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\FaqResource;
use App\Http\Resources\Api\SupportTicketResource;
use App\Models\Faq;
use App\Models\SupportTicket;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    use ApiResponse;

    /**
     * Get all active FAQs
     */
    public function faqs(Request $request)
    {
        try {
            $faqs = Faq::active()->ordered()->get();

            return $this->successResponse(
                [
                    'faqs' => FaqResource::collection($faqs),
                    'total' => $faqs->count(),
                ],
                'FAQs retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve FAQs',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Submit a support ticket/contact form
     */
    public function submit(Request $request)
    {
        try {
            $validated = $request->validate([
                'subject' => 'required|string|max:255',
                'message' => 'required|string|min:10',
            ]);

            $user = $request->user();

            $ticket = SupportTicket::create([
                'user_id' => $user->id,
                'subject' => $validated['subject'],
                'message' => $validated['message'],
                'status' => 'pending',
            ]);

            return $this->successResponse(
                new SupportTicketResource($ticket),
                'Your support request has been submitted successfully. We will respond soon!',
                201
            );

        } catch (\Illuminate\Validation\ValidationException $e) {
            return $this->validationErrorResponse($e->errors());
        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to submit support request',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get user's support tickets
     */
    public function myTickets(Request $request)
    {
        try {
            $user = $request->user();

            $tickets = SupportTicket::where('user_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->get();

            return $this->successResponse(
                [
                    'tickets' => SupportTicketResource::collection($tickets),
                    'total' => $tickets->count(),
                ],
                'Support tickets retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve support tickets',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get a specific support ticket
     */
    public function show(Request $request, $id)
    {
        try {
            $user = $request->user();

            $ticket = SupportTicket::where('user_id', $user->id)->findOrFail($id);

            return $this->successResponse(
                new SupportTicketResource($ticket),
                'Support ticket retrieved successfully'
            );

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFoundResponse('Support ticket not found');
        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve support ticket',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}

