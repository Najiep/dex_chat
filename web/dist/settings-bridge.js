(() => {
  'use strict';

  const saveButton = document.getElementById('saveSettings');
  if (!saveButton) return;

  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dex_chat';
  saveButton.addEventListener('click', () => {
    window.setTimeout(() => {
      fetch(`https://${resourceName}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}'
      }).catch(() => null);
    }, 100);
  });
})();
