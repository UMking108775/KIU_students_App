<?php

namespace App\Traits;

use Illuminate\Support\Collection;

/**
 * Server-side enforcement of guest-mode preview limits.
 *
 * These limits MUST mirror the client-side limits in the Flutter app
 * (lib/services/guest_service.dart). Relying on the client alone is
 * insecure: an unauthenticated caller hitting the API directly would
 * otherwise receive every category and every content download URL.
 */
trait GuestContentFilter
{
    // Mirror GuestService.maxAudioFiles / maxPdfFiles
    protected int $guestMaxAudio = 1;
    protected int $guestMaxPdf = 1;

    // Mirror GuestService.level1Limit / level2Limit / level3Limit
    protected function guestCategoryLimitForLevel(int $level): int
    {
        return match (true) {
            $level <= 1 => 1, // level1Limit
            $level === 2 => 2, // level2Limit
            default => 1,      // level3Limit (level >= 3)
        };
    }

    /**
     * Limit a collection of sibling categories for guests, based on the
     * level of the items in the collection.
     */
    protected function limitCategoriesForGuest(Collection $categories): Collection
    {
        if ($categories->isEmpty()) {
            return $categories;
        }

        $level = (int) ($categories->first()->level ?? 1);

        return $categories->take($this->guestCategoryLimitForLevel($level))->values();
    }

    /**
     * Whether a guest is allowed to access content of the given type at all.
     * Mirrors GuestService.isContentTypeAllowedForGuest.
     */
    protected function guestCanAccessContentType(?string $contentType): bool
    {
        $type = strtolower((string) $contentType);

        return str_contains($type, 'audio')
            || str_contains($type, 'mp3')
            || str_contains($type, 'pdf')
            || str_contains($type, 'document');
    }

    /**
     * Limit a collection of contents for guests to the allowed number of
     * audio and PDF items (other content types are dropped), mirroring
     * GuestService.filterContentForGuest.
     */
    protected function limitContentsForGuest(Collection $contents): Collection
    {
        $audioCount = 0;
        $pdfCount = 0;

        return $contents->filter(function ($content) use (&$audioCount, &$pdfCount) {
            $type = strtolower((string) ($content->content_type ?? ''));

            if (str_contains($type, 'audio') || str_contains($type, 'mp3')) {
                if ($audioCount < $this->guestMaxAudio) {
                    $audioCount++;
                    return true;
                }
                return false;
            }

            if (str_contains($type, 'pdf') || str_contains($type, 'document')) {
                if ($pdfCount < $this->guestMaxPdf) {
                    $pdfCount++;
                    return true;
                }
                return false;
            }

            // Guests only ever receive audio/pdf preview material.
            return false;
        })->values();
    }
}