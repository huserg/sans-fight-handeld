/**
 * Gamepad to Keyboard Mapper for Construct 2 games
 * Maps gamepad inputs to keyboard events that C2 runtime expects
 */

(function() {
  var previousButtonStates = {};
  var previousAxisStates = {};
  var DEADZONE = 0.3;

  // Gamepad button mapping (standard gamepad layout)
  var BUTTON_MAP = {
    0: 'KeyZ',       // A button -> Z (confirm)
    1: 'KeyX',       // B button -> X (cancel/back)
    2: 'KeyC',       // X button -> C
    3: 'KeyV',       // Y button -> V
    12: 'ArrowUp',   // D-pad Up
    13: 'ArrowDown', // D-pad Down
    14: 'ArrowLeft', // D-pad Left
    15: 'ArrowRight',// D-pad Right
    9: 'Escape',     // Start -> Escape
    8: 'Enter'       // Select -> Enter
  };

  var KEY_CODES = {
    'ArrowUp': 38,
    'ArrowDown': 40,
    'ArrowLeft': 37,
    'ArrowRight': 39,
    'KeyZ': 90,
    'KeyX': 88,
    'KeyC': 67,
    'KeyV': 86,
    'Enter': 13,
    'Escape': 27
  };

  function dispatchKeyEvent(type, keyName) {
    var keyCode = KEY_CODES[keyName] || 0;
    var key = keyName.replace('Key', '').replace('Arrow', '');

    var event;
    try {
      event = new KeyboardEvent(type, {
        key: key,
        code: keyName,
        keyCode: keyCode,
        which: keyCode,
        bubbles: true,
        cancelable: true
      });
    } catch (e) {
      // Fallback for older environments
      event = document.createEvent('KeyboardEvent');
      event.initKeyboardEvent(type, true, true, window, key, 0, '', false, '');
      Object.defineProperty(event, 'keyCode', { get: function() { return keyCode; } });
      Object.defineProperty(event, 'which', { get: function() { return keyCode; } });
    }

    document.dispatchEvent(event);

    // Also dispatch to canvas directly
    var canvas = document.getElementById('c2canvas');
    if (canvas) {
      canvas.dispatchEvent(event);
    }
  }

  function processGamepad(gamepad, index) {
    if (!gamepad) return;

    var prevButtons = previousButtonStates[index] || {};
    var prevAxes = previousAxisStates[index] || {};

    // Process buttons
    for (var btnIndex = 0; btnIndex < gamepad.buttons.length; btnIndex++) {
      var keyName = BUTTON_MAP[btnIndex];
      if (!keyName) continue;

      var wasPressed = prevButtons[btnIndex] || false;
      var isPressed = gamepad.buttons[btnIndex].pressed;

      if (isPressed && !wasPressed) {
        dispatchKeyEvent('keydown', keyName);
      } else if (!isPressed && wasPressed) {
        dispatchKeyEvent('keyup', keyName);
      }

      prevButtons[btnIndex] = isPressed;
    }

    // Process left analog stick as D-pad
    if (gamepad.axes.length >= 2) {
      var axisX = gamepad.axes[0];
      var axisY = gamepad.axes[1];

      var wasLeft = prevAxes.left || false;
      var wasRight = prevAxes.right || false;
      var isLeft = axisX < -DEADZONE;
      var isRight = axisX > DEADZONE;

      if (isLeft && !wasLeft) dispatchKeyEvent('keydown', 'ArrowLeft');
      else if (!isLeft && wasLeft) dispatchKeyEvent('keyup', 'ArrowLeft');

      if (isRight && !wasRight) dispatchKeyEvent('keydown', 'ArrowRight');
      else if (!isRight && wasRight) dispatchKeyEvent('keyup', 'ArrowRight');

      var wasUp = prevAxes.up || false;
      var wasDown = prevAxes.down || false;
      var isUp = axisY < -DEADZONE;
      var isDown = axisY > DEADZONE;

      if (isUp && !wasUp) dispatchKeyEvent('keydown', 'ArrowUp');
      else if (!isUp && wasUp) dispatchKeyEvent('keyup', 'ArrowUp');

      if (isDown && !wasDown) dispatchKeyEvent('keydown', 'ArrowDown');
      else if (!isDown && wasDown) dispatchKeyEvent('keyup', 'ArrowDown');

      prevAxes.left = isLeft;
      prevAxes.right = isRight;
      prevAxes.up = isUp;
      prevAxes.down = isDown;
    }

    previousButtonStates[index] = prevButtons;
    previousAxisStates[index] = prevAxes;
  }

  function poll() {
    var gamepads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (var i = 0; i < gamepads.length; i++) {
      processGamepad(gamepads[i], i);
    }
    requestAnimationFrame(poll);
  }

  function init() {
    console.log('[GamepadMapper] Initializing...');

    window.addEventListener('gamepadconnected', function(e) {
      console.log('[GamepadMapper] Connected:', e.gamepad.id);
    });

    window.addEventListener('gamepaddisconnected', function(e) {
      console.log('[GamepadMapper] Disconnected:', e.gamepad.id);
      delete previousButtonStates[e.gamepad.index];
      delete previousAxisStates[e.gamepad.index];
    });

    poll();
  }

  // Initialize when ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
