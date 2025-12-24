<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'kiu_id',
        'whatsapp_number',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    /**
     * Get the category access records for the user.
     */
    public function categoryAccess()
    {
        return $this->hasMany(CategoryAccess::class);
    }

    /**
     * Get the categories that the user has access to.
     */
    public function accessibleCategories()
    {
        return $this->belongsToMany(Category::class, 'user_category_access')
                    ->withPivot('has_access')
                    ->withTimestamps();
    }

    /**
     * Check if user has access to a specific category.
     */
    public function hasAccessToCategory($categoryId): bool
    {
        // If no access record exists, user has NO access by default
        $access = $this->categoryAccess()->where('category_id', $categoryId)->first();
        
        if (!$access) {
            return false; // No access by default - admin must grant explicitly
        }
        
        return $access->has_access;
    }

    /**
     * Check if user has access to category and its ancestors.
     */
    public function hasAccessToCategoryAndParents($categoryId): bool
    {
        $category = Category::find($categoryId);
        
        if (!$category) {
            return false;
        }

        // Check current category access
        if (!$this->hasAccessToCategory($categoryId)) {
            return false;
        }

        // Check parent access recursively
        if ($category->parent_id) {
            return $this->hasAccessToCategoryAndParents($category->parent_id);
        }

        return true;
    }

    /**
     * Get the notifications that the user has read status for.
     */
    public function notifications()
    {
        return $this->belongsToMany(Notification::class, 'user_notifications')
                    ->withPivot('is_read', 'read_at')
                    ->withTimestamps();
    }

    /**
     * Check if user has read a specific notification.
     */
    public function hasReadNotification($notificationId): bool
    {
        $notification = $this->notifications()->where('notification_id', $notificationId)->first();
        return $notification && $notification->pivot->is_read;
    }
}
