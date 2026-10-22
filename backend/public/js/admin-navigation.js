(() => {
    const shell = document.querySelector('.shell');
    const sidebar = document.getElementById('hr-sidebar');
    const toggle = document.getElementById('sidebar-toggle');
    const edge = document.getElementById('sidebar-edge');
    const close = document.getElementById('sidebar-close');
    if (!shell || !sidebar || !toggle || !edge || !close) return;

    const hover = window.matchMedia('(hover: hover) and (pointer: fine)');
    let visible = false;
    let openedByClick = false;
    let closeTimer;
    const cancelClose = () => window.clearTimeout(closeTimer);
    const setVisible = (next) => {
        cancelClose();
        visible = next;
        if (!visible) openedByClick = false;
        sidebar.inert = !visible;
        sidebar.setAttribute('aria-hidden', String(!visible));
        shell.classList.toggle('sidebar-open', visible);
        toggle.setAttribute('aria-expanded', String(visible));
        edge.setAttribute('aria-expanded', String(visible));
        toggle.textContent = visible ? '☰ Sembunyikan menu' : '☰ Tampilkan menu';
    };
    const scheduleClose = () => {
        cancelClose();
        closeTimer = window.setTimeout(() => {
            if (!sidebar.contains(document.activeElement)) setVisible(false);
        }, 240);
    };
    const dismiss = () => {
        if (sidebar.contains(document.activeElement)) toggle.focus();
        setVisible(false);
    };

    // Overlaying the page keeps Leaflet's dimensions stable during hover.
    shell.classList.add('navigation-ready');
    setVisible(false);
    for (const trigger of [toggle, edge]) {
        trigger.addEventListener('click', (event) => {
            if (visible && openedByClick) {
                dismiss();
                openedByClick = false;
            } else {
                setVisible(true);
                openedByClick = true;
                if (event.detail === 0) close.focus();
            }
        });
    }
    for (const surface of [sidebar, edge, toggle]) {
        surface.addEventListener('pointerenter', (event) => {
            if (hover.matches && event.pointerType !== 'touch') setVisible(true);
        });
        surface.addEventListener('pointerleave', (event) => {
            if (hover.matches && event.pointerType !== 'touch') scheduleClose();
        });
    }
    sidebar.addEventListener('focusin', cancelClose);
    sidebar.addEventListener('focusout', (event) => {
        if (!sidebar.contains(event.relatedTarget)) scheduleClose();
    });
    close.addEventListener('click', dismiss);
    document.addEventListener('pointerdown', (event) => {
        if (visible && !sidebar.contains(event.target) && !toggle.contains(event.target) && !edge.contains(event.target)) dismiss();
    });
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && visible) {
            event.preventDefault();
            dismiss();
        }
    });
})();
