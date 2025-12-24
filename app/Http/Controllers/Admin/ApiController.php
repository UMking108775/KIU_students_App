<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

class ApiController extends Controller
{
    /**
     * Display API documentation
     */
    public function index()
    {
        $baseUrl = url('/api/v1');
        
        $endpoints = [
            'authentication' => [
                [
                    'method' => 'POST',
                    'endpoint' => '/auth/register',
                    'description' => 'Register a new user',
                    'auth_required' => false,
                    'parameters' => [
                        'kiu_id' => 'string|required|unique|numbers only',
                        'name' => 'string|required|min:3',
                        'whatsapp_number' => 'string|required|valid phone',
                        'password' => 'string|required|min:6',
                        'password_confirmation' => 'string|required',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Registration successful',
                        'data' => [
                            'user' => ['id', 'kiu_id', 'name', 'whatsapp_number'],
                            'token' => 'Bearer token',
                            'token_type' => 'Bearer',
                            'expires_in' => '30 days',
                        ],
                    ],
                ],
                [
                    'method' => 'POST',
                    'endpoint' => '/auth/login',
                    'description' => 'Login user',
                    'auth_required' => false,
                    'parameters' => [
                        'kiu_id' => 'string|required|numbers only',
                        'password' => 'string|required',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Login successful',
                        'data' => [
                            'user' => ['id', 'kiu_id', 'name', 'whatsapp_number'],
                            'token' => 'Bearer token',
                            'token_type' => 'Bearer',
                            'expires_in' => '30 days',
                        ],
                    ],
                ],
                [
                    'method' => 'POST',
                    'endpoint' => '/auth/logout',
                    'description' => 'Logout user (revoke current token)',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Logout successful',
                    ],
                ],
                [
                    'method' => 'POST',
                    'endpoint' => '/auth/logout-all',
                    'description' => 'Logout from all devices (revoke all tokens)',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Logged out from all devices successfully',
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/auth/user',
                    'description' => 'Get authenticated user profile',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'data' => [
                            'user' => ['id', 'kiu_id', 'name', 'whatsapp_number', 'created_at'],
                        ],
                    ],
                ],
                [
                    'method' => 'POST',
                    'endpoint' => '/auth/refresh-token',
                    'description' => 'Refresh authentication token',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'data' => [
                            'token' => 'New Bearer token',
                            'token_type' => 'Bearer',
                            'expires_in' => '30 days',
                        ],
                    ],
                ],
            ],
            'categories' => [
                [
                    'method' => 'GET',
                    'endpoint' => '/categories',
                    'description' => 'Get all main categories (level 1) that user has access to',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Main categories retrieved successfully',
                        'data' => [
                            [
                                'id' => 1,
                                'title' => 'Category Name',
                                'image' => 'full URL to image',
                                'parent_id' => null,
                                'level' => 1,
                                'is_active' => true,
                                'children' => [],
                                'contents_count' => 5,
                            ],
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/categories/{id}',
                    'description' => 'Get a specific category by ID with its details',
                    'auth_required' => true,
                    'parameters' => [
                        'id' => 'integer|required|category ID',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Category retrieved successfully',
                        'data' => [
                            'id' => 1,
                            'title' => 'Category Name',
                            'image' => 'full URL to image',
                            'parent_id' => null,
                            'level' => 1,
                            'is_active' => true,
                            'parent' => null,
                            'children' => [],
                            'contents_count' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/categories/{parentId}/subcategories',
                    'description' => 'Get all subcategories for a specific parent category',
                    'auth_required' => true,
                    'parameters' => [
                        'parentId' => 'integer|required|parent category ID',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Subcategories retrieved successfully',
                        'data' => [
                            [
                                'id' => 2,
                                'title' => 'Subcategory Name',
                                'image' => 'full URL to image',
                                'parent_id' => 1,
                                'level' => 2,
                                'is_active' => true,
                                'children' => [],
                                'contents_count' => 3,
                            ],
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/categories/tree',
                    'description' => 'Get full category tree with all levels (filtered by user access)',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Category tree retrieved successfully',
                        'data' => [
                            [
                                'id' => 1,
                                'title' => 'Main Category',
                                'level' => 1,
                                'children' => [
                                    [
                                        'id' => 2,
                                        'title' => 'Sub Category',
                                        'level' => 2,
                                        'children' => [
                                            [
                                                'id' => 3,
                                                'title' => '3rd Level Category',
                                                'level' => 3,
                                            ],
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            'contents' => [
                [
                    'method' => 'GET',
                    'endpoint' => '/categories/{categoryId}/contents',
                    'description' => 'Get all materials/contents for a specific category (works for all 3 levels)',
                    'auth_required' => true,
                    'parameters' => [
                        'categoryId' => 'integer|required|category ID (Level 1, 2, or 3)',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Contents retrieved successfully',
                        'data' => [
                            'category' => [
                                'id' => 1,
                                'title' => 'Computer Science',
                                'level' => 1,
                            ],
                            'contents' => [
                                [
                                    'id' => 1,
                                    'title' => 'Introduction to Programming.pdf',
                                    'content_type' => 'pdf',
                                    'backblaze_url' => 'https://backblaze.com/file/xyz.pdf',
                                    'is_active' => true,
                                    'category' => ['id' => 1, 'title' => 'Computer Science', 'level' => 1],
                                ],
                            ],
                            'total' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/contents',
                    'description' => 'Get all materials across all accessible categories',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'All contents retrieved successfully',
                        'data' => [
                            'contents' => [],
                            'total' => 25,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/contents/{id}',
                    'description' => 'Get a specific material/content by ID',
                    'auth_required' => true,
                    'parameters' => [
                        'id' => 'integer|required|content ID',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Content retrieved successfully',
                        'data' => [
                            'id' => 5,
                            'title' => 'Database Design.pdf',
                            'content_type' => 'pdf',
                            'backblaze_url' => 'https://backblaze.com/file/db.pdf',
                            'is_active' => true,
                            'category' => ['id' => 2, 'title' => 'Database', 'level' => 2],
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/contents/search?query={search_term}',
                    'description' => 'Search materials by title',
                    'auth_required' => true,
                    'parameters' => [
                        'query' => 'string|required|search term',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Search completed successfully',
                        'data' => [
                            'query' => 'python',
                            'contents' => [],
                            'total' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/contents/type/{type}',
                    'description' => 'Filter materials by content type (pdf, video, ppt, etc.)',
                    'auth_required' => true,
                    'parameters' => [
                        'type' => 'string|required|content type (pdf, video, ppt, doc, etc.)',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Contents retrieved successfully',
                        'data' => [
                            'type' => 'pdf',
                            'contents' => [],
                            'total' => 15,
                        ],
                    ],
                ],
            ],
            'support' => [
                [
                    'method' => 'GET',
                    'endpoint' => '/support/faqs',
                    'description' => 'Get all active FAQs',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'FAQs retrieved successfully',
                        'data' => [
                            'faqs' => [
                                [
                                    'id' => 1,
                                    'question' => 'How do I download materials?',
                                    'answer' => 'You can download materials by clicking on them...',
                                    'order' => 0,
                                ],
                            ],
                            'total' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'POST',
                    'endpoint' => '/support/submit',
                    'description' => 'Submit a support ticket/contact form',
                    'auth_required' => true,
                    'parameters' => [
                        'subject' => 'string|required|max:255',
                        'message' => 'string|required|min:10',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Your support request has been submitted successfully',
                        'data' => [
                            'id' => 1,
                            'subject' => 'Issue with download',
                            'message' => 'I cannot download PDF files...',
                            'status' => 'pending',
                            'admin_response' => null,
                            'created_at' => '2025-12-22 10:00:00',
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/support/tickets',
                    'description' => 'Get all support tickets for the authenticated user',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Support tickets retrieved successfully',
                        'data' => [
                            'tickets' => [],
                            'total' => 3,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/support/tickets/{id}',
                    'description' => 'Get a specific support ticket with admin response',
                    'auth_required' => true,
                    'parameters' => [
                        'id' => 'integer|required|ticket ID',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Support ticket retrieved successfully',
                        'data' => [
                            'id' => 1,
                            'subject' => 'Issue with download',
                            'message' => 'User message here...',
                            'status' => 'resolved',
                            'admin_response' => 'Admin response here...',
                            'responded_at' => '2025-12-22 11:00:00',
                            'created_at' => '2025-12-22 10:00:00',
                        ],
                    ],
                ],
            ],
            'notifications' => [
                [
                    'method' => 'GET',
                    'endpoint' => '/notifications',
                    'description' => 'Get all active and valid notifications',
                    'auth_required' => true,
                    'parameters' => [
                        'limit' => 'integer|optional|default:50|max:100',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Notifications retrieved successfully',
                        'data' => [
                            'notifications' => [
                                [
                                    'id' => 1,
                                    'title' => 'New Study Material Available',
                                    'message' => 'Check out the new programming tutorials...',
                                    'type' => 'info',
                                    'action_url' => null,
                                    'action_text' => null,
                                    'priority' => 10,
                                ],
                            ],
                            'total' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/notifications/count',
                    'description' => 'Get count of active notifications (for badge)',
                    'auth_required' => true,
                    'parameters' => [],
                    'response' => [
                        'success' => true,
                        'message' => 'Notification count retrieved successfully',
                        'data' => [
                            'count' => 5,
                        ],
                    ],
                ],
                [
                    'method' => 'GET',
                    'endpoint' => '/notifications/{id}',
                    'description' => 'Get a specific notification by ID',
                    'auth_required' => true,
                    'parameters' => [
                        'id' => 'integer|required|notification ID',
                    ],
                    'response' => [
                        'success' => true,
                        'message' => 'Notification retrieved successfully',
                        'data' => [
                            'id' => 1,
                            'title' => 'New Study Material Available',
                            'message' => 'Check out the new programming tutorials...',
                            'type' => 'info',
                            'priority' => 10,
                        ],
                    ],
                ],
            ],
        ];

        return view('admin.api.index', compact('endpoints', 'baseUrl'));
    }
}
