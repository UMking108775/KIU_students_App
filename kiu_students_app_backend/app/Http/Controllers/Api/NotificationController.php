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
            $user = $request->user();
            $limit = $request->input('limit', 50);
            $limit = min($limit, 100); // Max 100 notifications

            $accessibleCategoryIds = $user ? $user->accessibleCategories()->pluck('categories.id')->toArray() : [];

            $notifications = Notification::active()
                ->valid()
                ->where(function($q) use ($accessibleCategoryIds) {
                    $q->whereNull('category_id');
                    if (!empty($accessibleCategoryIds)) {
                        $q->orWhereIn('category_id', $accessibleCategoryIds);
                    }
                })
                ->ordered()
                ->limit($limit)
                ->get();

            // Eager load user's read status for all notifications to avoid N+1 queries
            if ($user) {
                // Get all user's notification relationships with read status and read_at
                $userNotifications = $user->notifications()
                    ->whereIn('notification_id', $notifications->pluck('id'))
                    ->get()
                    ->keyBy('id');
                
                // Attach read status to each notification
                $notifications->each(function ($notification) use ($userNotifications) {
                    $userNotification = $userNotifications->get($notification->id);
                    if ($userNotification && $userNotification->pivot->is_read) {
                        $notification->is_read_by_user = true;
                        $notification->read_at_by_user = $userNotification->pivot->read_at;
                    } else {
                        $notification->is_read_by_user = false;
                        $notification->read_at_by_user = null;
                    }
                });
            }

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
            $user = $request->user();
            
            $accessibleCategoryIds = $user ? $user->accessibleCategories()->pluck('categories.id')->toArray() : [];

            // Get all active and valid notifications
            $allNotifications = Notification::active()
                ->valid()
                ->where(function($q) use ($accessibleCategoryIds) {
                    $q->whereNull('category_id');
                    if (!empty($accessibleCategoryIds)) {
                        $q->orWhereIn('category_id', $accessibleCategoryIds);
                    }
                })
                ->pluck('id');
            
            // Get notifications that user has already read
            $readNotificationIds = $user->notifications()
                ->wherePivot('is_read', true)
                ->pluck('notification_id');
            
            // Count unread notifications
            $unreadCount = $allNotifications->diff($readNotificationIds)->count();

            return $this->successResponse(
                ['count' => $unreadCount],
                'Notification count retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve notification count',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Mark all notifications as read for the authenticated user
     */
    public function markAllAsRead(Request $request)
    {
        try {
            $user = $request->user();
            
            $accessibleCategoryIds = $user ? $user->accessibleCategories()->pluck('categories.id')->toArray() : [];

            // Get all active and valid notifications
            $notificationIds = Notification::active()
                ->valid()
                ->where(function($q) use ($accessibleCategoryIds) {
                    $q->whereNull('category_id');
                    if (!empty($accessibleCategoryIds)) {
                        $q->orWhereIn('category_id', $accessibleCategoryIds);
                    }
                })
                ->pluck('id')
                ->toArray();
            
            if (empty($notificationIds)) {
                return $this->successResponse(
                    ['marked_count' => 0],
                    'No notifications to mark as read'
                );
            }
            
            $now = now();
            
            // Use a single query to mark all notifications as read
            $data = [];
            foreach ($notificationIds as $notificationId) {
                $data[$notificationId] = [
                    'is_read' => true,
                    'read_at' => $now,
                ];
            }
            
            // Sync all notifications at once
            $user->notifications()->syncWithoutDetaching($data);

            return $this->successResponse(
                ['marked_count' => count($notificationIds)],
                'All notifications marked as read successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to mark notifications as read',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Mark a single notification as read
     */
    public function markAsRead(Request $request, $id)
    {
        try {
            $user = $request->user();
            
            // Verify notification exists and is valid
            $notification = Notification::active()
                ->valid()
                ->find($id);

            if (!$notification) {
                return $this->notFoundResponse('Notification not found or expired');
            }

            // Mark notification as read for this user
            $user->notifications()->syncWithoutDetaching([
                $notification->id => [
                    'is_read' => true,
                    'read_at' => now(),
                ]
            ]);

            return $this->successResponse(
                ['notification_id' => $notification->id],
                'Notification marked as read successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to mark notification as read',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}

