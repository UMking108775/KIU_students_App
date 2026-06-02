<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('important_links', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('video_link');
            $table->text('description');
            $table->integer('order')->default(0)->comment('Display order');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('important_links');
    }
};
