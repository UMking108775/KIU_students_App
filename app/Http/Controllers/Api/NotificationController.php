<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\NotificationResource;
use App\Models\Notification;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    use ApiResponse;

    /**
     * Get all active and valid notifications
     */
    public function index(Request $request)
    {
        try {
            $limit = $request->input('limit', 50);
            $limit = min($limit, 100); // Max 100 notifications

            $notifications = Notification::active()
                ->valid()
                ->ordered()
                ->limit($limit)
                ->get();

            return $this->successResponse(
                [
                    'notifications' => NotificationResource::collection($notifications),
                    'total' => $notifications->count(),
                ],
                'Notifications retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve notifications',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get a specific notification by ID
     */
    public function show(Request $request, $id)
    {
        try {
            $notification = Notification::active()
                ->valid()
                ->find($id);

            if (!$notification) {
                return $this->notFoundResponse('Notification not found or expired');
            }

            return $this->successResponse(
                new NotificationResource($notification),
                'Notification retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve notification',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get unread notifications count (for badge)
     */
    public function count(Request $request)
    {
        try {
            $count = Notification::active()
                ->valid()
                ->count();

            return $this->successResponse(
                ['count' => $count],
                'Notification count retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve notification count',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}

