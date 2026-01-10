<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // Use pre-loaded read status if available (from controller optimization)
        $isRead = $this->is_read_by_user ?? false;
        $readAt = null;
        
        if ($isRead && isset($this->read_at_by_user)) {
            $readAt = $this->read_at_by_user instanceof \Carbon\Carbon 
                ? $this->read_at_by_user->format('Y-m-d H:i:s')
                : $this->read_at_by_user;
        } else {
            // Fallback: check read status directly (for single notification requests)
            $user = $request->user();
            if ($user) {
                $userNotification = $user->notifications()->where('notification_id', $this->id)->first();
                if ($userNotification) {
                    $isRead = $userNotification->pivot->is_read ?? false;
                    $readAt = $userNotification->pivot->read_at ? $userNotification->pivot->read_at->format('Y-m-d H:i:s') : null;
                }
            }
        }

        return [
            'id' => $this->id,
            'title' => $this->title,
            'message' => $this->message,
            'type' => $this->type,
            'action_url' => $this->action_url,
            'action_text' => $this->action_text,
            'category_id' => $this->category_id,
            'priority' => $this->priority,
            'is_read' => $isRead,
            'read_at' => $readAt,
            'created_at' => $this->created_at?->format('Y-m-d H:i:s'),
            'scheduled_at' => $this->scheduled_at?->format('Y-m-d H:i:s'),
            'expires_at' => $this->expires_at?->format('Y-m-d H:i:s'),
        ];
    }
}

