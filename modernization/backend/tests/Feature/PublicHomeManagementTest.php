<?php

namespace Tests\Feature;

use App\Http\Requests\StorePublicHomeFileRequest;
use App\Models\ApplicationBatch;
use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PublicHomeManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_homepage_returns_enabled_content_in_order(): void
    {
        PublicHomeSection::create([
            'key' => 'nav',
            'title' => '门户',
        ]);
        PublicHomeSection::create([
            'key' => 'hero',
            'title' => '首页标题',
            'eyebrow' => '服务',
            'body' => '首页说明',
            'metadata' => [
                'primary_action' => ['label' => '进入系统', 'href' => '/login'],
                'secondary_action' => ['label' => '通知', 'href' => '#notices'],
                'status_title' => '当前状态',
            ],
        ]);
        PublicHomeSection::create(['key' => 'footer', 'body' => '页脚']);
        PublicHomeItem::create(['section' => 'nav_link', 'label' => '第二', 'href' => '#two', 'sort_order' => 20]);
        PublicHomeItem::create(['section' => 'nav_link', 'label' => '第一', 'href' => '#one', 'sort_order' => 10]);
        PublicHomeItem::create(['section' => 'notice', 'title' => '停用公告', 'sort_order' => 1, 'is_active' => false]);
        PublicHomeItem::create(['section' => 'notice', 'title' => '较早公告', 'summary' => 'B', 'published_at' => '2024-01-01', 'sort_order' => 10]);
        PublicHomeItem::create(['section' => 'notice', 'title' => '较新公告', 'summary' => 'A', 'published_at' => '2025-01-01', 'sort_order' => 10]);
        PublicHomeItem::create(['section' => 'service', 'code' => '01', 'title' => '服务', 'summary' => '说明', 'sort_order' => 10]);

        $response = $this->getJson('/api/public/homepage')->assertOk();

        $this->assertSame('门户', $response->json('nav.title'));
        $this->assertSame(['第一', '第二'], collect($response->json('nav.links'))->pluck('label')->all());
        $this->assertSame(['较新公告', '较早公告'], collect($response->json('notices'))->pluck('title')->all());
        $this->assertSame('页脚', $response->json('footer'));
    }

    public function test_public_homepage_excludes_e2e_batches_from_current_batch(): void
    {
        PublicHomeSection::create(['key' => 'nav', 'title' => '门户']);

        ApplicationBatch::create([
            'name' => 'E2E 测试批次',
            'code' => 'E2E-OPEN',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
            'metadata' => ['e2e' => true],
        ]);
        ApplicationBatch::create([
            'name' => '早期测试批次',
            'code' => 'E2E-LEGACY',
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);
        $businessBatch = ApplicationBatch::create([
            'name' => '正式业务批次',
            'code' => 'BUSINESS-OPEN',
            'starts_at' => now()->subDays(2),
            'ends_at' => now()->addDay(),
            'status' => ApplicationBatch::STATUS_OPEN,
        ]);

        $response = $this->getJson('/api/public/homepage')->assertOk();

        $this->assertSame($businessBatch->id, $response->json('current_batch.id'));
        $batchNames = collect($response->json('open_batches'))->pluck('name');
        $this->assertTrue($batchNames->contains('正式业务批次'));
        $this->assertFalse($batchNames->contains('E2E 测试批次'));
        $this->assertFalse($batchNames->contains('早期测试批次'));
    }

    public function test_only_admin_can_manage_public_home_content(): void
    {
        $user = User::factory()->create(['role' => 'unit']);
        Sanctum::actingAs($user);

        $this->getJson('/api/public-home')->assertForbidden();

        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);

        $section = PublicHomeSection::create(['key' => 'hero', 'title' => '旧标题']);

        $this->putJson('/api/public-home/sections/hero', [
            'title' => '新标题',
            'eyebrow' => '标签',
            'body' => '说明',
            'metadata' => ['status_title' => '状态'],
            'is_active' => true,
        ])->assertOk()
            ->assertJsonPath('title', '新标题');

        $item = $this->postJson('/api/public-home/items', [
            'section' => 'service',
            'title' => '项目申报',
            'summary' => '在线办理',
            'code' => '01',
            'sort_order' => 10,
            'is_active' => true,
        ])->assertCreated()
            ->json();

        $this->putJson('/api/public-home/items/'.$item['id'], [
            'section' => 'service',
            'title' => '项目申报',
            'summary' => '在线受理',
            'code' => '01',
            'sort_order' => 20,
            'is_active' => false,
        ])->assertOk()
            ->assertJsonPath('summary', '在线受理')
            ->assertJsonPath('is_active', false);

        $this->deleteJson('/api/public-home/items/'.$item['id'])->assertNoContent();
        $this->assertDatabaseMissing('public_home_items', ['id' => $item['id']]);
        $this->assertSame('新标题', $section->refresh()->title);
    }

    public function test_download_file_upload_reuses_secure_upload_rules(): void
    {
        Storage::fake('local');
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        $item = PublicHomeItem::create(['section' => 'download', 'title' => '模板', 'sort_order' => 10]);

        foreach (['php', 'jsp', 'asp', 'phtml', 'phar'] as $extension) {
            $this->postJson("/api/public-home/items/{$item->id}/file", [
                'file' => UploadedFile::fake()->create("shell.{$extension}", 10, 'application/octet-stream'),
            ])->assertUnprocessable();
        }

        $this->postJson("/api/public-home/items/{$item->id}/file", [
            'file' => UploadedFile::fake()->create('invoice.php.jpg', 10, 'image/jpeg'),
        ])->assertUnprocessable();

        $this->postJson("/api/public-home/items/{$item->id}/file", [
            'file' => UploadedFile::fake()->create('template.docx', 10, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
        ])->assertOk()
            ->assertJsonPath('file_original_name', 'template.docx')
            ->assertJsonPath('file_extension', 'docx');

        $item->refresh();
        Storage::disk('local')->assertExists($item->file_path);
    }

    public function test_public_home_file_request_rejects_path_like_original_names(): void
    {
        $request = StorePublicHomeFileRequest::create('/fake-upload', 'POST');
        $request->setContainer($this->app);

        foreach (['../budget.pdf', 'folder\\budget.pdf', 'budget..pdf'] as $originalName) {
            $path = tempnam(sys_get_temp_dir(), 'public-home-upload-');
            file_put_contents($path, "%PDF-1.4\n");

            try {
                $file = new class ($path, $originalName) extends UploadedFile {
                    public function __construct(string $path, private readonly string $originalName)
                    {
                        parent::__construct($path, 'budget.pdf', 'application/pdf', null, true);
                    }

                    public function getClientOriginalName(): string
                    {
                        return $this->originalName;
                    }
                };
                $validator = Validator::make(['file' => $file], $request->rules());

                $this->assertTrue($validator->fails(), $originalName.' should be rejected');
                $this->assertStringContainsString('文件名不能包含路径字符', implode(' ', $validator->errors()->all()));
            } finally {
                @unlink($path);
            }
        }
    }

    public function test_super_admin_can_manage_public_home_favicon_asset(): void
    {
        Storage::fake('local');
        $admin = User::factory()->create(['role' => 'super_admin']);
        Sanctum::actingAs($admin);
        $section = PublicHomeSection::create(['key' => 'nav', 'title' => '门户']);

        $this->postJson("/api/public-home/sections/{$section->key}/asset", [
            'type' => 'favicon',
            'file' => UploadedFile::fake()->image('favicon.png', 64, 64),
        ])->assertOk()
            ->assertJsonPath('metadata.assets.favicon.extension', 'png');

        $section->refresh();
        Storage::disk('local')->assertExists($section->metadata['assets']['favicon']['path']);

        $homepage = $this->getJson('/api/public/homepage')->assertOk();
        $faviconUrl = $homepage->json('brand.favicon_url');
        $this->assertIsString($faviconUrl);
        $this->assertStringStartsWith('/api/public/homepage/assets/nav/favicon', $faviconUrl);
        $this->get($faviconUrl)->assertOk();

        $this->deleteJson("/api/public-home/sections/{$section->key}/asset/favicon")
            ->assertOk()
            ->assertJsonMissingPath('metadata.assets.favicon');

        Storage::disk('local')->assertMissing($section->metadata['assets']['favicon']['path']);
        $this->getJson('/api/public/homepage')->assertOk()->assertJsonPath('brand.favicon_url', null);
    }

    public function test_public_download_requires_enabled_item_and_existing_file(): void
    {
        Storage::fake('local');
        Storage::disk('local')->put('public-home/downloads/1/template.pdf', 'PDF');
        $item = PublicHomeItem::create([
            'section' => 'download',
            'title' => '模板',
            'is_active' => true,
            'file_disk' => 'local',
            'file_path' => 'public-home/downloads/1/template.pdf',
            'file_original_name' => 'template.pdf',
            'file_extension' => 'pdf',
            'file_size_bytes' => 3,
        ]);

        $this->get("/api/public/homepage/downloads/{$item->id}")->assertOk();

        $item->update(['is_active' => false]);
        $this->get("/api/public/homepage/downloads/{$item->id}")->assertNotFound();
    }

    public function test_legacy_public_home_import_dry_run_and_execute(): void
    {
        Storage::fake('local');
        $workingDir = storage_path('framework/testing/public-home-import');
        File::ensureDirectoryExists($workingDir);
        File::ensureDirectoryExists($workingDir.'/upload');
        File::put($workingDir.'/upload/template.docx', 'docx body');
        $dump = $workingDir.'/legacy.sql';
        File::put($dump, <<<SQL
CREATE TABLE `pro_cms` (`id` int, `kind` int, `time` datetime, `title` varchar(255), `content` text, `ex_1` varchar(64));
INSERT INTO `pro_cms` VALUES
(1,1,'2025-01-01 00:00:00','通知标题','<p>通知内容</p>',''),
(2,3,'2025-01-02 00:00:00','下载模板','template.docx',''),
(3,4,'2025-01-03 00:00:00','资讯','跳过','');
SQL);

        Artisan::call('legacy:import-public-home', ['dump' => $dump, '--upload-root' => $workingDir.'/upload']);
        $this->assertStringContainsString('dry-run', Artisan::output());
        $this->assertDatabaseCount('public_home_items', 0);

        Artisan::call('legacy:import-public-home', [
            'dump' => $dump,
            '--upload-root' => $workingDir.'/upload',
            '--execute' => true,
        ]);

        $this->assertDatabaseHas('public_home_items', [
            'section' => 'notice',
            'title' => '通知标题',
            'legacy_source' => 'pro_cms',
            'legacy_id' => 1,
        ]);
        $download = PublicHomeItem::query()->where('legacy_id', 2)->firstOrFail();
        $this->assertTrue($download->is_active);
        $this->assertSame('download', $download->section);
        Storage::disk('local')->assertExists($download->file_path);
    }
}
