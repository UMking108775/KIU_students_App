<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class RegisterRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'kiu_id' => [
                'required',
                'string',
                'unique:users,kiu_id',
                'regex:/^[0-9]+$/',
                'min:4',
                'max:20'
            ],
            'name' => [
                'required',
                'string',
                'max:255',
                'min:3'
            ],
            'whatsapp_number' => [
                'required',
                'string',
                'max:20',
                'regex:/^[+]?[0-9]{10,15}$/'
            ],
            'password' => [
                'required',
                'string',
                'min:6',
                'max:50',
                'confirmed'
            ],
        ];
    }

    /**
     * Get custom messages for validator errors.
     */
    public function messages(): array
    {
        return [
            'kiu_id.required' => 'KIU ID is required',
            'kiu_id.unique' => 'This KIU ID is already registered',
            'kiu_id.regex' => 'KIU ID must contain only numbers',
            'kiu_id.min' => 'KIU ID must be at least 4 characters',
            'name.required' => 'Name is required',
            'name.min' => 'Name must be at least 3 characters',
            'whatsapp_number.required' => 'WhatsApp number is required',
            'whatsapp_number.regex' => 'Please enter a valid WhatsApp number',
            'password.required' => 'Password is required',
            'password.min' => 'Password must be at least 6 characters',
            'password.confirmed' => 'Password confirmation does not match',
        ];
    }

    /**
     * Handle a failed validation attempt.
     */
    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(
            response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422)
        );
    }
}
