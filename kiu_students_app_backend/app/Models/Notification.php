<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class Notification extends Model
{
    protected $fillable = [
        'title',
        'message',
        'category_id',
        'type',
        'action_url',
        'action_text',
        'is_active',
        'scheduled_at',
        'expires_at',
        'priority',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'category_id' => 'integer',
        'scheduled_at' => 'datetime',
        'expires_at' => 'datetime',
        'priority' => 'integer',
    ];

    /**
     * Scope to get only active notifications.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope to get notifications that are currently valid.
     */
    public function scopeValid($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('scheduled_at')
              ->orWhere('scheduled_at', '<=', now());
        })->where(function ($q) {
            $q->whereNull('expires_at')
              ->orWhere('expires_at', '>=', now());
        });
    }

    /**
     * Scope to order by priority and date.
     */
    public function scopeOrdered($query)
    {
        return $query->orderBy('priority', 'desc')
                     ->orderBy('created_at', 'desc');
    }

    /**
     * Check if notification is currently valid.
     */
    public function isValid(): bool
    {
        if (!$this->is_active) {
            return false;
        }

        if ($this->scheduled_at && $this->scheduled_at->isFuture()) {
            return false;
        }

        if ($this->expires_at && $this->expires_at->isPast()) {
            return false;
        }

        return true;
    }

    /**
     * Get the users that have read status for this notification.
     */
    public function users()
    {
        return $this->belongsToMany(\App\Models\User::class, 'user_notifications')
                    ->withPivot('is_read', 'read_at')
                    ->withTimestamps();
    }
}

