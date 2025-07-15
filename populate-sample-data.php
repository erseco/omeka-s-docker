<?php
/** Sample data generator for Omeka S */

if (PHP_SAPI !== 'cli') {
    echo "CLI only\n";
    exit(1);
}

require 'bootstrap.php';

use Laminas\Mvc\Application;
use Omeka\Api\Manager as ApiManager;
use Omeka\Api\Representation\SiteRepresentation;

function findSite(ApiManager $api, string $slug): ?SiteRepresentation {
    $response = $api->search('sites', ['slug' => $slug, 'limit' => 1]);
    return $response->getTotalResults() ? $response->getContent()[0] : null;
}

function ensureSite(ApiManager $api, string $title, string $slug): SiteRepresentation {
    if ($site = findSite($api, $slug)) {
        echo "Site '$slug' exists\n";
        return $site;
    }
    $site = $api->create('sites', [
        'o:title' => $title,
        'o:slug' => $slug,
        'o:theme' => 'default',
        'o:is_public' => 1,
    ])->getContent();
    echo "Site '$slug' created\n";
    return $site;
}

function ensureItem(ApiManager $api, string $title, int $siteId, array $media, string $description): void {
    $resp = $api->search('items', ['search' => $title, 'site_id' => $siteId, 'limit' => 1]);
    if ($resp->getTotalResults()) {
        echo "  Item '$title' exists\n";
        return;
    }
    $api->create('items', [
        'dcterms:title' => [[ '@value' => $title, 'type' => 'literal', '@language' => 'en']],
        'dcterms:description' => [[ '@value' => $description, 'type' => 'literal', '@language' => 'en']],
        'o:media' => [ $media ],
        'o:sites' => [[ 'o:id' => $siteId ]],
    ]);
    echo "  Item '$title' created\n";
}

$app = Application::init(require 'application/config/application.config.php');
$services = $app->getServiceManager();
$api = $services->get('Omeka\\ApiManager');

$sampleData = json_decode(file_get_contents('sample-data.json'), true);

foreach ($sampleData as $spec) {
    $site = ensureSite($api, $spec['title'], $spec['slug']);
    foreach ($spec['items'] as $i) {
        $mediaData = ['o:ingester' => $i['media']['o:ingester']];
        if (isset($i['media']['ingest_url'])) {
            $mediaData['ingest_url'] = $i['media']['ingest_url'];
        }
        if (isset($i['media']['o:source'])) {
            $mediaData['o:source'] = $i['media']['o:source'];
        }
        ensureItem($api, $i['title'], $site->id(), $mediaData, $i['desc']);
    }
}

echo "Done\n";
