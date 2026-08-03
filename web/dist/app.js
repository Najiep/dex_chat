(() => {
  'use strict';

  const state = {
    historyLimit: 200,
    hideState: 0,
    inputOpen: false,
    settingsOpen: false,
    messages: [],
    suggestions: [],
    modes: {},
    templates: {},
    history: [],
    historyIndex: -1,
    selectedSuggestion: 0,
    selectedChannel: null,
    quickChannels: [],
    themes: {},
    messageThemes: {},
    ui: {},
    preferences: {},
    permissions: {},
    maxLength: 250
  };

  const chat = document.getElementById('chat');
  const messages = document.getElementById('messages');
  const composer = document.getElementById('composer');
  const input = document.getElementById('input');
  const suggestions = document.getElementById('suggestions');
  const modeBadge = document.getElementById('modeBadge');
  const channelTabs = document.getElementById('channelTabs');
  const characterCounter = document.getElementById('characterCounter');
  const settingsButton = document.getElementById('settingsButton');
  const settingsPanel = document.getElementById('settings');
  const settingsClose = document.getElementById('settingsClose');
  const themeSelect = document.getElementById('themeSelect');
  const scaleRange = document.getElementById('scaleRange');
  const opacityRange = document.getElementById('opacityRange');
  const scaleValue = document.getElementById('scaleValue');
  const opacityValue = document.getElementById('opacityValue');
  const compactToggle = document.getElementById('compactToggle');
  const timestampsToggle = document.getElementById('timestampsToggle');
  const blurToggle = document.getElementById('blurToggle');
  const motionToggle = document.getElementById('motionToggle');
  const saveSettingsButton = document.getElementById('saveSettings');

  const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dex_chat';

  function nui(endpoint, payload = {}) {
    return fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload)
    }).then(response => response.json()).catch(() => null);
  }

  function textNode(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = value == null ? '' : String(value);
    return node;
  }

  function formatTime(timestamp) {
    const date = new Date((Number(timestamp) || Math.floor(Date.now() / 1000)) * 1000);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function appendMessageText(container, value) {
    const parts = String(value || '').split(/(@[\w-]+)/g);
    for (const part of parts) {
      if (/^@[\w-]+$/.test(part)) container.appendChild(textNode('span', 'mention', part));
      else container.appendChild(document.createTextNode(part));
    }
  }

  function applyTheme() {
    const selected = state.themes[state.preferences.theme] || state.themes[state.ui.Theme] || Object.values(state.themes)[0] || {};
    const root = document.documentElement;
    const tokens = {
      background: selected.background,
      surface: selected.surface,
      'surface-alt': selected.surfaceAlt,
      text: selected.text,
      muted: selected.muted,
      accent: selected.accent,
      border: selected.border,
      danger: selected.danger,
      success: selected.success
    };
    for (const [key, value] of Object.entries(tokens)) {
      if (value) root.style.setProperty(`--${key}`, value);
    }

    const scale = Number(state.preferences.scale ?? state.ui.Scale ?? 1);
    const opacity = Number(state.preferences.opacity ?? state.ui.Opacity ?? 0.96);
    root.style.setProperty('--chat-scale', String(Math.min(1.35, Math.max(0.75, scale))));
    root.style.setProperty('--chat-opacity', String(Math.min(1, Math.max(0.45, opacity))));
    root.style.setProperty('--chat-width', `${Number(state.ui.Width) || 560}px`);
    root.style.setProperty('--chat-max-height', `${Number(state.ui.MaxHeight) || 430}px`);

    chat.dataset.position = state.ui.Position || 'top-left';
    chat.classList.toggle('compact', state.preferences.compact === true);
    chat.classList.toggle('no-blur', state.preferences.blur === false);
    chat.classList.toggle('reduced-motion', state.preferences.reducedMotion === true);
  }

  function messageTheme(message) {
    const themeId = message.presentation?.themeId || message.presentation?.variant || message.kind || 'normal';
    return { ...(state.messageThemes[themeId] || state.messageThemes.normal || {}), ...(message.presentation || {}) };
  }

  function applyMessageTheme(card, theme) {
    if (theme.accent) card.style.setProperty('--message-accent', theme.accent);
    if (theme.background) card.style.setProperty('--message-background', theme.background);
    if (theme.text) card.style.setProperty('--message-text', theme.text);
  }

  function senderLabel(message) {
    const sender = message.sender?.name || '';
    const showId = state.permissions.showPlayerIds && Number(message.sender?.serverId) > 0;
    return showId ? `${sender} [${message.sender.serverId}]` : sender;
  }

  function renderNormal(message) {
    const theme = messageTheme(message);
    const card = document.createElement('article');
    card.className = `message ${message.presentation?.variant || message.kind || 'normal'}`;
    if (message.critical) card.classList.add('critical');
    applyMessageTheme(card, theme);

    const marker = document.createElement('span');
    marker.className = 'message-marker';
    marker.setAttribute('aria-hidden', 'true');
    card.appendChild(marker);

    const content = document.createElement('div');
    content.className = 'message-content';
    const header = document.createElement('div');
    header.className = 'message-header';

    if (message.channel) header.appendChild(textNode('span', 'channel', message.channel));
    const author = senderLabel(message);
    if (author) header.appendChild(textNode('span', 'author', author));
    if (message.sender?.gradeLabel) header.appendChild(textNode('span', 'grade', message.sender.gradeLabel));
    if (state.preferences.showTimestamps !== false) header.appendChild(textNode('time', 'timestamp', formatTime(message.timestamp)));
    if (header.childNodes.length) content.appendChild(header);

    const body = document.createElement('div');
    body.className = 'message-text';
    appendMessageText(body, message.text);
    content.appendChild(body);
    card.appendChild(content);
    return card;
  }

  function renderBanner(message) {
    const presentation = message.presentation || {};
    const organization = message.organization || {};
    const card = document.createElement('article');
    card.className = `message banner ${presentation.layout || 'expanded'}`;
    if (message.critical) card.classList.add('critical');
    card.style.setProperty('--primary', presentation.primary || '#2563EB');
    card.style.setProperty('--secondary', presentation.secondary || '#0F172A');
    card.style.setProperty('--banner-border', presentation.border || '#60A5FA');
    card.style.setProperty('--banner-text', presentation.text || '#FFFFFF');

    const top = document.createElement('div');
    top.className = 'banner-top';
    const logo = document.createElement('div');
    logo.className = 'banner-logo';
    const fallback = (organization.shortLabel || organization.label || 'ORG').slice(0, 5);

    if (presentation.logo && !/^https?:/i.test(presentation.logo)) {
      const image = document.createElement('img');
      image.src = presentation.logo;
      image.alt = organization.shortLabel || organization.label || 'Organization';
      image.addEventListener('error', () => logo.replaceChildren(textNode('span', '', fallback)), { once: true });
      logo.appendChild(image);
    } else {
      logo.textContent = fallback;
    }

    const heading = document.createElement('div');
    heading.className = 'banner-heading';
    heading.appendChild(textNode('div', 'banner-title', presentation.title || organization.label || 'Announcement'));
    heading.appendChild(textNode('div', 'banner-org', organization.label || organization.name || 'Organization'));
    top.append(logo, heading);

    const body = document.createElement('div');
    body.className = 'banner-body';
    const bannerText = document.createElement('div');
    bannerText.className = 'banner-text';
    appendMessageText(bannerText, message.text);
    body.appendChild(bannerText);

    const footerParts = [];
    if (message.sender?.name) footerParts.push(senderLabel(message));
    if (message.sender?.gradeLabel) footerParts.push(message.sender.gradeLabel);
    if (state.preferences.showTimestamps !== false) footerParts.push(formatTime(message.timestamp));
    if (footerParts.length) body.appendChild(textNode('div', 'banner-footer', footerParts.join(' • ')));

    card.append(top, body);
    return card;
  }

  function refreshVisibility() {
    chat.classList.toggle('input-active', state.inputOpen);
    chat.classList.toggle('settings-active', state.settingsOpen);
    chat.classList.toggle('always-hidden', state.hideState === 2);
    chat.classList.toggle('always-show', state.hideState === 1);
    chat.classList.toggle('auto-hide', state.hideState === 0);
  }

  function addMessage(message) {
    if (!message || typeof message.text !== 'string') return;
    const element = message.kind === 'organization' || message.presentation?.variant === 'banner'
      ? renderBanner(message)
      : renderNormal(message);

    const record = { id: message.id || `${Date.now()}-${Math.random()}`, element, critical: message.critical === true };
    state.messages.push(record);
    messages.appendChild(element);

    while (state.messages.length > state.historyLimit) {
      state.messages.shift()?.element.remove();
    }

    window.setTimeout(() => element.classList.add('expired'), Math.max(1500, Number(message.duration) || 12000));
  }

  function setHideState(value) {
    state.hideState = Number(value) || 0;
    refreshVisibility();
  }

  function selectedChannel() {
    return state.quickChannels.find(channel => channel.key === state.selectedChannel) || state.quickChannels[0] || null;
  }

  function selectChannel(key) {
    const channel = state.quickChannels.find(item => item.key === key);
    if (!channel) return;
    state.selectedChannel = channel.key;
    modeBadge.textContent = channel.label;
    for (const button of channelTabs.querySelectorAll('button')) {
      button.classList.toggle('active', button.dataset.channel === channel.key);
    }
  }

  function renderChannels() {
    channelTabs.replaceChildren();
    if (state.ui.ShowChannelTabs === false) {
      channelTabs.classList.add('hidden');
      return;
    }
    channelTabs.classList.remove('hidden');

    for (const channel of state.quickChannels) {
      const button = textNode('button', 'channel-tab', channel.label);
      button.type = 'button';
      button.dataset.channel = channel.key;
      button.addEventListener('click', () => selectChannel(channel.key));
      channelTabs.appendChild(button);
    }

    const preferred = state.quickChannels.some(channel => channel.key === state.selectedChannel)
      ? state.selectedChannel
      : state.quickChannels[0]?.key;
    if (preferred) selectChannel(preferred);
  }

  function matchingSuggestions() {
    const value = input.value.trim().toLowerCase();
    if (!value.startsWith('/')) return [];
    const command = value.split(' ')[0];
    return state.suggestions
      .filter(item => String(item.name || '').toLowerCase().startsWith(command))
      .slice(0, 8);
  }

  function fillSuggestion(item) {
    if (!item?.name) return;
    input.value = `${item.name} `;
    input.focus();
    updateCharacterCounter();
    renderSuggestions();
  }

  function renderSuggestions() {
    const results = matchingSuggestions();
    suggestions.replaceChildren();
    state.selectedSuggestion = Math.min(state.selectedSuggestion, Math.max(0, results.length - 1));

    results.forEach((item, index) => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'suggestion';
      row.setAttribute('role', 'option');
      row.classList.toggle('selected', index === state.selectedSuggestion);
      row.appendChild(textNode('span', 'suggestion-name', item.name));
      row.appendChild(textNode('span', 'suggestion-help', item.help || ''));
      row.addEventListener('click', () => fillSuggestion(item));
      suggestions.appendChild(row);
    });

    suggestions.classList.toggle('hidden', results.length === 0);
  }

  function updateCharacterCounter() {
    const current = input.value.length;
    characterCounter.textContent = `${current}/${input.maxLength}`;
    characterCounter.classList.toggle('near-limit', current >= input.maxLength * 0.8);
    characterCounter.classList.toggle('hidden', state.ui.ShowCharacterCounter === false);
  }

  function openInput(data = {}) {
    state.inputOpen = true;
    state.settingsOpen = false;
    composer.classList.remove('hidden');
    settingsPanel.classList.add('hidden');
    if (data.maxLength) input.maxLength = Number(data.maxLength);
    if (Array.isArray(data.suggestions)) state.suggestions = data.suggestions;
    if (data.modes) state.modes = data.modes;
    input.value = '';
    state.historyIndex = -1;
    state.selectedSuggestion = 0;
    input.focus();
    renderChannels();
    renderSuggestions();
    updateCharacterCounter();
    refreshVisibility();
  }

  function closeInput() {
    state.inputOpen = false;
    composer.classList.add('hidden');
    suggestions.classList.add('hidden');
    refreshVisibility();
  }

  function populateSettings() {
    themeSelect.replaceChildren();
    for (const [key, theme] of Object.entries(state.themes)) {
      const option = document.createElement('option');
      option.value = key;
      option.textContent = theme.label || key;
      themeSelect.appendChild(option);
    }

    themeSelect.value = state.preferences.theme || state.ui.Theme || '';
    scaleRange.value = String(state.preferences.scale ?? state.ui.Scale ?? 1);
    opacityRange.value = String(state.preferences.opacity ?? state.ui.Opacity ?? 0.96);
    compactToggle.checked = state.preferences.compact === true;
    timestampsToggle.checked = state.preferences.showTimestamps !== false;
    blurToggle.checked = state.preferences.blur !== false;
    motionToggle.checked = state.preferences.reducedMotion === true;
    updateSettingsLabels();
  }

  function updateSettingsLabels() {
    scaleValue.textContent = `${Math.round(Number(scaleRange.value) * 100)}%`;
    opacityValue.textContent = `${Math.round(Number(opacityRange.value) * 100)}%`;
  }

  function openSettings(data = {}) {
    state.inputOpen = false;
    state.settingsOpen = true;
    composer.classList.add('hidden');
    settingsPanel.classList.remove('hidden');
    if (data.preferences) state.preferences = { ...state.preferences, ...data.preferences };
    if (data.themes) state.themes = data.themes;
    populateSettings();
    refreshVisibility();
  }

  function closeSettings() {
    state.settingsOpen = false;
    settingsPanel.classList.add('hidden');
    refreshVisibility();
  }

  async function saveSettings() {
    const next = {
      theme: themeSelect.value,
      scale: Number(scaleRange.value),
      opacity: Number(opacityRange.value),
      compact: compactToggle.checked,
      showTimestamps: timestampsToggle.checked,
      blur: blurToggle.checked,
      reducedMotion: motionToggle.checked
    };
    const response = await nui('saveSettings', next);
    state.preferences = { ...state.preferences, ...(response?.preferences || next) };
    applyTheme();
    for (const record of state.messages) {
      const timestamp = record.element.querySelector('.timestamp');
      if (timestamp) timestamp.classList.toggle('hidden', state.preferences.showTimestamps === false);
    }
    closeSettings();
  }

  function applyConfiguration(data = {}) {
    state.historyLimit = Number(data.historyLimit) || 200;
    state.ui = data.ui || {};
    state.themes = data.themes || {};
    state.messageThemes = data.messageThemes || {};
    state.preferences = { ...(data.preferences || {}) };
    state.quickChannels = Array.isArray(data.quickChannels) ? data.quickChannels : [];
    state.permissions = data.permissions || {};
    state.maxLength = Number(data.maxLength) || 250;
    input.maxLength = state.maxLength;
    settingsButton.classList.toggle('hidden', state.ui.ShowSettingsButton === false);
    setHideState(data.hideState);
    applyTheme();
    renderChannels();
    updateCharacterCounter();
  }

  window.addEventListener('message', event => {
    const payload = event.data || {};
    const data = payload.data;

    switch (payload.action) {
      case 'CONFIGURE': applyConfiguration(data); break;
      case 'ADD_MESSAGE': addMessage(data); break;
      case 'CLEAR_MESSAGES': state.messages = []; messages.replaceChildren(); break;
      case 'OPEN_INPUT': openInput(data); break;
      case 'CLOSE_INPUT': closeInput(); break;
      case 'OPEN_SETTINGS': openSettings(data); break;
      case 'CLOSE_SETTINGS': closeSettings(); break;
      case 'SET_SUGGESTIONS': state.suggestions = Array.isArray(data) ? data : []; renderSuggestions(); break;
      case 'SET_MODES': state.modes = data || {}; break;
      case 'ADD_TEMPLATE': if (data?.id) state.templates[data.id] = data.html; break;
      case 'SET_HIDE_STATE': setHideState(data); break;
    }
  });

  input.addEventListener('input', () => {
    state.selectedSuggestion = 0;
    renderSuggestions();
    updateCharacterCounter();
  });

  input.addEventListener('keydown', event => {
    const results = matchingSuggestions();

    if (event.key === 'Escape') {
      event.preventDefault();
      nui('close');
      closeInput();
      return;
    }

    if (event.key === 'Tab' && results.length) {
      event.preventDefault();
      fillSuggestion(results[state.selectedSuggestion] || results[0]);
      return;
    }

    if (event.key === 'ArrowDown' && results.length) {
      event.preventDefault();
      state.selectedSuggestion = (state.selectedSuggestion + 1) % results.length;
      renderSuggestions();
      return;
    }

    if (event.key === 'ArrowUp' && results.length) {
      event.preventDefault();
      state.selectedSuggestion = (state.selectedSuggestion - 1 + results.length) % results.length;
      renderSuggestions();
      return;
    }

    if (event.key === 'Enter') {
      event.preventDefault();
      let message = input.value.trim();
      const channel = selectedChannel();
      if (message && !message.startsWith('/') && channel?.command) message = `/${channel.command} ${message}`;
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
        updateCharacterCounter();
      }
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      state.historyIndex = Math.max(-1, state.historyIndex - 1);
      input.value = state.historyIndex === -1 ? '' : state.history[state.historyIndex] || '';
      updateCharacterCounter();
    }
  });

  settingsButton.addEventListener('click', () => nui('openSettings'));
  settingsClose.addEventListener('click', () => { nui('close'); closeSettings(); });
  saveSettingsButton.addEventListener('click', saveSettings);
  scaleRange.addEventListener('input', updateSettingsLabels);
  opacityRange.addEventListener('input', updateSettingsLabels);

  window.addEventListener('keydown', event => {
    if (event.key === 'Escape' && state.settingsOpen) {
      nui('close');
      closeSettings();
    }
  });

  nui('loaded');
})();
