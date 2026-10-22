<?php
namespace Tests\Feature;
use App\Models\BusinessCategory;
use App\Models\BusinessKind;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Services\BusinessCatalog;
use App\Services\NetworkService;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BusinessCatalogTest extends TestCase {
    use RefreshDatabase;
    private function catalog(): void {
        BusinessCategory::create(['id'=>'food','name'=>'Kuliner','color'=>'#e66b16']);
        BusinessCategory::create(['id'=>'shop','name'=>'Toko','color'=>'#2563eb']);
        BusinessKind::create(['id'=>'bakso','name'=>'Bakso','category_id'=>'food','icon'=>'bowl']);
        BusinessKind::create(['id'=>'kios','name'=>'Kios','category_id'=>'shop','icon'=>'store']);
        DB::table('business_aliases')->insert(['normalized'=>'bakso','kind_id'=>'bakso']);
    }
    public function test_catalog_is_authenticated_and_only_hr_can_manage_with_safe_style_values(): void {
        $this->catalog();
        $this->getJson('/api/business-catalog')->assertUnauthorized();
        $spv=User::factory()->create(['role'=>'spv']);
        $this->actingAs($spv,'sanctum')->getJson('/api/business-catalog')->assertOk()->assertJsonCount(2,'data');
        $this->actingAs($spv)->post('/admin/business-catalog/categories',['name'=>'Bad','color'=>'#ffffff','active'=>1])->assertForbidden();
        $this->actingAs(User::factory()->create(['role'=>'hr']));
        $this->get('/admin/business-catalog')->assertOk()->assertSee('Master Jenis Usaha');
        $this->post('/admin/business-catalog/categories/food',['name'=>'Kuliner','color'=>'url(evil)','active'=>1])->assertSessionHasErrors('color');
        $this->post('/admin/business-catalog/kinds/bakso',['name'=>'Bakso','category_id'=>'food','icon'=>'<script>','active'=>1])->assertSessionHasErrors('icon');
        $this->post('/admin/business-catalog/kinds/bakso',['name'=>'Bakso','category_id'=>'food','icon'=>'bowl','active'=>0])->assertRedirect();
        $this->getJson('/api/business-catalog')->assertJsonCount(0,'data.0.kinds');
    }
    public function test_classification_pair_legacy_labels_and_update_retention(): void {
        $this->seed(WorkflowDemoSeeder::class); $this->catalog();
        $owner=User::where('role','fgg')->firstOrFail();
        $profile=NetworkProfile::where('owner_id',$owner->id)->firstOrFail();
        $base=['id'=>'catalog-new','type'=>'ukm','name'=>'Catalog Test','address'=>'Jalan test','business_type'=>'baso','phone_number'=>'081234567890','status'=>'draft',
            'territory_province'=>'DKI Jakarta','territory_city'=>'Jakarta Barat','territory_district'=>'Taman Sari','territory_subdistrict'=>'Krukut'];
        $this->actingAs($owner,'sanctum');
        $this->postJson('/api/network',$base+['business_kind_id'=>'bakso','business_category_id'=>'shop'])->assertUnprocessable();
        $this->postJson('/api/network',$base+['business_kind_id'=>'bakso','business_category_id'=>'food'])->assertCreated()->assertJsonPath('data.business_kind_id','bakso')->assertJsonPath('data.business_type','Bakso');
        $legacy=$base; $legacy['id']='legacy-baso';
        $this->postJson('/api/network',$legacy)->assertCreated()->assertJsonPath('data.business_kind_id','bakso')->assertJsonPath('data.business_type','baso');
        BusinessKind::whereKey('bakso')->update(['active'=>false]);
        $legacy['name']='Updated legacy';
        $this->postJson('/api/network',$legacy)->assertCreated()->assertJsonPath('data.business_kind_id','bakso');
        $base['id']='inactive';
        $this->postJson('/api/network',$base+['business_kind_id'=>'bakso','business_category_id'=>'food'])->assertUnprocessable();
    }
    public function test_network_table_and_map_share_category_kind_and_unclassified_filters(): void {
        $this->seed(WorkflowDemoSeeder::class); $this->catalog();
        $template=NetworkProfile::first()->getAttributes();
        foreach ([['catalog-a','bakso'],['catalog-b','kios'],['catalog-c',null]] as [$id,$kind]) {
            NetworkProfile::insert(array_replace($template,['id'=>$id,'name'=>$id,'business_kind_id'=>$kind,'latitude'=>-6.2,'longitude'=>106.8]));
        }
        $this->actingAs(User::where('role','hr')->first());
        $filter='?search=catalog-&business_category_id=food&business_kind_id=bakso';
        $this->get('/admin/network'.$filter)->assertOk()->assertSee('catalog-a')->assertDontSee('catalog-b')->assertDontSee('catalog-c');
        $this->getJson('/admin/network/map-points'.$filter)->assertOk()->assertJsonCount(1,'data')
            ->assertJsonPath('data.0.business.category_name','Kuliner')->assertJsonPath('data.0.business.color','#e66b16')->assertJsonPath('data.0.business.icon','bowl');
        $this->getJson('/admin/network/map-points?search=catalog-&business_category_id=unclassified')->assertJsonCount(1,'data')->assertJsonPath('data.0.id','catalog-c');
        $this->getJson('/admin/network/map-points?search=catalog-&business_category_id=shop&business_kind_id=bakso')->assertJsonCount(0,'data');
    }
    public function test_staging_bootstrap_is_conservative_idempotent_and_preserves_source_and_coordinates(): void {
        $this->seed(WorkflowDemoSeeder::class);
        config(['app.url'=>'https://staging-absent.folony.co.id']);
        $profile=NetworkProfile::first();
        $profile->update(['business_type'=>'baso','latitude'=>-6.1234567,'longitude'=>106.1234567]);
        $before=$profile->getAttributes();
        $other=NetworkProfile::where('id','!=',$profile->id)->first();
        $other->update(['business_type'=>'meeting']);
        $this->artisan('business:bootstrap')->assertSuccessful();
        $this->assertDatabaseCount('business_categories',0);
        $this->artisan('business:bootstrap',['--apply'=>true])->assertSuccessful();
        $mapped=$profile->fresh();
        $this->assertSame('kuliner-bakso',$mapped->business_kind_id);
        foreach (['business_type','latitude','longitude','updated_at','owner_id'] as $key) $this->assertEquals($before[$key],$mapped->getAttributes()[$key]);
        $this->assertNull($other->fresh()->business_kind_id);
        $count=BusinessKind::count();
        $this->artisan('business:bootstrap',['--apply'=>true])->assertSuccessful();
        $this->assertSame($count,BusinessKind::count());
        config(['app.url'=>'https://absent.folony.co.id']);
        $this->artisan('business:bootstrap',['--apply'=>true])->assertFailed();
    }
    public function test_hr_review_mapping_preserves_original_text_and_ignores_already_classified(): void {
        $this->seed(WorkflowDemoSeeder::class); $this->catalog();
        $profile=NetworkProfile::first(); $profile->update(['business_type'=>'warung','business_kind_id'=>null]);
        $before=$profile->getAttributes();
        $this->actingAs(User::where('role','hr')->first())->post('/admin/business-catalog/map',[
            'source'=>'warung','business_kind_id'=>'kios','business_category_id'=>'shop'])->assertRedirect();
        $profile->refresh();
        $this->assertSame('kios',$profile->business_kind_id);
        $this->assertSame('warung',$profile->business_type);
        $this->assertEquals($before['updated_at'],$profile->getAttributes()['updated_at']);
        $this->post('/admin/business-catalog/map',['source'=>'warung','business_kind_id'=>'bakso','business_category_id'=>'food'])->assertRedirect();
        $this->assertSame('kios',$profile->fresh()->business_kind_id);
    }
}
