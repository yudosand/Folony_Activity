(() => {
    const data = document.getElementById('business-catalog-data');
    if (!data) return;
    const categories = JSON.parse(data.textContent);
    document.querySelectorAll('[data-business-select]').forEach(group => {
        const category = group.querySelector('[data-business-category]');
        const kind = group.querySelector('[data-business-kind]');
        const populate = (selected = '') => {
            kind.replaceChildren(new Option(kind.required ? 'Pilih jenis usaha' : 'Semua jenis usaha', ''));
            const options = categories.find(item => item.id === category.value)?.kinds || [];
            for (const item of options) kind.add(new Option(item.name, item.id, false, item.id === selected));
            kind.disabled = !options.length;
        };
        populate(kind.dataset.selected);
        category.addEventListener('change', () => populate());
    });
})();
