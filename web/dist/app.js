(() => {
  'use strict';

  const state = {
    historyLimit: 150,
    showTimestamps: true,
    hideState: 0,
    inputOpen: false,
    messages: [],
    suggestions: [],
    modes: {},
    templates: {},
    history: [],
    historyIndex: -1
  };

  const chat = document.getElementById('chat');
  const messages = document.getElementById('messages');
  const composer = document.getElementById('composer');
  const input = document.getElementById('input');
  const suggestions = document.getElementById('suggestions');
  const modeBadge = document.getElementById('modeBadge');

  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dex_chat';

  function nui(endpoint, payload = {}) {
    return fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload)
    }).catch(() => null);
  }

  function formatTime(timestamp) {
    const date = new Date((Number(timestamp) || Math.floor(Date.now() / 1000)) * 1000);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function textNode(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = value == null ? '' : String(value);
    return node;
  }

  function renderNormal(message) {
    const variant = message.presentation?.variant || 'normal';
    const card = document.createElement('article');
    card.className = `message ${variant}`;

    const header = document.createElement('div');
    header.className = 'message-header';

    if (message.channel) header.appendChild(textNode('span', 'channel', message.channel));
    if (message.sender?.name) header.appendChild(textNode('span', 'author', message.sender.name));
    if (state.showTimestamps) header.appendChild(textNode('time', 'timestamp', formatTime(message.timestamp)));

    if (header.childNodes.length) card.appendChild(header);
    card.appendChild(textNode('div', 'message-text', message.text));
    return card;
  }

  function renderBanner(message) {
    const presentation = message.presentation || {};
    const organization = message.organization || {};
    const card = document.createElement('article');
    card.className = 'message banner';
    card.style.setProperty('--primary', presentation.primary || '#2563EB');
    card.style.setProperty('--secondary', presentation.secondary || '#0F172A');
    card.style.borderColor = presentation.border || '#60A5FA';
    card.style.color = presentation.text || '#FFFFFF';

    const top = document.createElement('div');
    top.className = 'banner-top';
    const logo = document.createElement('div');
    logo.className = 'banner-logo';

    if (presentation.logo) {
      const image = document.createElement('img');
      image.src = presentation.logo;
      image.alt = organization.shortLabel || organization.label || 'Organization';
      image.addEventListener('error', () => {
        logo.replaceChildren(textNode('span', '', (organization.shortLabel || organization.label || 'ORG').slice(0, 5)));
      }, { once: true });
      logo.appendChild(image);
    } else {
      logo.textContent = (organization.shortLabel || organization.label || 'ORG').slice(0, 5);
    }

    const heading = document.createElement('div');
    heading.appendChild(textNode('div', 'banner-title', presentation.title || organization.label || 'Announcement'));
    heading.appendChild(textNode('div', 'banner-org', organization.label || organization.name || 'Organization'));
    top.append(logo, heading);

    const body = document.createElement('div');
    body.className = 'banner-body';
    body.appendChild(textNode('div', 'banner-text', message.text));

    const sender = message.sender?.name || 'Member';
    const grade = message.sender?.gradeLabel ? ` • ${message.sender.gradeLabel}` : '';
    const time = state.showTimestamps ? ` • ${formatTime(message.timestamp)}` : '';
    body.appendChild(textNode('div', 'banner-footer', `${sender}${grade}${time}`));

    card.append(top, body);
    return card;
  }

  function addMessage(message) {
    if (!message || typeof message.text !== 'string') return;

    const element = message.kind === 'organization' || message.presentation?.variant === 'banner'
      ? renderBanner(message)
      : renderNormal(message);

    const record = { id: message.id || `${Date.now()}-${Math.random()}`, element };
    state.messages.push(record);
    messages.appendChild(element);

    while (state.messages.length > state.historyLimit) {
      const removed = state.messages.shift();
      removed?.element.remove();
    }

    const duration = Math.max(1500, Number(message.duration) || 10000);
    window.setTimeout(() => {
      if (!state.inputOpen && state.hideState === 0) {
        element.classList.add('expired');
        window.setTimeout(() => element.remove(), 320);
      }
    }, duration);
  }

  function renderSuggestions() {
    const value = input.value.trim().toLowerCase();
    suggestions.replaceChildren();

    if (!value.startsWith('/')) {
      suggestions.classList.add('hidden');
      return;
    }

    const results = state.suggestions
      .filter(item => String(item.name || '').toLowerCase().startsWith(value.split(' ')[0]))
      .slice(0, 7);

    for (const item of results) {
      const row = document.createElement('div');
      row.className = 'suggestion';
      row.appendChild(textNode('span', 'suggestion-name', item.name));
      row.appendChild(textNode('span', 'suggestion-help', item.help || ''));
      suggestions.appendChild(row);
    }

    suggestions.classList.toggle('hidden', results.length === 0);
  }

  function setHideState(value) {
    state.hideState = Number(value) || 0;
    chat.classList.toggle('always-hidden', state.hideState === 2);
    chat.classList.toggle('passive', state.hideState === 0);
  }

  function openInput(data = {}) {
    state.inputOpen = true;
    composer.classList.remove('hidden');
    chat.classList.remove('always-hidden');
    if (data.maxLength) input.maxLength = Number(data.maxLength);
    if (Array.isArray(data.suggestions)) state.suggestions = data.suggestions;
    input.value = '';
    state.historyIndex = -1;
    input.focus();
    renderSuggestions();
  }

  function closeInput() {
    state.inputOpen = false;
    composer.classList.add('hidden');
    suggestions.classList.add('hidden');
    setHideState(state.hideState);
  }

  window.addEventListener('message', event => {
    const payload = event.data || {};
    const data = payload.data;

    switch (payload.action) {
      case 'CONFIGURE':
        state.historyLimit = Number(data?.historyLimit) || 150;
        state.showTimestamps = data?.showTimestamps !== false;
        setHideState(data?.hideState);
        break;
      case 'ADD_MESSAGE': addMessage(data); break;
      case 'CLEAR_MESSAGES': state.messages = []; messages.replaceChildren(); break;
      case 'OPEN_INPUT': openInput(data); break;
      case 'CLOSE_INPUT': closeInput(); break;
      case 'SET_SUGGESTIONS': state.suggestions = Array.isArray(data) ? data : []; renderSuggestions(); break;
      case 'SET_MODES': state.modes = data || {}; break;
      case 'ADD_TEMPLATE': if (data?.id) state.templates[data.id] = data.html; break;
      case 'SET_HIDE_STATE': setHideState(data); break;
    }
  });

  input.addEventListener('input', renderSuggestions);

  input.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      event.preventDefault();
      nui('close');
      closeInput();
      return;
    }

    if (event.key === 'Enter') {
      event.preventDefault();
      const message = input.value.trim();
      if (message) {
        state.history.unshift(message);
        state.history = state.history.slice(0, 50);
      }
      nui('submit', { message });
      closeInput();
      return;
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault();
      if (state.history.length) {
        state.historyIndex = Math.min(state.history.length - 1, state.historyIndex + 1);
        input.value = state.history[state.historyIndex] || '';
        renderSuggestions();
      }
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      state.historyIndex = Math.max(-1, state.historyIndex - 1);
      input.value = state.historyIndex === -1 ? '' : state.history[state.historyIndex] || '';
      renderSuggestions();
    }
  });

  nui('loaded');
})();
