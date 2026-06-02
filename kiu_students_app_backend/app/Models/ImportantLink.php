<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ImportantLink extends Model
{
    protected $fillable = [
        'title',
        'video_link',
        'description',
        'order',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'order' => 'integer',
    ];

    /**
     * Scope to get only active important links.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope to order by order field.
     */
    public function scopeOrdered($query)
    {
        return $query->orderBy('order')->orderBy('created_at');
    }
}
