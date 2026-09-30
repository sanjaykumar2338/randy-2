(() => {
  // Stock chat reloads theme scripts when resources start/stop. Replace our
  // listeners rather than accumulating handlers in the shared chat document.
  const owner = '__tarrantChatCancel';
  window[owner]?.();

  const theme = 'tarrant_chat_cancel';
  const dismissedClass = 'tarrant-chat-cancelled';
  const restore = () => document.documentElement.classList.remove(dismissedClass);

  function onKeyUp(event) {
    if (event.key !== 'Escape' ||
        !(event.target instanceof HTMLTextAreaElement) ||
        !event.target.matches('.chat-input textarea') ||
        event.target.getClientRects().length === 0) return;

    // Capture before Vue hides the input. Do not consume the event: the stock
    // Escape handler must still post chatResult and release NUI focus.
    document.documentElement.classList.add(dismissedClass);
  }

  function onMessage(event) {
    const data = event.data || event.detail;
    if (!data) return;

    if (data.type === 'ON_UPDATE_THEMES' && !data.themes?.[theme]) {
      cleanup();
    } else if (['ON_OPEN', 'ON_MESSAGE', 'ON_CLEAR', 'ON_SCREEN_STATE_CHANGE'].includes(data.type)) {
      // Remove only our temporary visual override. Stock chat still decides
      // whether to display/fade based on the unchanged user's visibility mode.
      restore();
    }
  }

  function cleanup() {
    window.removeEventListener('keyup', onKeyUp, true);
    window.removeEventListener('message', onMessage);
    restore();
    delete window[owner];
  }

  window[owner] = cleanup;
  window.addEventListener('keyup', onKeyUp, true);
  window.addEventListener('message', onMessage);
})();
