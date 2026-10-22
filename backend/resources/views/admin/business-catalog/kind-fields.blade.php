<label>Nama jenis usaha<input name="name" maxlength="120" value="{{ $kind?->name }}" required></label>
<label>Kategori<select name="category_id" required>@foreach($categories as $c)<option value="{{ $c->id }}" @selected($kind?->category_id===$c->id)>{{ $c->name }}</option>@endforeach</select></label>
<label>Ikon<select name="icon">@foreach($icons as $key=>$label)<option value="{{ $key }}" @selected($kind?->icon===$key)>{{ $label }}</option>@endforeach</select></label>
<label>Status<select name="active"><option value="1" @selected($kind?->active ?? true)>Aktif</option><option value="0" @selected($kind && !$kind->active)>Nonaktif</option></select></label>
