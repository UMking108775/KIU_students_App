<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest;
use App\Http\Requests\Api\RegisterRequest;
use App\Http\Resources\Api\UserResource;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    use ApiResponse;

    /**
     * Register a new user
     */
    public function register(RegisterRequest $request)
    {
        try {
            DB::beginTransaction();

            $user = User::create([
                'kiu_id' => $request->kiu_id,
                'name' => $request->name,
                'email' => $request->kiu_id . '@kiu.student.app', // Auto-generate email from KIU ID
                'whatsapp_number' => $request->whatsapp_number,
                'password' => Hash::make($request->password),
                'role' => 'user',
            ]);

            // Create access records for all categories with has_access = false (no access by default)
            $allCategories = \App\Models\Category::pluck('id');
            foreach ($allCategories as $categoryId) {
                \App\Models\CategoryAccess::create([
                    'user_id' => $user->id,
                    'category_id' => $categoryId,
                    'has_access' => false, // No access by default - admin must grant
                ]);
            }

            // Generate token using Sanctum
            $token = $user->createToken('mobile-app', ['*'], now()->addDays(30))->plainTextToken;

            DB::commit();

            return $this->successResponse([
                'user' => new UserResource($user),
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => '30 days',
            ], 'Registration successful. Welcome!', 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverErrorResponse('Registration failed. Please try again.', 
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Login user
     */
    public function login(LoginRequest $request)
    {
        try {
            $user = User::where('kiu_id', $request->kiu_id)
                ->where('role', '!=', 'admin')
                ->first();

            if (!$user || !Hash::check($request->password, $user->password)) {
                return $this->unauthorizedResponse('Invalid KIU ID or password');
            }

            // Revoke all previous tokens
            $user->tokens()->delete();

            // Generate new token with 30 days expiry
            $token = $user->createToken('mobile-app', ['*'], now()->addDays(30))->plainTextToken;

            return $this->successResponse([
                'user' => new UserResource($user),
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => '30 days',
            ], 'Login successful. Welcome back!');

        } catch (\Exception $e) {
            return $this->serverErrorResponse('Login failed. Please try again.',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Logout user (revoke current token)
     */
    public function logout(Request $request)
    {
        try {
            // Revoke current token
            $request->user()->currentAccessToken()->delete();

            return $this->successResponse(null, 'Logout successful');

        } catch (\Exception $e) {
            return $this->serverErrorResponse('Logout failed',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Logout from all devices (revoke all tokens)
     */
    public function logoutAll(Request $request)
    {
        try {
            // Revoke all tokens
            $request->user()->tokens()->delete();

            return $this->successResponse(null, 'Logged out from all devices successfully');

        } catch (\Exception $e) {
            return $this->serverErrorResponse('Logout failed',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Get authenticated user profile
     */
    public function user(Request $request)
    {
        try {
            return $this->successResponse(
                new UserResource($request->user()),
                'User profile retrieved successfully'
            );
        } catch (\Exception $e) {
            return $this->serverErrorResponse('Failed to retrieve user profile',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Refresh token (revoke old and create new)
     */
    public function refreshToken(Request $request)
    {
        try {
            // Revoke current token
            $request->user()->currentAccessToken()->delete();

            // Create new token
            $token = $request->user()->createToken('mobile-app', ['*'], now()->addDays(30))->plainTextToken;

            return $this->successResponse([
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => '30 days',
            ], 'Token refreshed successfully');

        } catch (\Exception $e) {
            return $this->serverErrorResponse('Failed to refresh token',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Update user profile
     */
    public function updateProfile(Request $request)
    {
        try {
            $user = $request->user();
            
            $validated = $request->validate([
                'name' => 'sometimes|required|string|max:255',
                'whatsapp_number' => 'sometimes|required|string|max:20',
            ]);

            $user->update($validated);

            return $this->successResponse(
                new UserResource($user->fresh()),
                'Profile updated successfully'
            );

        } catch (\Illuminate\Validation\ValidationException $e) {
            return $this->validationErrorResponse($e->errors());
        } catch (\Exception $e) {
            return $this->serverErrorResponse('Failed to update profile',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }
}
