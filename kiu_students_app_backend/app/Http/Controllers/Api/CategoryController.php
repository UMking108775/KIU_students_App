<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\CategoryResource;
use App\Models\Category;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    use ApiResponse;

    /**
     * Get all main categories (level 1) that user has access to
     */
    public function index(Request $request)
    {
        try {
            $user = $request->user();
            
            // Get all active level 1 categories
            $categories = Category::active()
                ->byLevel(1)
                ->with('children')
                ->withCount('contents')
                ->get();

            // Filter categories based on user access
            $accessibleCategories = $categories->filter(function ($category) use ($user) {
                return $user->hasAccessToCategory($category->id);
            });

            return $this->successResponse(
                CategoryResource::collection($accessibleCategories),
                'Main categories retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve categories',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get subcategories for a specific parent category
     */
    public function subcategories(Request $request, $parentId)
    {
        try {
            $user = $request->user();

            // Check if user has access to parent category
            if (!$user->hasAccessToCategory($parentId)) {
                return $this->unauthorizedResponse('You do not have access to this category');
            }

            // Verify parent category exists and is active
            $parent = Category::active()->find($parentId);
            
            if (!$parent) {
                return $this->notFoundResponse('Parent category not found or inactive');
            }

            // Get subcategories
            $subcategories = Category::active()
                ->where('parent_id', $parentId)
                ->with('children')
                ->withCount('contents')
                ->get();

            // Filter subcategories based on user access
            $accessibleSubcategories = $subcategories->filter(function ($category) use ($user) {
                return $user->hasAccessToCategory($category->id);
            });

            return $this->successResponse(
                CategoryResource::collection($accessibleSubcategories),
                'Subcategories retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve subcategories',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get a specific category by ID
     */
    public function show(Request $request, $id)
    {
        try {
            $user = $request->user();

            // Check if user has access to this category
            if (!$user->hasAccessToCategoryAndParents($id)) {
                return $this->unauthorizedResponse('You do not have access to this category');
            }

            $category = Category::active()
                ->with(['parent', 'children'])
                ->withCount('contents')
                ->find($id);

            if (!$category) {
                return $this->notFoundResponse('Category not found or inactive');
            }

            // Filter children based on user access
            if ($category->children) {
                $category->children = $category->children->filter(function ($child) use ($user) {
                    return $user->hasAccessToCategory($child->id);
                });
            }

            return $this->successResponse(
                new CategoryResource($category),
                'Category retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve category',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get full category tree that user has access to
     */
    public function tree(Request $request)
    {
        try {
            $user = $request->user();

            // Get all level 1 categories with nested children
            $categories = Category::active()
                ->byLevel(1)
                ->with(['children' => function ($query) {
                    $query->active()->with(['children' => function ($q) {
                        $q->active();
                    }]);
                }])
                ->get();

            // Filter tree based on user access
            $accessibleTree = $categories->filter(function ($category) use ($user) {
                if (!$user->hasAccessToCategory($category->id)) {
                    return false;
                }

                // Filter level 2 children
                if ($category->children) {
                    $category->children = $category->children->filter(function ($child) use ($user) {
                        if (!$user->hasAccessToCategory($child->id)) {
                            return false;
                        }

                        // Filter level 3 children
                        if ($child->children) {
                            $child->children = $child->children->filter(function ($grandchild) use ($user) {
                                return $user->hasAccessToCategory($grandchild->id);
                            });
                        }

                        return true;
                    });
                }

                return true;
            });

            return $this->successResponse(
                CategoryResource::collection($accessibleTree),
                'Category tree retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve category tree',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}

