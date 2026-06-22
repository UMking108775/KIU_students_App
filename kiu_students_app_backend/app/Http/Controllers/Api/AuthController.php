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

            // Generate token using Sanctum. The token is named with the
            // device id so the active session can be tracked per-device.
            $deviceId = $this->resolveDeviceId($request);
            $token = $user->createToken($deviceId, ['*'], now()->addDays(30))->plainTextToken;

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

            $deviceId = $this->resolveDeviceId($request);
            $force = filter_var($request->input('force', false), FILTER_VALIDATE_BOOLEAN);

            // Single active session: is this account currently logged in on a
            // DIFFERENT device? If so, warn before signing that device out.
            $otherDeviceActive = $this->hasActiveTokenOnOtherDevice($user, $deviceId);

            if ($otherDeviceActive && !$force) {
                return response()->json([
                    'success' => false,
                    'requires_confirmation' => true,
                    'message' => 'This account is already logged in on another device. If you continue, you will be signed in here and that device will be signed out.',
                ], 409);
            }

            // Revoke all previous tokens (this signs out any other device).
            $user->tokens()->delete();

            // New token named with this device's id so we can identify which
            // device currently owns the session.
            $token = $user->createToken($deviceId, ['*'], now()->addDays(30))->plainTextToken;

            return $this->successResponse([
                'user' => new UserResource($user),
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => '30 days',
                'displaced_other_device' => $otherDeviceActive,
            ], 'Login successful. Welcome back!');

        } catch (\Exception $e) {
            return $this->serverErrorResponse('Login failed. Please try again.',
                config('app.debug') ? $e->getMessage() : null
            );
        }
    }

    /**
     * Report whether an account's session is still active, and why it ended.
     *
     * Public (unauthenticated) on purpose: a device whose token was revoked by
     * a login elsewhere can no longer authenticate, but still needs to know
     * WHY it was logged out. Returns one of:
     *   - active              : this device still owns a valid session
     *   - logged_in_elsewhere : another device took over the session
     *   - expired             : no active session for this account
     *   - unknown             : account not found / insufficient data
     */
    public function sessionState(Request $request)
    {
        $kiuId = trim((string) $request->input('kiu_id', ''));
        $deviceId = $this->resolveDeviceId($request);

        if ($kiuId === '') {
            return $this->successResponse(['active' => false, 'reason' => 'unknown']);
        }

        $user = User::where('kiu_id', $kiuId)->where('role', '!=', 'admin')->first();
        if (!$user) {
            return $this->successResponse(['active' => false, 'reason' => 'unknown']);
        }

        $now = now();
        $tokens = $user->tokens()
            ->where(function ($q) use ($now) {
                $q->whereNull('expires_at')->orWhere('expires_at', '>', $now);
            })
            ->get(['id', 'name']);

        $hasThisDevice = $tokens->contains(fn ($t) => $t->name === $deviceId);
        $hasOtherDevice = $tokens->contains(fn ($t) => $t->name !== $deviceId);

        $reason = $hasThisDevice
            ? 'active'
            : ($hasOtherDevice ? 'logged_in_elsewhere' : 'expired');

        return $this->successResponse([
            'active' => $hasThisDevice,
            'reason' => $reason,
        ]);
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

    /**
     * Resolve a stable device id from the request, falling back to a legacy
     * constant so older app builds (which don't send one) keep working.
     */
    private function resolveDeviceId(Request $request): string
    {
        $deviceId = trim((string) $request->input('device_id', ''));

        return $deviceId !== '' ? substr($deviceId, 0, 100) : 'mobile-app';
    }

    /**
     * Whether the user has a non-expired token that belongs to a different
     * device than the one making the request.
     */
    private function hasActiveTokenOnOtherDevice(User $user, string $deviceId): bool
    {
        $now = now();

        return $user->tokens()
            ->where('name', '!=', $deviceId)
            ->where(function ($q) use ($now) {
                $q->whereNull('expires_at')->orWhere('expires_at', '>', $now);
            })
            ->exists();
    }
}
