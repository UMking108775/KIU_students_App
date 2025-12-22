<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

class ApiException extends Exception
{
    protected $statusCode;
    protected $errors;

    public function __construct(
        string $message = 'An error occurred',
        int $statusCode = 400,
        $errors = null
    ) {
        parent::__construct($message);
        $this->statusCode = $statusCode;
        $this->errors = $errors;
    }

    public function render(): JsonResponse
    {
        $response = [
            'success' => false,
            'message' => $this->getMessage(),
        ];

        if ($this->errors !== null) {
            $response['errors'] = $this->errors;
        }

        return response()->json($response, $this->statusCode);
    }
}

