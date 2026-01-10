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
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('message');
            $table->enum('type', ['info', 'success', 'warning', 'error', 'announcement'])->default('info');
            $table->string('action_url')->nullable()->comment('Optional: URL to open when notification is clicked');
            $table->string('action_text')->nullable()->comment('Optional: Button text for action');
            $table->boolean('is_active')->default(true);
            $table->timestamp('scheduled_at')->nullable()->comment('Schedule notification for future');
            $table->timestamp('expires_at')->nullable()->comment('Notification expires after this date');
            $table->integer('priority')->default(0)->comment('Higher priority notifications appear first');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};

