/* ==========================================================================
   KeyHolder Product Website Logic (Three.js & App Simulator)
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  // Initialize Components
  initClock();
  initAppSimulator();
  initThreeDScene();
  initScrollytellingFallback();
});

/* ==========================================================================
   1. Mock Clock System
   ========================================================================== */
function initClock() {
  const clockEl = document.getElementById('mock-clock');
  if (!clockEl) return;
  
  function updateTime() {
    const now = new Date();
    let hours = now.getHours();
    let minutes = now.getMinutes();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    
    hours = hours % 12;
    hours = hours ? hours : 12; // the hour '0' should be '12'
    minutes = minutes < 10 ? '0' + minutes : minutes;
    
    clockEl.textContent = `${hours}:${minutes} ${ampm}`;
  }
  
  updateTime();
  setInterval(updateTime, 60000); // update every minute
}

/* ==========================================================================
   2. Three.js 3D Vault Scene
   ========================================================================== */
let globalThreeDCoordinator = {
  triggerScan: null,
  triggerSuccess: null,
  triggerReset: null
};

function initThreeDScene() {
  const container = document.getElementById('canvas-container');
  if (!container) return;

  // 1. Scene & Renderer Setup
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x070709, 0.08);

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  container.appendChild(renderer.domElement);

  // 2. Camera Setup
  const camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 100);
  camera.position.z = 8;

  // 3. Lighting (Apple Studio Light Style)
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.3);
  scene.add(ambientLight);

  const mainLight = new THREE.DirectionalLight(0xffffff, 2.5);
  mainLight.position.set(5, 5, 4);
  scene.add(mainLight);

  const blueGlow = new THREE.PointLight(0x009efd, 8, 15);
  blueGlow.position.set(-3, -2, 2);
  scene.add(blueGlow);

  const greenGlow = new THREE.PointLight(0x2af598, 0, 15);
  greenGlow.position.set(3, 2, 2);
  scene.add(greenGlow);

  const scannerGlow = new THREE.PointLight(0xff7b00, 0, 10);
  scannerGlow.position.set(0, 0, 1.5);
  scene.add(scannerGlow);

  // 4. Create Vault Group
  const vaultGroup = new THREE.Group();
  scene.add(vaultGroup);

  // 4a. Glassmorphic Card
  const glassGeometry = new THREE.BoxGeometry(3.2, 4.2, 0.15);
  const glassMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x1a2030,
    metalness: 0.1,
    roughness: 0.15,
    transmission: 0.9,      // transparency
    ior: 1.6,
    clearcoat: 1.0,
    clearcoatRoughness: 0.1,
    transparent: true,
    opacity: 0.8
  });
  const glassCard = new THREE.Mesh(glassGeometry, glassMaterial);
  vaultGroup.add(glassCard);

  // 4b. Metallic Rim Frame
  const frameGeometry = new THREE.BoxGeometry(3.3, 4.3, 0.16);
  const frameEdges = new THREE.EdgesGeometry(frameGeometry);
  const frameMaterial = new THREE.LineBasicMaterial({ color: 0xffffff, linewidth: 2, opacity: 0.15, transparent: true });
  const frame = new THREE.LineSegments(frameEdges, frameMaterial);
  vaultGroup.add(frame);

  // 4c. Interactive Shield Ring (Central core)
  const ringGeometry = new THREE.TorusGeometry(0.75, 0.06, 16, 100);
  const ringMaterial = new THREE.MeshStandardMaterial({
    color: 0x009efd,
    emissive: 0x009efd,
    emissiveIntensity: 1.5,
    metalness: 0.9,
    roughness: 0.1
  });
  const shieldRing = new THREE.Mesh(ringGeometry, ringMaterial);
  shieldRing.position.z = 0.12;
  vaultGroup.add(shieldRing);

  // 4d. Inner Shield Face
  const shieldShape = new THREE.Shape();
  shieldShape.moveTo(0, 0.45);
  shieldShape.quadraticCurveTo(0.35, 0.45, 0.35, 0.1);
  shieldShape.quadraticCurveTo(0.35, -0.3, 0, -0.5);
  shieldShape.quadraticCurveTo(-0.35, -0.3, -0.35, 0.1);
  shieldShape.quadraticCurveTo(-0.35, 0.45, 0, 0.45);

  const extrudeSettings = { depth: 0.05, bevelEnabled: true, bevelSegments: 3, steps: 1, bevelSize: 0.02, bevelThickness: 0.02 };
  const shieldGeometry = new THREE.ExtrudeGeometry(shieldShape, extrudeSettings);
  shieldGeometry.center();
  const shieldMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x7000ff,
    metalness: 0.9,
    roughness: 0.2,
    clearcoat: 1.0,
    emissive: 0x7000ff,
    emissiveIntensity: 0.4
  });
  const innerShield = new THREE.Mesh(shieldGeometry, shieldMaterial);
  innerShield.position.z = 0.1;
  vaultGroup.add(innerShield);

  // 4e. Center Key Lock
  const keyGroup = new THREE.Group();
  keyGroup.position.set(0, 0, 0.25);
  vaultGroup.add(keyGroup);

  // Key Loop (Torus)
  const keyLoopGeom = new THREE.TorusGeometry(0.2, 0.04, 8, 32);
  const keyMaterial = new THREE.MeshStandardMaterial({
    color: 0xe5e5e7,
    metalness: 0.95,
    roughness: 0.1,
    name: 'keyMat'
  });
  const keyLoop = new THREE.Mesh(keyLoopGeom, keyMaterial);
  keyLoop.position.y = 0.18;
  keyGroup.add(keyLoop);

  // Key Stem (Cylinder)
  const keyStemGeom = new THREE.CylinderGeometry(0.04, 0.04, 0.5, 16);
  const keyStem = new THREE.Mesh(keyStemGeom, keyMaterial);
  keyStem.position.y = -0.12;
  keyStem.rotation.x = Math.PI / 2; // Lie flat/normal
  keyGroup.add(keyStem);

  // Key Teeth
  const keyTeethGeom = new THREE.BoxGeometry(0.12, 0.06, 0.1);
  const keyTeeth = new THREE.Mesh(keyTeethGeom, keyMaterial);
  keyTeeth.position.set(0.06, -0.22, 0);
  keyGroup.add(keyTeeth);

  // 4f. Surrounding Data Particles
  const particleCount = 40;
  const particlesGeometry = new THREE.BufferGeometry();
  const positions = new Float32Array(particleCount * 3);
  const sizes = new Float32Array(particleCount);

  for (let i = 0; i < particleCount; i++) {
    // Spherical random dispersion
    const u = Math.random();
    const v = Math.random();
    const theta = u * 2.0 * Math.PI;
    const phi = Math.acos(2.0 * v - 1.0);
    const r = 2.5 + Math.random() * 1.5; // Radius between 2.5 and 4.0

    positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);
    positions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
    positions[i * 3 + 2] = r * Math.cos(phi) - 1.0;
  }

  particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  
  // Custom glowing canvas particle texture
  const particleCanvas = document.createElement('canvas');
  particleCanvas.width = 16;
  particleCanvas.height = 16;
  const ctx = particleCanvas.getContext('2d');
  const grad = ctx.createRadialGradient(8, 8, 0, 8, 8, 8);
  grad.addColorStop(0, 'rgba(0, 158, 253, 1)');
  grad.addColorStop(1, 'rgba(0, 158, 253, 0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 16, 16);
  const particleTexture = new THREE.CanvasTexture(particleCanvas);

  const particleMaterial = new THREE.PointsMaterial({
    size: 0.15,
    map: particleTexture,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    transparent: true,
    opacity: 0.8
  });
  const dataParticles = new THREE.Points(particlesGeometry, particleMaterial);
  scene.add(dataParticles);

  // 5. Interaction State Variables
  let mouse = { x: 0, y: 0 };
  let targetRotation = { x: 0.2, y: -0.3 };
  let isScanning = false;
  let isUnlocked = false;
  let animationTime = 0;

  // Mouse Move Event listener (local container tracking for Apple tilt)
  container.addEventListener('mousemove', (e) => {
    const rect = container.getBoundingClientRect();
    // Normalise mouse positions between -1 and 1
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    
    // Set target rotations based on mouse cursor position
    if (!isScanning) {
      targetRotation.y = mouse.x * 0.5;
      targetRotation.x = -mouse.y * 0.5;
    }
  });

  container.addEventListener('mouseleave', () => {
    // Reset back to gentle default rotation
    mouse.x = 0;
    mouse.y = 0;
    if (!isScanning) {
      targetRotation.x = 0.2;
      targetRotation.y = -0.3;
    }
  });

  // 6. External Animation Coordinators (Triggered by App Simulator)
  globalThreeDCoordinator.triggerScan = () => {
    isScanning = true;
    isUnlocked = false;
    // Rotate card to face directly forward
    targetRotation.x = 0;
    targetRotation.y = 0;
    
    // Shift lights to warning/scanning orange
    ringMaterial.color.setHex(0xff7b00);
    ringMaterial.emissive.setHex(0xff7b00);
    ringMaterial.emissiveIntensity = 2.0;
    scannerGlow.intensity = 6;
  };

  globalThreeDCoordinator.triggerSuccess = () => {
    isScanning = false;
    isUnlocked = true;
    
    // Shift lights to success green
    ringMaterial.color.setHex(0x2af598);
    ringMaterial.emissive.setHex(0x2af598);
    ringMaterial.emissiveIntensity = 3.0;
    greenGlow.intensity = 8;
    scannerGlow.intensity = 0;
    
    // Unlock key animation: rotate key 90deg on Z axis
    gsapAnimate(keyGroup.rotation, { z: Math.PI / 2, duration: 0.5 });
    
    // Pop scale slightly for tactile satisfaction
    gsapAnimate(vaultGroup.scale, { x: 1.1, y: 1.1, z: 1.1, duration: 0.2, yoyo: true, repeat: 1 });
  };

  globalThreeDCoordinator.triggerReset = () => {
    isScanning = false;
    isUnlocked = false;
    
    // Revert lights to cyan/blue
    ringMaterial.color.setHex(0x009efd);
    ringMaterial.emissive.setHex(0x009efd);
    ringMaterial.emissiveIntensity = 1.5;
    greenGlow.intensity = 0;
    scannerGlow.intensity = 0;
    
    // Relock key
    gsapAnimate(keyGroup.rotation, { z: 0, duration: 0.4 });
    targetRotation.x = 0.2;
    targetRotation.y = -0.3;
  };

  // Simple vanilla linear interpolation helper
  function lerp(start, end, amt) {
    return (1 - amt) * start + amt * end;
  }

  // Simple fallback animation coordinator when GSAP is not loaded
  function gsapAnimate(targetObj, props) {
    const startVal = {};
    const keys = Object.keys(props).filter(k => k !== 'duration' && k !== 'yoyo' && k !== 'repeat');
    
    keys.forEach(k => { startVal[k] = targetObj[k]; });
    
    const duration = (props.duration || 0.4) * 1000;
    const startTime = performance.now();
    
    function step() {
      const elapsed = performance.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      
      keys.forEach(k => {
        targetObj[k] = startVal[k] + (props[k] - startVal[k]) * progress;
      });
      
      if (progress < 1) {
        requestAnimationFrame(step);
      } else if (props.repeat === 1 && props.yoyo) {
        // Simple 1-loop yoyo implementation
        const reverseProps = { ...startVal, duration: props.duration };
        gsapAnimate(targetObj, reverseProps);
      }
    }
    requestAnimationFrame(step);
  }

  // 7. Render Loop
  const clock = new THREE.Clock();
  
  function animate() {
    requestAnimationFrame(animate);
    
    const delta = clock.getDelta();
    animationTime += delta;
    
    // Base floating motion
    if (!isScanning) {
      vaultGroup.position.y = Math.sin(animationTime * 1.2) * 0.15;
      vaultGroup.rotation.z = Math.sin(animationTime * 0.8) * 0.03;
    } else {
      // Rapid scan vibration
      vaultGroup.position.y = Math.sin(animationTime * 25.0) * 0.02;
    }
    
    // Smooth lerp rotation to target mouse/state/scroll values
    let currentTargetX = targetRotation.x;
    let currentTargetY = targetRotation.y;
    let currentTargetZ = 0;

    // Scroll Integration: Rotate card as page scrolls
    const scrollY = window.scrollY;
    const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
    if (maxScroll > 0) {
      const scrollPercent = scrollY / maxScroll;
      if (!isScanning && !isUnlocked) {
        currentTargetY += scrollPercent * 2.5;
        currentTargetX += scrollPercent * 0.8;
        currentTargetZ = -scrollPercent * 3.0;
      }
    }

    vaultGroup.rotation.x = lerp(vaultGroup.rotation.x, currentTargetX, 0.08);
    vaultGroup.rotation.y = lerp(vaultGroup.rotation.y, currentTargetY, 0.08);
    vaultGroup.position.z = lerp(vaultGroup.position.z, currentTargetZ, 0.08);

    // Rotate core ring and particles
    if (isScanning) {
      shieldRing.rotation.z += delta * 12.0; // spin fast when scanning
    } else if (isUnlocked) {
      shieldRing.rotation.z += delta * 1.0;
    } else {
      shieldRing.rotation.z += delta * 1.8;
    }
    
    dataParticles.rotation.y += delta * 0.05;
    dataParticles.rotation.x += delta * 0.02;

    renderer.render(scene, camera);
  }
  
  animate();

  // Resize handler
  window.addEventListener('resize', () => {
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  });
}

/* ==========================================================================
   3. Interactive App Simulator
   ========================================================================== */
function initAppSimulator() {
  // 1. Initial State Data Store
  const credentialsDB = [
    { id: '1', platform: 'OpenAI API Key', label: 'olix-studios-prod', secret: 'mock-openai-api-key-value-123456789-abcdefg', tags: ['prod', 'api'] },
    { id: '2', platform: 'GitHub Copilot Token', label: 'olix-ignacious', secret: 'mock-github-token-value-abcdefg-123456789', tags: ['dev', 'api'] },
    { id: '3', platform: 'Stripe Live Secret', label: 'studios-checkout', secret: 'mock-stripe-secret-key-value-123456789-abcdefg', tags: ['prod'] },
    { id: '4', platform: 'Firebase Admin Credentials', label: 'db-keyholder-main', secret: 'mock-firebase-service-account-json-string', tags: ['api'] },
    { id: '5', platform: 'Claude Anthropic Key', label: 'dev-sandbox', secret: 'mock-anthropic-api-key-value-123456789-abcdefg', tags: ['dev', 'api'] },
    { id: '6', platform: 'Vercel Deploy Token', label: 'olix-hosting-main', secret: 'mock-vercel-deploy-token-value-123456789-abcdefg', tags: ['dev'] }
  ];

  let keysList = [...credentialsDB];
  let searchFilter = '';
  let activeTagFilter = 'all';
  let credentialPendingCopy = null;
  let copyButtonElementPending = null;

  // DOM elements
  const trayBtn = document.getElementById('tray-trigger-btn');
  const popover = document.getElementById('keyholder-popover');
  const keysContainer = document.getElementById('sim-keys-list');
  const searchInput = document.getElementById('sim-search-input');
  const clearSearchBtn = document.getElementById('sim-clear-search');
  const filterPills = document.querySelectorAll('.filter-pill');
  const addKeyTrigger = document.getElementById('btn-add-key-view');
  const addKeyPanel = document.getElementById('add-key-slide-panel');
  const closeAddPanelBtn = document.getElementById('btn-close-add-panel');
  const addKeyForm = document.getElementById('sim-add-key-form');
  const platformInput = document.getElementById('input-platform');
  const labelInput = document.getElementById('input-label');
  const secretInput = document.getElementById('input-secret');
  const platformPreviewBadge = document.getElementById('platform-preview-badge');
  const previewIcon = platformPreviewBadge.querySelector('.preview-icon');
  const previewName = platformPreviewBadge.querySelector('.preview-name');
  const tagSelectButtons = document.querySelectorAll('.tag-select-btn');
  
  // Biometrics Modal DOM
  const bioOverlay = document.getElementById('biometric-overlay');
  const btnCancelBio = document.getElementById('btn-cancel-bio');
  const btnTriggerBio = document.getElementById('btn-trigger-bio-scan');
  const bioTitle = document.getElementById('biometric-title');
  const bioSubtitle = document.getElementById('biometric-subtitle');

  // 2. Event Listeners
  // Toggle Popover
  trayBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    popover.classList.toggle('collapsed');
    trayBtn.classList.toggle('active');
  });

  // Click outside to collapse popover
  document.addEventListener('click', (e) => {
    if (!popover.contains(e.target) && !trayBtn.contains(e.target)) {
      popover.classList.add('collapsed');
      trayBtn.classList.remove('active');
    }
  });

  // Search Logic
  searchInput.addEventListener('input', (e) => {
    searchFilter = e.target.value.toLowerCase();
    clearSearchBtn.hidden = searchFilter === '';
    applyFiltersAndRender();
  });

  clearSearchBtn.addEventListener('click', () => {
    searchInput.value = '';
    searchFilter = '';
    clearSearchBtn.hidden = true;
    applyFiltersAndRender();
    searchInput.focus();
  });

  // Filter Pill tabs
  filterPills.forEach(pill => {
    pill.addEventListener('click', () => {
      filterPills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      activeTagFilter = pill.getAttribute('data-tag');
      applyFiltersAndRender();
    });
  });

  // Slide Panels
  addKeyTrigger.addEventListener('click', () => {
    addKeyPanel.classList.add('active');
    platformInput.focus();
  });

  closeAddPanelBtn.addEventListener('click', () => {
    addKeyPanel.classList.remove('active');
    addKeyForm.reset();
    resetPlatformPreview();
  });

  // Platform Mapping Preview in form
  platformInput.addEventListener('input', (e) => {
    const val = e.target.value.toLowerCase().trim();
    if (val === '') {
      resetPlatformPreview();
      return;
    }
    const mapping = getPlatformMapping(val);
    previewIcon.textContent = mapping.icon;
    previewName.textContent = mapping.theme;
    platformPreviewBadge.style.borderColor = mapping.color;
    platformPreviewBadge.style.color = mapping.color;
  });

  function resetPlatformPreview() {
    previewIcon.textContent = '✨';
    previewName.textContent = 'Auto-mapping';
    platformPreviewBadge.style.borderColor = '';
    platformPreviewBadge.style.color = '';
  }

  // Inline Tag Selector inside form
  let selectedTags = [];
  tagSelectButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const val = btn.getAttribute('data-value');
      if (selectedTags.includes(val)) {
        selectedTags = selectedTags.filter(t => t !== val);
        btn.classList.remove('selected');
      } else {
        selectedTags.push(val);
        btn.classList.add('selected');
      }
    });
  });

  // Submit Add Key
  addKeyForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const newKey = {
      id: Date.now().toString(),
      platform: platformInput.value.trim(),
      label: labelInput.value.trim(),
      secret: secretInput.value.trim(),
      tags: [...selectedTags]
    };

    keysList.unshift(newKey);
    applyFiltersAndRender();
    
    // Reset Form
    addKeyPanel.classList.remove('active');
    addKeyForm.reset();
    resetPlatformPreview();
    selectedTags = [];
    tagSelectButtons.forEach(btn => btn.classList.remove('selected'));
  });

  // 3. Platform Mapping Logic (Matches README.md logic)
  function getPlatformMapping(platformName) {
    const name = platformName.toLowerCase();
    
    // AI & Machine Learning
    if (/openai|chatgpt|claude|anthropic|gemini|huggingface|cohere|deepseek|ollama/.test(name)) {
      return { icon: '✨', theme: 'AI & ML', color: '#2af598', borderClass: 'theme-ai' };
    }
    // Version Control
    if (/github|gitlab|bitbucket|git/.test(name)) {
      return { icon: '💻', theme: 'Git Host', color: '#b185ff', borderClass: 'theme-code' };
    }
    // Cloud & Hosting
    if (/aws|amazon|azure|cloudflare|digitalocean|heroku|vercel|netlify|fly\.io|render/.test(name)) {
      return { icon: '☁️', theme: 'Cloud Server', color: '#009efd', borderClass: 'theme-cloud' };
    }
    // Databases
    if (/postgres|mysql|mongo|redis|supabase|firebase|dynamodb|prisma|hasura|db/.test(name)) {
      return { icon: '🗄️', theme: 'Database', color: '#25d366', borderClass: 'theme-db' };
    }
    // Payments
    if (/stripe|paypal|braintree|adyen|coinbase|shopify/.test(name)) {
      return { icon: '💳', theme: 'Payment', color: '#635bff', borderClass: 'theme-pay' };
    }
    // Productivity
    if (/slack|discord|telegram|teams|zoom|notion|figma|jira|linear/.test(name)) {
      return { icon: '💬', theme: 'Productivity', color: '#ff007f', borderClass: 'theme-chat' };
    }
    
    // Default
    return { icon: '🌍', theme: 'General API', color: '#8e8e93', borderClass: 'theme-default' };
  }

  // 4. Render Functions
  function applyFiltersAndRender() {
    let results = keysList.filter(item => {
      // Search matches platform name or label name
      const matchesSearch = item.platform.toLowerCase().includes(searchFilter) || 
                            item.label.toLowerCase().includes(searchFilter);
      
      // Tag filter
      const matchesTag = activeTagFilter === 'all' || item.tags.includes(activeTagFilter);
      
      return matchesSearch && matchesTag;
    });

    renderList(results);
  }

  function renderList(list) {
    keysContainer.innerHTML = '';
    
    if (list.length === 0) {
      keysContainer.innerHTML = `
        <div class="empty-state">
          <p>No keys match your filters.</p>
        </div>
      `;
      return;
    }

    list.forEach(item => {
      const mapping = getPlatformMapping(item.platform);
      
      // Render Row
      const row = document.createElement('div');
      row.className = 'credential-row';
      
      // Build inner HTML safely
      let tagsHtml = '';
      item.tags.forEach(tag => {
        tagsHtml += `<span class="row-pill-tag tag-${tag}">${tag}</span>`;
      });

      row.innerHTML = `
        <div class="row-meta-left">
          <div class="row-icon-badge" style="background-color: ${mapping.color}15; color: ${mapping.color}; border: 1px solid ${mapping.color}30">
            ${mapping.icon}
          </div>
          <div class="row-text">
            <span class="row-platform">${escapeHtml(item.platform)}</span>
            <span class="row-label">${escapeHtml(item.label)}</span>
          </div>
        </div>
        <div class="row-meta-right">
          ${tagsHtml}
          <button class="copy-btn" title="Copy Key" aria-label="Copy key for ${escapeHtml(item.platform)}">📋</button>
        </div>
      `;

      // Wire up copy button logic
      const copyBtn = row.querySelector('.copy-btn');
      copyBtn.addEventListener('click', () => {
        triggerBiometricsAuth(item, copyBtn);
      });

      keysContainer.appendChild(row);
    });
  }

  function escapeHtml(str) {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // 5. Biometric Simulation Process
  function triggerBiometricsAuth(item, btnElement) {
    credentialPendingCopy = item;
    copyButtonElementPending = btnElement;
    
    // Reset modal UI state
    bioOverlay.classList.remove('scanning');
    btnTriggerBio.disabled = false;
    btnTriggerBio.textContent = 'Scan Fingerprint';
    btnCancelBio.disabled = false;
    bioTitle.textContent = 'Biometric Verification';
    bioSubtitle.textContent = `Verify Touch ID / Windows Hello to decrypt and copy key for ${item.platform}.`;
    
    // Display Modal
    bioOverlay.classList.add('active');
    
    // Trigger 3D scanner stance
    if (globalThreeDCoordinator.triggerScan) {
      globalThreeDCoordinator.triggerScan();
    }
  }

  // Cancel Auth
  btnCancelBio.addEventListener('click', () => {
    bioOverlay.classList.remove('active');
    credentialPendingCopy = null;
    copyButtonElementPending = null;
    
    // Reset 3D
    if (globalThreeDCoordinator.triggerReset) {
      globalThreeDCoordinator.triggerReset();
    }
  });

  // Start Fingerprint Scan
  btnTriggerBio.addEventListener('click', () => {
    bioOverlay.classList.add('scanning');
    btnTriggerBio.disabled = true;
    btnTriggerBio.textContent = 'Verifying...';
    btnCancelBio.disabled = true;
    
    // Simulate Touch ID biometric match timer (2 seconds)
    setTimeout(() => {
      // 1. Success UI modifications
      bioOverlay.classList.remove('scanning');
      bioTitle.textContent = '✓ Unlocked';
      bioSubtitle.textContent = 'Credential decrypted and copied to clipboard.';
      
      // Trigger 3D success animation
      if (globalThreeDCoordinator.triggerSuccess) {
        globalThreeDCoordinator.triggerSuccess();
      }

      // 2. Perform copy operation
      // Actually write secret to client clipboard if supported, else simulate
      if (navigator.clipboard) {
        navigator.clipboard.writeText(credentialPendingCopy.secret)
          .catch(err => console.log('Clipboard copy failed, using simulator backup', err));
      }

      // Update button icon in row to indicate success
      const originalText = copyButtonElementPending.textContent;
      copyButtonElementPending.textContent = '✓';
      copyButtonElementPending.style.backgroundColor = 'rgba(42, 245, 152, 0.15)';
      copyButtonElementPending.style.borderColor = 'var(--color-accent-primary)';
      copyButtonElementPending.style.color = 'var(--color-accent-primary)';
      copyButtonElementPending.disabled = true;

      // Close modal shortly after success feedback
      setTimeout(() => {
        bioOverlay.classList.remove('active');
        
        // Reset copy button row UI
        setTimeout(() => {
          copyButtonElementPending.textContent = originalText;
          copyButtonElementPending.style.backgroundColor = '';
          copyButtonElementPending.style.borderColor = '';
          copyButtonElementPending.style.color = '';
          copyButtonElementPending.disabled = false;
          
          // Reset 3D vault
          if (globalThreeDCoordinator.triggerReset) {
            globalThreeDCoordinator.triggerReset();
          }
        }, 1500);
      }, 1000);

    }, 2000);
  });

  // Initial populate
  applyFiltersAndRender();
}

/* ==========================================================================
   4. Intersection Observer Scrollytelling Fallback
   ========================================================================== */
function initScrollytellingFallback() {
  // Only execute JS scroll animations if native CSS scroll timelines are unsupported
  if (!CSS.supports('(animation-timeline: view()) and (animation-range: entry)')) {
    const trackedSections = document.querySelectorAll('#tracked section');
    const textSlides = document.querySelectorAll('.text-panel-slide');
    const visualLayers = document.querySelectorAll('.visual-layer');

    const observerOptions = {
      root: null,
      threshold: 0.55 // Trigger active status when 55% of panel is visible
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const index = Array.from(trackedSections).indexOf(entry.target);
          if (index !== -1) {
            // Remove active status from all elements
            textSlides.forEach(slide => slide.classList.remove('active'));
            visualLayers.forEach(layer => layer.classList.remove('active'));
            
            // Activate current panel and corresponding graphic
            textSlides[index].classList.add('active');
            visualLayers[index].classList.add('active');
          }
        }
      });
    }, observerOptions);

    trackedSections.forEach(section => {
      observer.observe(section);
    });
  }
}
