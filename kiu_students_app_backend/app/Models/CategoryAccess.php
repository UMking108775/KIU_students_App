<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CategoryAccess extends Model
{
    protected $table = 'user_category_access';

    protected $fillable = [
        'user_id',
        'category_id',
        'has_access',
    ];

    protected $casts = [
        'has_access' => 'boolean',
    ];

    /**
     * Get the user that owns the category access.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the category that the access belongs to.
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }
}

