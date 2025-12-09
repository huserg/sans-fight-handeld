/**
 * Bad Time Simulator - JSGameLauncher Shim for Construct 2
 */

// Get canvas from JSGameLauncher's document
let canvas = globalThis.document.getElementById('canvas');
if (!canvas) {
  throw new Error('Canvas not found');
}

// Store canvas reference
const c2canvas = canvas;

// Get and cache the 2D context ONCE
const origGetContext = canvas.getContext.bind(canvas);
const cached2DContext = origGetContext('2d');

// Store global reference for C2 to access
globalThis._c2_cached_context = cached2DContext;
globalThis._c2_main_canvas = c2canvas;

// Shim window.location for browser plugin URL parsing
if (!globalThis.window.location || !globalThis.window.location.search) {
  globalThis.window.location = globalThis.window.location || {};
  globalThis.window.location.href = globalThis.window.location.href || 'file:///game/index.html';
  globalThis.window.location.search = globalThis.window.location.search || '';
  globalThis.window.location.hash = globalThis.window.location.hash || '';
  globalThis.window.location.protocol = globalThis.window.location.protocol || 'file:';
  globalThis.window.location.host = globalThis.window.location.host || '';
  globalThis.window.location.hostname = globalThis.window.location.hostname || '';
  globalThis.window.location.pathname = globalThis.window.location.pathname || '/game/index.html';
  globalThis.window.location.origin = globalThis.window.location.origin || 'file://';
  globalThis.window.location.reload = globalThis.window.location.reload || function() {};
}

// Create a getContext wrapper function
function wrappedGetContext(type, options) {
  if (type === '2d') {
    return cached2DContext;
  }
  // Return null for WebGL to force C2 into 2D mode
  if (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl') {
    return null;
  }
  return origGetContext(type, options);
}

// Apply wrapper to canvas
canvas.getContext = wrappedGetContext;

// Test drawing something to verify canvas works
cached2DContext.fillStyle = 'blue';
cached2DContext.fillRect(0, 0, 50, 50);

// Add missing canvas properties that C2 might need
canvas.width = 320;
canvas.height = 240;
canvas.clientWidth = 320;
canvas.clientHeight = 240;
canvas.offsetWidth = 320;
canvas.offsetHeight = 240;
canvas.tabIndex = 0;
canvas.focus = () => {};
canvas.blur = () => {};

// Extend document.getElementById for C2
const origGetElementById = globalThis.document.getElementById.bind(globalThis.document);
globalThis.document.getElementById = function(id) {
  if (id === 'c2canvas') return c2canvas;
  if (id === 'c2canvasdiv') {
    const divListeners = {};
    return {
      appendChild: () => {},
      removeChild: () => {},
      children: [c2canvas],
      style: {},
      offsetWidth: c2canvas.width,
      offsetHeight: c2canvas.height,
      getBoundingClientRect: () => ({
        left: 0, top: 0,
        width: c2canvas.width, height: c2canvas.height,
        right: c2canvas.width, bottom: c2canvas.height
      }),
      addEventListener: (type, fn, opts) => {
        divListeners[type] = divListeners[type] || [];
        divListeners[type].push(fn);
        // Forward touch/pointer events to canvas
        c2canvas.addEventListener(type, fn, opts);
      },
      removeEventListener: (type, fn) => {
        c2canvas.removeEventListener(type, fn);
      }
    };
  }
  return origGetElementById(id);
};

// Event listener storage for shim objects
const bodyListeners = {};
const docElementListeners = {};

// Ensure body has all required properties and methods
globalThis.document.body = globalThis.document.body || {};
globalThis.document.body.clientWidth = c2canvas.width;
globalThis.document.body.clientHeight = c2canvas.height;
globalThis.document.body.appendChild = globalThis.document.body.appendChild || (() => {});
globalThis.document.body.removeChild = globalThis.document.body.removeChild || (() => {});
globalThis.document.body.style = globalThis.document.body.style || {};
globalThis.document.body.addEventListener = globalThis.document.body.addEventListener || function(type, fn, opts) {
  bodyListeners[type] = bodyListeners[type] || [];
  bodyListeners[type].push(fn);
  // Forward to document for key events
  if (type.startsWith('key') || type.startsWith('mouse') || type.startsWith('pointer') || type.startsWith('touch')) {
    globalThis.document.addEventListener(type, fn, opts);
  }
};
globalThis.document.body.removeEventListener = globalThis.document.body.removeEventListener || function(type, fn) {
  globalThis.document.removeEventListener(type, fn);
};
globalThis.document.body.dispatchEvent = globalThis.document.body.dispatchEvent || function(e) {
  globalThis.document.dispatchEvent(e);
};

// Ensure documentElement has all required properties
globalThis.document.documentElement = globalThis.document.documentElement || {};
globalThis.document.documentElement.clientWidth = c2canvas.width;
globalThis.document.documentElement.clientHeight = c2canvas.height;
globalThis.document.documentElement.style = globalThis.document.documentElement.style || {};
globalThis.document.documentElement.addEventListener = globalThis.document.documentElement.addEventListener || function(type, fn, opts) {
  docElementListeners[type] = docElementListeners[type] || [];
  docElementListeners[type].push(fn);
  globalThis.document.addEventListener(type, fn, opts);
};
globalThis.document.documentElement.removeEventListener = globalThis.document.documentElement.removeEventListener || function(type, fn) {
  globalThis.document.removeEventListener(type, fn);
};

// Handle DOMContentLoaded
const origAddEventListener = globalThis.document.addEventListener.bind(globalThis.document);
globalThis.document.addEventListener = function(event, handler, options) {
  if (event === 'DOMContentLoaded') {
    setTimeout(handler, 10);
    return;
  }
  origAddEventListener(event, handler, options);
};

// Override createElement - C2 creates multiple canvases
const origCreateElement = globalThis.document.createElement.bind(globalThis.document);
let canvasCount = 0;
globalThis.document.createElement = function(tag) {
  if (tag === 'canvas' || tag === 'CANVAS') {
    canvasCount++;
    if (canvasCount === 1) {
      // First canvas is the main display canvas
      return c2canvas;
    } else {
      // Subsequent canvases are for sprite batching - create real offscreen canvases
      return origCreateElement(tag);
    }
  }
  return origCreateElement(tag);
};

// Window properties
globalThis.window = globalThis.window || globalThis;
globalThis.window.innerWidth = 320;
globalThis.window.innerHeight = 240;
globalThis.window.devicePixelRatio = globalThis.window.devicePixelRatio || 1;

// Image constructor shim - C2 creates images and adds event listeners
const OrigImage = globalThis.Image;
let imgCount = 0;
globalThis.Image = function(width, height) {
  imgCount++;
  const myId = imgCount;
  const img = new OrigImage(width, height);
  const listeners = {};

  // Trigger load listeners
  const triggerLoad = () => {
    if (listeners.load) {
      listeners.load.forEach(f => {
        try { f({ target: img, type: 'load' }); } catch(e) {}
      });
    }
    if (img.onload) {
      try { img.onload({ target: img, type: 'load' }); } catch(e) {}
    }
  };

  // Watch for image completion
  let watchCount = 0;
  let triggered = false;
  const watchLoad = () => {
    if (triggered) return;
    watchCount++;
    if (img.complete && img.naturalWidth > 0) {
      triggered = true;
      triggerLoad();
    } else if (img.complete && !img.naturalWidth) {
      // JSGameLauncher doesn't set naturalWidth, trigger when complete
      triggered = true;
      triggerLoad();
    } else if (watchCount > 50) {
      triggered = true;
      triggerLoad();
    } else {
      setTimeout(watchLoad, 20);
    }
  };

  // Override src setter to watch for loads
  const srcDescriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(img), 'src');
  if (srcDescriptor) {
    Object.defineProperty(img, 'src', {
      get: function() { return srcDescriptor.get.call(this); },
      set: function(val) {
        srcDescriptor.set.call(this, val);
        if (val) setTimeout(watchLoad, 10);
      },
      configurable: true
    });
  }

  // Add addEventListener
  if (!img.addEventListener) {
    img.addEventListener = function(type, fn, opts) {
      listeners[type] = listeners[type] || [];
      listeners[type].push(fn);
      // If image already loaded, trigger immediately
      if (type === 'load' && img.complete && img.naturalWidth > 0) {
        setTimeout(() => fn({ target: img, type: 'load' }), 0);
      }
    };
  }

  if (!img.removeEventListener) {
    img.removeEventListener = function(type, fn) {
      if (listeners[type]) {
        listeners[type] = listeners[type].filter(f => f !== fn);
      }
    };
  }

  return img;
};

// Audio shim - ensure audio elements have required methods
const OrigAudio = globalThis.Audio;
globalThis.Audio = function(...args) {
  let audio;
  try {
    audio = args.length ? new OrigAudio(...args) : new OrigAudio();
  } catch(e) {
    // If Audio construction fails, create a stub
    audio = {
      src: '',
      volume: 1,
      currentTime: 0,
      duration: 0,
      paused: true,
      ended: false,
      loop: false,
      muted: false,
      readyState: 0,
      play: () => Promise.resolve(),
      pause: () => {},
      load: () => {},
      addEventListener: () => {},
      removeEventListener: () => {}
    };
  }

  // Add missing methods
  if (!audio.addEventListener) {
    audio.addEventListener = () => {};
  }
  if (!audio.removeEventListener) {
    audio.removeEventListener = () => {};
  }

  // Watch for src changes
  const origSrc = audio.src;
  Object.defineProperty(audio, 'src', {
    get: function() { return this._src || ''; },
    set: function(val) {
      this._src = val;
      try {
        if (OrigAudio.prototype && Object.getOwnPropertyDescriptor(OrigAudio.prototype, 'src')) {
          Object.getOwnPropertyDescriptor(OrigAudio.prototype, 'src').set.call(this, val);
        }
      } catch(e) {}
    }
  });

  return audio;
};

// AudioContext shim - C2 uses listener.setPosition/setOrientation
const existingAC = globalThis.AudioContext;
let needsShim = !existingAC;
if (existingAC && !needsShim) {
  try {
    const testCtx = new existingAC();
    needsShim = !testCtx.listener || typeof testCtx.listener.setPosition !== 'function';
    if (testCtx.close) testCtx.close();
  } catch(e) {
    needsShim = true;
  }
}
if (needsShim) {
  globalThis.AudioContext = function() {
    return {
      state: 'running',
      sampleRate: 44100,
      destination: { maxChannelCount: 2 },
      currentTime: 0,
      listener: {
        setPosition: () => {},
        setOrientation: () => {},
        positionX: { value: 0 },
        positionY: { value: 0 },
        positionZ: { value: 0 },
        forwardX: { value: 0 },
        forwardY: { value: 0 },
        forwardZ: { value: -1 },
        upX: { value: 0 },
        upY: { value: 1 },
        upZ: { value: 0 }
      },
      createGain: () => ({
        gain: { value: 1, setValueAtTime: () => {}, linearRampToValueAtTime: () => {}, exponentialRampToValueAtTime: () => {} },
        connect: () => {},
        disconnect: () => {}
      }),
      createBufferSource: () => ({
        buffer: null,
        loop: false,
        loopStart: 0,
        loopEnd: 0,
        playbackRate: { value: 1, setValueAtTime: () => {} },
        start: () => {},
        stop: () => {},
        connect: () => {},
        disconnect: () => {}
      }),
      createPanner: () => ({
        setPosition: () => {},
        setOrientation: () => {},
        panningModel: 'HRTF',
        distanceModel: 'inverse',
        refDistance: 1,
        maxDistance: 10000,
        rolloffFactor: 1,
        coneInnerAngle: 360,
        coneOuterAngle: 360,
        coneOuterGain: 0,
        connect: () => {},
        disconnect: () => {}
      }),
      createAnalyser: () => ({
        fftSize: 2048,
        frequencyBinCount: 1024,
        minDecibels: -100,
        maxDecibels: -30,
        smoothingTimeConstant: 0.8,
        connect: () => {},
        disconnect: () => {},
        getByteFrequencyData: (arr) => { if (arr) arr.fill(0); },
        getFloatFrequencyData: (arr) => { if (arr) arr.fill(-100); },
        getByteTimeDomainData: (arr) => { if (arr) arr.fill(128); },
        getFloatTimeDomainData: (arr) => { if (arr) arr.fill(0); }
      }),
      createBiquadFilter: () => ({
        type: 'lowpass',
        frequency: { value: 350, setValueAtTime: () => {} },
        Q: { value: 1, setValueAtTime: () => {} },
        gain: { value: 0, setValueAtTime: () => {} },
        detune: { value: 0 },
        connect: () => {},
        disconnect: () => {}
      }),
      createDelay: (maxTime) => ({
        delayTime: { value: 0, setValueAtTime: () => {} },
        connect: () => {},
        disconnect: () => {}
      }),
      createDynamicsCompressor: () => ({
        threshold: { value: -24 },
        knee: { value: 30 },
        ratio: { value: 12 },
        attack: { value: 0.003 },
        release: { value: 0.25 },
        reduction: 0,
        connect: () => {},
        disconnect: () => {}
      }),
      createOscillator: () => ({
        type: 'sine',
        frequency: { value: 440, setValueAtTime: () => {} },
        detune: { value: 0 },
        start: () => {},
        stop: () => {},
        connect: () => {},
        disconnect: () => {},
        onended: null
      }),
      createConvolver: () => ({
        buffer: null,
        normalize: true,
        connect: () => {},
        disconnect: () => {}
      }),
      createWaveShaper: () => ({
        curve: null,
        oversample: 'none',
        connect: () => {},
        disconnect: () => {}
      }),
      createMediaStreamSource: () => ({
        connect: () => {},
        disconnect: () => {}
      }),
      decodeAudioData: (data, success, error) => {
        // Return a fake empty AudioBuffer to allow loading to complete
        const fakeBuffer = {
          duration: 1,
          length: 44100,
          numberOfChannels: 2,
          sampleRate: 44100,
          getChannelData: (ch) => new Float32Array(44100),
          copyFromChannel: () => {},
          copyToChannel: () => {}
        };
        if (success) setTimeout(() => success(fakeBuffer), 10);
        return Promise.resolve(fakeBuffer);
      },
      resume: () => Promise.resolve(),
      suspend: () => Promise.resolve(),
      close: () => Promise.resolve()
    };
  };
}

// Disable service worker
globalThis.C2_RegisterSW = () => {};
globalThis.window.C2_RegisterSW = () => {};

// jQuery shim - comprehensive version for C2
globalThis.jQuery = globalThis.$ = function(selector) {
  // Determine the target element
  let target = null;
  if (selector === document || selector === globalThis.document) {
    target = document;
  } else if (selector === window || selector === globalThis.window || selector === globalThis) {
    target = globalThis;
  } else if (typeof selector === 'string') {
    if (selector.includes('c2canvas') || selector === '#c2canvas') {
      target = c2canvas;
    } else if (selector === 'body') {
      target = document.body;
    }
  } else if (selector && selector.addEventListener) {
    target = selector;
  }

  const obj = {
    0: target,
    length: target ? 1 : 0,
    ready: (fn) => { setTimeout(fn, 50); return obj; },
    on: (evt, fn) => {
      if (target && target.addEventListener) target.addEventListener(evt, fn);
      return obj;
    },
    off: (evt, fn) => {
      if (target && target.removeEventListener) target.removeEventListener(evt, fn);
      return obj;
    },
    // Event shorthand methods
    keydown: (fn) => { if (target && target.addEventListener) target.addEventListener('keydown', fn); return obj; },
    keyup: (fn) => { if (target && target.addEventListener) target.addEventListener('keyup', fn); return obj; },
    keypress: (fn) => { if (target && target.addEventListener) target.addEventListener('keypress', fn); return obj; },
    click: (fn) => { if (target && target.addEventListener) target.addEventListener('click', fn); return obj; },
    mousedown: (fn) => { if (target && target.addEventListener) target.addEventListener('mousedown', fn); return obj; },
    mouseup: (fn) => { if (target && target.addEventListener) target.addEventListener('mouseup', fn); return obj; },
    mousemove: (fn) => { if (target && target.addEventListener) target.addEventListener('mousemove', fn); return obj; },
    focus: (fn) => { if (fn) { if (target && target.addEventListener) target.addEventListener('focus', fn); } else if (target && target.focus) target.focus(); return obj; },
    blur: (fn) => { if (fn) { if (target && target.addEventListener) target.addEventListener('blur', fn); } else if (target && target.blur) target.blur(); return obj; },
    resize: (fn) => { if (target && target.addEventListener) target.addEventListener('resize', fn); return obj; },
    // DOM methods
    find: () => ({ length: 0, each: () => {}, get: () => [] }),
    each: (fn) => { if (target) fn.call(target, 0, target); return obj; },
    get: (i) => i === undefined ? [target] : target,
    css: (prop, val) => {
      if (target && target.style && typeof prop === 'string' && val !== undefined) {
        target.style[prop] = val;
      }
      return obj;
    },
    attr: (name, val) => {
      if (target && val !== undefined) target[name] = val;
      return obj;
    },
    appendTo: () => obj,
    append: () => obj,
    remove: () => obj,
    width: () => target === globalThis ? globalThis.innerWidth : (target ? target.width || target.offsetWidth : 320),
    height: () => target === globalThis ? globalThis.innerHeight : (target ? target.height || target.offsetHeight : 240),
    offset: () => ({ left: 0, top: 0 }),
    scrollTop: () => 0,
    scrollLeft: () => 0
  };

  // If selector is a function, call it when "ready"
  if (typeof selector === 'function') {
    setTimeout(selector, 50);
  }

  return obj;
};

globalThis.jQuery.fn = { jquery: '3.4.1' };
globalThis.jQuery.extend = function(target, ...sources) {
  for (const source of sources) {
    if (source) Object.assign(target, source);
  }
  return target;
};
globalThis.jQuery.ajax = (opts) => {
  const url = typeof opts === 'string' ? opts : opts.url;

  // Convert relative URL to absolute file path
  let filePath = url;
  if (!url.startsWith('/') && !url.startsWith('file://')) {
    filePath = globalThis._jsg.rom.romDir + '/' + url;
  }

  return fetch(filePath)
    .then(r => {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.text();
    })
    .then(data => {
      if (opts.success) opts.success(data);
      return data;
    })
    .catch(err => {
      if (opts.error) opts.error(err);
    });
};

// XMLHttpRequest enhancement for file loading
const OrigXHR = globalThis.XMLHttpRequest;
let xhrCount = 0;
globalThis.XMLHttpRequest = function() {
  const xhr = new OrigXHR();
  const origOpen = xhr.open.bind(xhr);
  const origSend = xhr.send.bind(xhr);
  const myXhrId = ++xhrCount;
  let myUrl = '';
  let myMethod = '';

  xhr.open = function(method, url, async) {
    myMethod = method;
    myUrl = url;
    let finalUrl = url;
    // Convert relative URLs
    if (!url.startsWith('/') && !url.startsWith('file://') && !url.startsWith('http')) {
      finalUrl = globalThis._jsg.rom.romDir + '/' + url;
    }
    return origOpen(method, finalUrl, async);
  };

  // Monitor onreadystatechange
  let _onReadyStateChange = null;
  Object.defineProperty(xhr, 'onreadystatechange', {
    get: () => _onReadyStateChange,
    set: (fn) => {
      _onReadyStateChange = function(evt) {
        if (fn) fn.call(xhr, evt);
      };
    }
  });

  // Intercept send to handle files that XHR can't load properly
  xhr.send = function(body) {

    // Handle audio files with fake response
    if (myUrl.endsWith('.ogg') || myUrl.endsWith('.mp3') || myUrl.endsWith('.wav')) {
      const fakeArrayBuffer = new ArrayBuffer(1024);
      Object.defineProperty(xhr, 'response', { value: fakeArrayBuffer, writable: false });
      Object.defineProperty(xhr, 'responseType', { value: 'arraybuffer', writable: true });
      Object.defineProperty(xhr, 'status', { value: 200, writable: false });
      Object.defineProperty(xhr, 'readyState', { value: 4, writable: false });
      setTimeout(() => { if (xhr.onload) xhr.onload({ target: xhr }); }, 5);
      return;
    }

    // Handle CSV files by reading directly from filesystem
    if (myUrl.endsWith('.csv')) {
      let filePath = myUrl;
      if (!myUrl.startsWith('/')) {
        filePath = globalThis._jsg.rom.romDir + '/' + myUrl;
      }
      try {
        const fs = require('fs');
        const data = fs.readFileSync(filePath, 'utf8');
        Object.defineProperty(xhr, 'responseText', { value: data, writable: false, configurable: true });
        Object.defineProperty(xhr, 'response', { value: data, writable: false, configurable: true });
        Object.defineProperty(xhr, 'status', { value: 200, writable: false, configurable: true });
        Object.defineProperty(xhr, 'readyState', { value: 4, writable: false, configurable: true });
        setTimeout(() => {
          if (_onReadyStateChange) _onReadyStateChange({ target: xhr });
          if (xhr.onload) xhr.onload({ target: xhr });
        }, 1);
        return;
      } catch (err) {
        Object.defineProperty(xhr, 'status', { value: 404, writable: false, configurable: true });
        Object.defineProperty(xhr, 'readyState', { value: 4, writable: false, configurable: true });
        setTimeout(() => {
          if (_onReadyStateChange) _onReadyStateChange({ target: xhr });
          if (xhr.onerror) xhr.onerror({ target: xhr });
        }, 1);
        return;
      }
    }

    return origSend(body);
  };

  return xhr;
};

// Load data.js first (contains project configuration)
try {
  require('./data.js');
} catch (err) {
  // data.js load failed
}

// Pre-load data.js using fetch (more reliable than XHR in JSGameLauncher)
async function initGame() {
  try {
    // Load c2runtime.js first
    require('./c2runtime.js');

    if (typeof cr_createRuntime !== 'function') {
      throw new Error('cr_createRuntime not defined!');
    }

    // Load data.js ourselves using fetch (use relative path)
    const response = await fetch('data.js');
    if (!response.ok) {
      throw new Error('Failed to fetch data.js: ' + response.status);
    }
    const dataText = await response.text();
    const projectData = JSON.parse(dataText);

    // Create runtime
    const runtime = cr_createRuntime('c2canvas');

    if (!runtime) {
      throw new Error('Runtime creation failed');
    }

    // Wrap runtime.canvas.getContext before C2 uses it
    if (runtime.canvas) {
      const runtimeOrigGetContext = runtime.canvas.getContext;
      runtime.canvas.getContext = function(type, opts) {
        if (type === '2d') {
          return cached2DContext;
        }
        if (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl') {
          return null;
        }
        if (runtimeOrigGetContext) {
          return runtimeOrigGetContext.call(this, type, opts);
        }
        return null;
      };
    }

    // Pre-set the 2D context
    runtime.Ba = cached2DContext;

    // Manually call the data processing function (Qh) to skip XHR
    if (typeof runtime.Qh === 'function') {
      try {
        runtime.Qh(projectData);
      } catch (qhErr) {
        // Qh error - silent
      }
    }

  } catch (err) {
    // Init error - silent
  }
}

initGame();

// Keep process alive
setInterval(() => {}, 1000);
