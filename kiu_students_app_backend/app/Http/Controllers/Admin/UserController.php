<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Category;
use App\Models\CategoryAccess;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    /**
     * Display a listing of users.
     */
    public function index(Request $request)
    {
        $search = $request->get('search');
        $perPage = $request->get('per_page', 15);
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $accessFilter = $request->get('access_filter'); // 'has_access', 'no_access', or null for all
        
        // Validate per_page value
        $allowedPerPage = [10, 25, 50, 100];
        if (!in_array((int)$perPage, $allowedPerPage)) {
            $perPage = 15;
        }
        
        $users = User::where('role', '!=', 'admin')
            ->when($search, function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                      ->orWhere('kiu_id', 'like', "%{$search}%")
                      ->orWhere('whatsapp_number', 'like', "%{$search}%");
                });
            })
            ->when($dateFrom, function ($query, $dateFrom) {
                $query->whereDate('created_at', '>=', $dateFrom);
            })
            ->when($dateTo, function ($query, $dateTo) {
                $query->whereDate('created_at', '<=', $dateTo);
            })
            ->when($accessFilter === 'has_access', function ($query) {
                $query->whereHas('categoryAccess', function ($q) {
                    $q->where('has_access', true);
                });
            })
            ->when($accessFilter === 'no_access', function ($query) {
                $query->where(function ($q) {
                    $q->whereDoesntHave('categoryAccess')
                      ->orWhereDoesntHave('categoryAccess', function ($subQ) {
                          $subQ->where('has_access', true);
                      });
                });
            })
            ->withCount(['categoryAccess as categories_count' => function ($query) {
                $query->where('has_access', true);
            }])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        // Get main categories for the bulk assignment modal
        $mainCategories = Category::byLevel(1)->orderBy('title')->get();

        return view('admin.users.index', compact('users', 'search', 'perPage', 'dateFrom', 'dateTo', 'accessFilter', 'mainCategories'));
    }

    /**
     * Show the form for creating a new user.
     */
    public function create()
    {
        return view('admin.users.create');
    }

    /**
     * Store a newly created user.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'kiu_id' => 'required|string|regex:/^[0-9]+$/|unique:users,kiu_id',
            'name' => 'required|string|min:3|max:255',
            'whatsapp_number' => 'required|string|max:20',
            'password' => 'required|string|min:6|confirmed',
        ]);

        try {
            DB::beginTransaction();

            $user = User::create([
                'kiu_id' => $validated['kiu_id'],
                'name' => $validated['name'],
                'email' => $validated['kiu_id'] . '@kiu.student.app', // Auto-generate email from KIU ID
                'whatsapp_number' => $validated['whatsapp_number'],
                'password' => Hash::make($validated['password']),
                'role' => 'user',
            ]);

            // Create access records for all categories with has_access = false (no access by default)
            $allCategories = Category::pluck('id');
            foreach ($allCategories as $categoryId) {
                CategoryAccess::create([
                    'user_id' => $user->id,
                    'category_id' => $categoryId,
                    'has_access' => false, // No access by default
                ]);
            }

            DB::commit();

            return redirect()->route('admin.users.index')
                ->with('success', 'User created successfully! Please assign category access.');

        } catch (\Exception $e) {
            DB::rollBack();
            
            $errorMessage = 'Failed to create user. Please try again.';
            if (config('app.debug')) {
                $errorMessage .= ' Error: ' . $e->getMessage();
            }
            
            return redirect()->back()
                ->withInput()
                ->with('error', $errorMessage);
        }
    }

    /**
     * Display the specified user.
     */
    public function show(string $id)
    {
        $user = User::with(['categoryAccess.category'])->findOrFail($id);
        return view('admin.users.show', compact('user'));
    }

    /**
     * Show the form for editing the specified user.
     */
    public function edit(string $id)
    {
        $user = User::findOrFail($id);
        
        if ($user->role === 'admin') {
            return redirect()->route('admin.users.index')
                ->with('error', 'Cannot edit admin users.');
        }

        return view('admin.users.edit', compact('user'));
    }

    /**
     * Update the specified user.
     */
    public function update(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        if ($user->role === 'admin') {
            return redirect()->route('admin.users.index')
                ->with('error', 'Cannot edit admin users.');
        }

        $validated = $request->validate([
            'kiu_id' => ['required', 'string', 'regex:/^[0-9]+$/', Rule::unique('users')->ignore($user->id)],
            'name' => 'required|string|min:3|max:255',
            'whatsapp_number' => 'required|string|max:20',
            'password' => 'nullable|string|min:6|confirmed',
        ]);

        try {
            DB::beginTransaction();

            $updateData = [
                'kiu_id' => $validated['kiu_id'],
                'name' => $validated['name'],
                'email' => $validated['kiu_id'] . '@kiu.student.app', // Auto-generate email from KIU ID
                'whatsapp_number' => $validated['whatsapp_number'],
            ];

            if (!empty($validated['password'])) {
                $updateData['password'] = Hash::make($validated['password']);
            }

            $user->update($updateData);

            DB::commit();

            return redirect()->route('admin.users.index')
                ->with('success', 'User updated successfully!');

        } catch (\Exception $e) {
            DB::rollBack();
            return redirect()->back()
                ->withInput()
                ->with('error', 'Failed to update user. Please try again.');
        }
    }

    /**
     * Remove the specified user.
     */
    public function destroy(string $id)
    {
        $user = User::findOrFail($id);

        if ($user->role === 'admin') {
            return redirect()->route('admin.users.index')
                ->with('error', 'Cannot delete admin users.');
        }

        try {
            $user->delete();
            return redirect()->route('admin.users.index')
                ->with('success', 'User deleted successfully!');
        } catch (\Exception $e) {
            return redirect()->back()
                ->with('error', 'Failed to delete user. Please try again.');
        }
    }

    /**
     * Show the form for managing user's category access.
     */
    public function categoryAccess(string $id)
    {
        $user = User::findOrFail($id);
        
        if ($user->role === 'admin') {
            return redirect()->route('admin.users.index')
                ->with('error', 'Cannot manage category access for admin users.');
        }

        // Get all categories organized by level
        $mainCategories = Category::byLevel(1)->with(['children.children'])->orderBy('title')->get();
        
        // Get user's current access settings
        $userAccess = CategoryAccess::where('user_id', $user->id)->pluck('has_access', 'category_id')->toArray();

        return view('admin.users.category-access', compact('user', 'mainCategories', 'userAccess'));
    }

    /**
     * Update user's category access.
     */
    public function updateCategoryAccess(Request $request, string $id)
    {
        $user = User::findOrFail($id);

        if ($user->role === 'admin') {
            return redirect()->route('admin.users.index')
                ->with('error', 'Cannot manage category access for admin users.');
        }

        try {
            DB::beginTransaction();

            // Get all category IDs from the system
            $allCategoryIds = Category::pluck('id')->toArray();
            
            // Get categories that should have access (checked checkboxes)
            $allowedCategories = $request->input('categories', []);
            
            // Delete all existing access records for this user
            CategoryAccess::where('user_id', $user->id)->delete();

            // Create new access records
            foreach ($allCategoryIds as $categoryId) {
                CategoryAccess::create([
                    'user_id' => $user->id,
                    'category_id' => $categoryId,
                    'has_access' => in_array($categoryId, $allowedCategories),
                ]);
            }

            DB::commit();

            return redirect()->route('admin.users.category-access', $user->id)
                ->with('success', 'Category access updated successfully!');

        } catch (\Exception $e) {
            DB::rollBack();
            return redirect()->back()
                ->with('error', 'Failed to update category access. Please try again.');
        }
    }

    /**
     * Bulk update category access for multiple users.
     */
    public function bulkCategoryAccess(Request $request)
    {
        $validated = $request->validate([
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'exists:users,id',
            'category_ids' => 'required|array|min:1',
            'category_ids.*' => 'exists:categories,id',
            'action' => 'required|in:grant,revoke',
        ]);

        $userIds = $validated['user_ids'];
        $categoryIds = $validated['category_ids'];
        $action = $validated['action'];
        $hasAccess = $action === 'grant';

        try {
            DB::beginTransaction();

            // Get all child categories for selected main categories
            $allCategoryIds = collect($categoryIds);
            foreach ($categoryIds as $categoryId) {
                $category = Category::with('descendants')->find($categoryId);
                if ($category) {
                    $allCategoryIds = $allCategoryIds->merge($this->getAllDescendantIds($category));
                }
            }
            $allCategoryIds = $allCategoryIds->unique()->toArray();

            // Filter out admin users
            $validUsers = User::whereIn('id', $userIds)
                ->where('role', '!=', 'admin')
                ->pluck('id')
                ->toArray();

            foreach ($validUsers as $userId) {
                foreach ($allCategoryIds as $categoryId) {
                    CategoryAccess::updateOrCreate(
                        [
                            'user_id' => $userId,
                            'category_id' => $categoryId,
                        ],
                        [
                            'has_access' => $hasAccess,
                        ]
                    );
                }
            }

            DB::commit();

            $actionText = $hasAccess ? 'granted' : 'revoked';
            return redirect()->route('admin.users.index')
                ->with('success', "Category access {$actionText} successfully for " . count($validUsers) . " user(s)!");

        } catch (\Exception $e) {
            DB::rollBack();
            return redirect()->back()
                ->with('error', 'Failed to update category access. Please try again. ' . (config('app.debug') ? $e->getMessage() : ''));
        }
    }

    /**
     * Get all descendant IDs for a category.
     */
    private function getAllDescendantIds(Category $category): array
    {
        $ids = [];
        foreach ($category->children as $child) {
            $ids[] = $child->id;
            $ids = array_merge($ids, $this->getAllDescendantIds($child));
        }
        return $ids;
    }
}

