# Issue: AEP-2
# Generated: 2025-09-13T17:24:57.505028
# Thread: 0f89bd00
# Enhanced: LangChain structured generation with prompt templates
# AI Model: deepseek/deepseek-chat-v3.1:free
# Max Length: 8000 characters

<?php
// {issue_key}: {summary}

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Exception;

class DataProcessorService
{
    private const MAX_RETRIES = 3;
    private const BATCH_SIZE = 100;

    public function processBatch(array $data): array
    {
        if (empty($data)) {
            throw new \InvalidArgumentException('Input data cannot be empty');
        }

        $results = [];
        $retryCount = 0;

        while ($retryCount < self::MAX_RETRIES) {
            try {
                DB::beginTransaction();

                foreach (array_chunk($data, self::BATCH_SIZE) as $chunk) {
                    $processedChunk = $this->processChunk($chunk);
                    $results = array_merge($results, $processedChunk);
                }

                DB::commit();
                break;

            } catch (Exception $e) {
                DB::rollBack();
                $retryCount++;
                
                Log::warning("Batch processing attempt {$retryCount} failed", [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString()
                ]);

                if ($retryCount >= self::MAX_RETRIES) {
                    throw new \RuntimeException('Max retries exceeded in batch processing', 0, $e);
                }
            }
        }

        return $results;
    }

    private function processChunk(array $chunk): array
    {
        $processed = [];

        foreach ($chunk as $item) {
            try {
                $validated = $this->validateItem($item);
                $transformed = $this->transformData($validated);
                $processed[] = $this->persistItem($transformed);
            } catch (Exception $e) {
                Log::error('Failed to process item', [
                    'item' => $item,
                    'error' => $e->getMessage()
                ]);
                continue;
            }
        }

        return $processed;
    }

    private function validateItem($item): array
    {
        if (!is_array($item)) {
            throw new \InvalidArgumentException('Item must be an array');
        }

        $required = ['id', 'name', 'value'];
        foreach ($required as $field) {
            if (!isset($item[$field])) {
                throw new \InvalidArgumentException("Missing required field: {$field}");
            }
        }

        if (!is_numeric($item['value'])) {
            throw new \InvalidArgumentException('Value must be numeric');
        }

        return $item;
    }

    private function transformData(array $data): array
    {
        return [
            'record_id' => (int) $data['id'],
            'record_name' => htmlspecialchars($data['name'], ENT_QUOTES, 'UTF-8'),
            'record_value' => (float) $data['value'],
            'processed_at' => now(),
            'checksum' => md5(serialize($data))
        ];
    }

    private function persistItem(array $data): array
    {
        try {
            $id = DB::table('processed_data')->insertGetId($data);
            $data['id'] = $id;
            return $data;
        } catch (Exception $e) {
            Log::error('Failed to persist item', [
                'data' => $data,
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function getStatistics(): array
    {
        return [
            'total_processed' => DB::table('processed_data')->count(),
            'last_processed' => DB::table('processed_data')->max('processed_at'),
            'average_value' => DB::table('processed_data')->avg('record_value')
        ];
    }
}