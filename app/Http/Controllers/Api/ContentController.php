<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ContentResource;
use App\Models\Content;
use App\Models\Category;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;

class ContentController extends Controller
{
    use ApiResponse;

    /**
     * Get all contents/materials for a specific category
     * Works for all 3 levels of categories
     */
    public function index(Request $request, $categoryId)
    {
        try {
            $user = $request->user();

            // Check if user has access to this category
            if (!$user->hasAccessToCategoryAndParents($categoryId)) {
                return $this->unauthorizedResponse('You do not have access to this category');
            }

            // Verify category exists and is active
            $category = Category::active()->find($categoryId);
            
            if (!$category) {
                return $this->notFoundResponse('Category not found or inactive');
            }

            // Get all active contents for this category
            $contents = Content::active()
                ->where('category_id', $categoryId)
                ->with('category')
                ->orderBy('created_at', 'desc')
                ->get();

            return $this->successResponse(
                [
                    'category' => [
                        'id' => $category->id,
                        'title' => $category->title,
                        'level' => $category->level,
                    ],
                    'contents' => ContentResource::collection($contents),
                    'total' => $contents->count(),
                ],
                'Contents retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve contents',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get a specific content/material by ID
     */
    public function show(Request $request, $id)
    {
        try {
            $user = $request->user();

            $content = Content::active()
                ->with('category')
                ->find($id);

            if (!$content) {
                return $this->notFoundResponse('Content not found or inactive');
            }

            // Check if user has access to the content's category
            if (!$user->hasAccessToCategoryAndParents($content->category_id)) {
                return $this->unauthorizedResponse('You do not have access to this content');
            }

            return $this->successResponse(
                new ContentResource($content),
                'Content retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve content',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get all contents across all categories user has access to
     * Useful for "All Materials" or "Recent Materials" view
     */
    public function all(Request $request)
    {
        try {
            $user = $request->user();

            // Get all active contents
            $allContents = Content::active()
                ->with('category')
                ->orderBy('created_at', 'desc')
                ->get();

            // Filter contents based on user's category access
            $accessibleContents = $allContents->filter(function ($content) use ($user) {
                return $user->hasAccessToCategoryAndParents($content->category_id);
            });

            return $this->successResponse(
                [
                    'contents' => ContentResource::collection($accessibleContents),
                    'total' => $accessibleContents->count(),
                ],
                'All contents retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve contents',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Search contents by title
     */
    public function search(Request $request)
    {
        try {
            $user = $request->user();
            $searchQuery = $request->input('query', '');

            if (empty($searchQuery)) {
                return $this->errorResponse('Search query is required', null, 400);
            }

            // Get all active contents matching search
            $contents = Content::active()
                ->where('title', 'like', "%{$searchQuery}%")
                ->with('category')
                ->orderBy('created_at', 'desc')
                ->get();

            // Filter contents based on user's category access
            $accessibleContents = $contents->filter(function ($content) use ($user) {
                return $user->hasAccessToCategoryAndParents($content->category_id);
            });

            return $this->successResponse(
                [
                    'query' => $searchQuery,
                    'contents' => ContentResource::collection($accessibleContents),
                    'total' => $accessibleContents->count(),
                ],
                'Search completed successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Search failed',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get contents by type (pdf, video, etc.)
     */
    public function byType(Request $request, $type)
    {
        try {
            $user = $request->user();

            // Get all active contents of specified type
            $contents = Content::active()
                ->byType($type)
                ->with('category')
                ->orderBy('created_at', 'desc')
                ->get();

            // Filter contents based on user's category access
            $accessibleContents = $contents->filter(function ($content) use ($user) {
                return $user->hasAccessToCategoryAndParents($content->category_id);
            });

            return $this->successResponse(
                [
                    'type' => $type,
                    'contents' => ContentResource::collection($accessibleContents),
                    'total' => $accessibleContents->count(),
                ],
                'Contents retrieved successfully'
            );

        } catch (\Exception $e) {
            return $this->serverErrorResponse(
                'Failed to retrieve contents',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}

