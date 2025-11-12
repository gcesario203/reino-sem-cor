// ======== MENU MOBILE ========
const menuToggle = document.getElementById('menuToggle');
const navLinks = document.getElementById('navLinks');
if (menuToggle && navLinks) {
    menuToggle.addEventListener('click', () => {
        navLinks.classList.toggle('active');
        menuToggle.classList.toggle('active');
    });
}

// ======== SMOOTH SCROLL ========
document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', e => {
        const id = a.getAttribute('href');
        if (!id || id === '#') return;
        const el = document.querySelector(id);
        if (el) {
            e.preventDefault();
            window.scrollTo({ top: el.offsetTop - 70, behavior: 'smooth' });
        }
    });
});

// ======== FUNÇÃO GENÉRICA PARA CARROSSEIS ========
function initCarousel(classe) {
    const container = document.querySelector(`.carousel-container.${classe}`);
    if (!container) return;

    const track = container.querySelector('.carousel-track');
    const items = container.querySelectorAll('.carousel-item');
    const nextBtn = container.querySelector('.next');
    const prevBtn = container.querySelector('.prev');
    const indicatorsContainer = document.querySelector(`.carousel-indicators.${classe}`);
    let index = 0;

    items.forEach((_, i) => {
        const dot = document.createElement('div');
        dot.className = 'dot' + (i === 0 ? ' active' : '');
        dot.onclick = () => { index = i; update(); };
        indicatorsContainer.appendChild(dot);
    });
    const dots = indicatorsContainer.querySelectorAll('.dot');

    function update() {
        const w = items[0].clientWidth;
        track.style.transform = `translateX(-${w * index}px)`;
        dots.forEach((d, i) => d.classList.toggle('active', i === index));
    }

    nextBtn.onclick = () => { index = (index + 1) % items.length; update(); };
    prevBtn.onclick = () => { index = (index - 1 + items.length) % items.length; update(); };
    window.addEventListener('resize', update);
}

// Inicializa os dois carrosséis
initCarousel('personagens');
initCarousel('mecanicas');