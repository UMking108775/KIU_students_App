<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'image' => $this->image ? asset('storage/' . $this->image) : null,
            'parent_id' => $this->parent_id,
            'level' => $this->level,
            'is_active' => $this->is_active,
            'parent' => $this->when($this->parent, new CategoryResource($this->parent)),
            'children' => CategoryResource::collection($this->whenLoaded('children')),
            'contents_count' => $this->when(isset($this->contents_count), $this->contents_count),
            'created_at' => $this->created_at?->format('Y-m-d H:i:s'),
            'updated_at' => $this->updated_at?->format('Y-m-d H:i:s'),
        ];
    }
}

