(() => {
    const shell = document.querySelector('.shell');
    const sidebar = document.getElementById('hr-sidebar');
    const toggle = document.getElementById('sidebar-toggle');
    if (!shell || !sidebar || !toggle) return;

    const setVisible = (visible) => {
        shell.classList.toggle('sidebar-hidden', !visible);
        sidebar.hidden = !visible;
        toggle.setAttribute('aria-expanded', String(visible));
        toggle.textContent = visible ? '☰ Sembunyikan menu' : '☰ Tampilkan menu';
        // Leaflet needs to recalculate its size when the content column changes.
        window.dispatchEvent(new Event('resize'));
    };
    let visible = !window.matchMedia('(max-width: 1080px)').matches;
    try {
        const saved = localStorage.getItem('folony.hr.sidebar.visible');
        if (saved !== null) visible = saved === 'true';
    } catch (_) { /* Navigation remains usable when browser storage is disabled. */ }
    setVisible(visible);
    toggle.addEventListener('click', () => {
        visible = !visible;
        setVisible(visible);
        try { localStorage.setItem('folony.hr.sidebar.visible', String(visible)); } catch (_) {}
    });
})();
