<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ImportantLink;

class ImportantLinkController extends Controller
{
    /**
     * Get all active important links for the mobile app.
     */
    public function index()
    {
        $links = ImportantLink::active()
            ->ordered()
            ->get(['id', 'title', 'video_link', 'description', 'created_at']);

        return response()->json([
            'success' => true,
            'message' => 'Important links retrieved successfully',
            'data' => [
                'links' => $links,
            ],
        ]);
    }
}
