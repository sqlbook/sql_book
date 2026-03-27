import { Controller } from '@hotwired/stimulus';

const MAX_IMAGE_COUNT = 6;
const MAX_IMAGE_SIZE_BYTES = 25 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

type JsonPayload = Record<string, unknown>;
type ChatAttachmentPayload = {
  id: number;
  filename: string;
  content_type: string;
  byte_size: number;
  url: string;
};

type ChatMessagePayload = {
  id: number;
  role: string;
  status: string;
  content: string;
  content_html?: string;
  metadata?: Record<string, unknown>;
  images?: ChatAttachmentPayload[];
};

export default class extends Controller<HTMLDivElement> {
  static targets = [
    'form',
    'textInput',
    'fileInput',
    'attachmentTray',
    'attachmentError',
    'messages',
    'threadInput',
    'sidebar',
    'sidebarOpenButton',
    'sidebarCloseButton',
    'threadSearchInput',
    'threadSearchClear',
    'threadRow',
    'threadListEmpty'
  ];

  static values = {
    workspaceId: Number,
    threadId: Number,
    i18n: Object,
    sidebarDefaultOpen: Boolean,
    newChatPath: String,
    mobileBreakpoint: Number
  };

  declare readonly formTarget: HTMLFormElement;
  declare readonly textInputTarget: HTMLInputElement;
  declare readonly fileInputTarget: HTMLInputElement;
  declare readonly attachmentTrayTarget: HTMLDivElement;
  declare readonly attachmentErrorTarget: HTMLParagraphElement;
  declare readonly messagesTarget: HTMLDivElement;
  declare readonly threadInputTarget: HTMLInputElement;
  declare readonly sidebarTarget: HTMLElement;
  declare readonly sidebarOpenButtonTarget: HTMLButtonElement;
  declare readonly sidebarCloseButtonTarget: HTMLButtonElement;
  declare readonly threadSearchInputTarget: HTMLInputElement;
  declare readonly threadSearchClearTarget: HTMLButtonElement;
  declare readonly threadRowTargets: HTMLElement[];
  declare readonly threadListEmptyTarget: HTMLElement;

  declare readonly hasMessagesTarget: boolean;
  declare readonly hasThreadInputTarget: boolean;
  declare readonly hasSidebarTarget: boolean;
  declare readonly hasSidebarOpenButtonTarget: boolean;
  declare readonly hasSidebarCloseButtonTarget: boolean;
  declare readonly hasThreadSearchInputTarget: boolean;
  declare readonly hasThreadSearchClearTarget: boolean;
  declare readonly hasThreadListEmptyTarget: boolean;

  declare readonly workspaceIdValue: number;
  declare readonly threadIdValue: number;
  declare readonly i18nValue: Record<string, string>;
  declare readonly sidebarDefaultOpenValue: boolean;
  declare readonly newChatPathValue: string;
  declare readonly mobileBreakpointValue: number;

  private selectedFiles: File[] = [];
  private previewUrls: string[] = [];
  private optimisticMessageElements: HTMLElement[] = [];
  private pendingDraft: { content: string; files: File[] } | null = null;
  private submitting = false;
  private openMenuRow: HTMLElement | null = null;
  private renamingRow: HTMLElement | null = null;

  private readonly onDocumentClick = (event: Event): void => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.closest('.chat-history-thread-actions')) return;

    this.closeThreadMenu();
  };

  public connect(): void {
    this.renderAttachmentTray();
    this.initializeSidebar();
    this.updateThreadSearchVisibility();
    this.refreshThreadEmptyState();
    requestAnimationFrame(() => this.scrollConversationToBottom(true));
    this.restoreComposerFocus();
    document.addEventListener('click', this.onDocumentClick);
  }

  public disconnect(): void {
    this.revokePreviewUrls();
    document.removeEventListener('click', this.onDocumentClick);
  }

  public useSuggestion(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const suggestion = target.dataset.suggestion;
    if (!suggestion) return;

    this.textInputTarget.value = suggestion;
    this.textInputTarget.focus();
  }

  public onFileChange(event: Event): void {
    const target = event.target as HTMLInputElement;
    const incomingFiles = Array.from(target.files || []);
    let validationError = '';

    incomingFiles.forEach((file) => {
      if (this.selectedFiles.length >= MAX_IMAGE_COUNT) {
        validationError = this.translate('maxImagesError');
        return;
      }

      if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
        validationError = this.translate('unsupportedImagesError');
        return;
      }

      if (file.size > MAX_IMAGE_SIZE_BYTES) {
        validationError = this.translate('imageTooLargeError');
        return;
      }

      this.selectedFiles.push(file);
    });

    this.syncFileInput();
    this.renderAttachmentTray();
    this.setAttachmentError(validationError);
  }

  public removeAttachment(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const index = Number(target.dataset.index);
    if (Number.isNaN(index)) return;

    this.selectedFiles.splice(index, 1);
    this.syncFileInput();
    this.renderAttachmentTray();
    this.setAttachmentError('');
  }

  public submit(event: Event): void {
    event.preventDefault();
    if (this.submitting) return;

    const draftContent = this.textInputTarget.value;
    const content = draftContent.trim();
    const requestThreadId = this.currentThreadId();
    if (requestThreadId > 0) this.rememberComposerFocus(requestThreadId);
    else this.clearComposerFocusRequest();

    if (!content && this.selectedFiles.length === 0) {
      this.setAttachmentError(this.translate('messageRequiredError'));
      return;
    }

    const draftFiles = [...this.selectedFiles];
    const formData = new FormData(this.formTarget);
    this.submitting = true;
    this.pendingDraft = { content: draftContent, files: draftFiles };
    this.appendOptimisticMessages(content);
    this.clearComposer();
    this.setAttachmentError('');
    this.setSubmittingState(true);

    this.fetchJson(this.formTarget.action, formData)
      .then((data) => {
        this.pendingDraft = null;
        const redirectPath = this.stringValue(data.redirect_path);
        if (redirectPath) {
          window.Turbo.visit(redirectPath);
          return;
        }

        const threadId = this.numberValue(data.thread_id);
        if (threadId > 0 && this.currentThreadId() <= 0) this.persistSidebarPreference(true);

        if (this.shouldRenderInlineResponse(data, threadId, requestThreadId)) {
          this.applyInlineResponse(data, threadId);
          return;
        }

        this.visitWorkspace(threadId);
      })
      .catch((error) => {
        this.removeOptimisticMessages();
        this.restorePendingDraft();
        this.clearComposerFocusRequest();
        this.setAttachmentError(error.message || this.translate('genericError'));
      })
      .finally(() => {
        this.submitting = false;
        this.setSubmittingState(false);
      });
  }

  public confirmAction(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const actionId = target.dataset.actionId;
    const confirmationToken = target.dataset.confirmationToken;
    const threadId = this.currentThreadId();
    if (!actionId || !confirmationToken || threadId <= 0) return;

    const formData = new FormData();
    formData.set('thread_id', String(threadId));
    formData.set('confirmation_token', confirmationToken);

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/actions/${actionId}/confirm`;
    this.fetchJson(path, formData)
      .then((data) => {
        const redirectPath = this.stringValue(data.redirect_path);
        if (redirectPath) {
          window.Turbo.visit(redirectPath);
          return;
        }

        this.visitWorkspace(threadId);
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('confirmActionError'));
      });
  }

  public cancelAction(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const actionId = target.dataset.actionId;
    const threadId = this.currentThreadId();
    if (!actionId || threadId <= 0) return;

    const formData = new FormData();
    formData.set('thread_id', String(threadId));

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/actions/${actionId}/cancel`;
    this.fetchJson(path, formData)
      .then(() => {
        this.visitWorkspace(threadId);
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('cancelActionError'));
      });
  }

  public saveQueryCard(event: Event): void {
    this.submitQueryCardAction(event, 'save');
  }

  public saveQueryCardAsNew(event: Event): void {
    this.submitQueryCardAction(event, 'save-as-new');
  }

  public saveQueryCardChanges(event: Event): void {
    this.submitQueryCardAction(event, 'save-changes');
  }

  public toggleSidebar(event: Event): void {
    event.preventDefault();
    this.setSidebarOpen(!this.sidebarOpen());
  }

  public startNewChat(event: Event): void {
    event.preventDefault();
    this.closeThreadMenu();
    this.cancelRename();
    this.persistSidebarPreference(true);
    window.Turbo.visit(this.newChatPathValue, { action: 'replace' });
  }

  public openThread(event: Event): void {
    event.preventDefault();
    if (this.renamingRow) return;

    const row = this.rowFromEvent(event);
    if (!row) return;

    const path = row.dataset.threadPath;
    if (!path) return;

    if (window.innerWidth <= this.mobileBreakpointValue) this.persistSidebarPreference(false);

    window.Turbo.visit(path, { action: 'replace' });
  }

  public searchThreads(): void {
    this.updateThreadSearchVisibility();
  }

  public clearThreadSearch(event: Event): void {
    event.preventDefault();
    if (!this.hasThreadSearchInputTarget) return;

    this.threadSearchInputTarget.value = '';
    this.updateThreadSearchVisibility();
    this.threadSearchInputTarget.focus();
  }

  public toggleThreadMenu(event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    const row = this.rowFromEvent(event);
    if (!row) return;

    if (this.openMenuRow && this.openMenuRow !== row) this.openMenuRow.classList.remove('menu-open');

    const isOpen = row.classList.toggle('menu-open');
    this.openMenuRow = isOpen ? row : null;
  }

  public beginRenameThread(event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    const row = this.rowFromEvent(event);
    if (!row) return;

    this.closeThreadMenu();
    this.activateRename(row);
  }

  public renameKeydown(event: Event): void {
    const keyboardEvent = event as KeyboardEvent;
    const input = event.currentTarget as HTMLInputElement;

    if (keyboardEvent.key === 'Escape') {
      keyboardEvent.preventDefault();
      this.cancelRename();
      return;
    }

    if (keyboardEvent.key !== 'Enter') return;

    keyboardEvent.preventDefault();
    this.commitRename(input);
  }

  public renameBlur(event: Event): void {
    const input = event.currentTarget as HTMLInputElement;
    this.commitRename(input);
  }

  public deleteThread(event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    const row = this.rowFromEvent(event);
    if (!row) return;

    const threadId = Number(row.dataset.threadId);
    if (Number.isNaN(threadId)) return;

    if (!window.confirm(this.translate('deleteThreadConfirmation'))) return;

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/threads/${threadId}`;
    this.fetchJson(path, new FormData(), 'DELETE')
      .then((data) => {
        const redirectPath = this.stringValue(data.redirect_path);
        if (redirectPath || row.classList.contains('is-active')) {
          window.Turbo.visit(redirectPath || this.newChatPathValue, { action: 'replace' });
          return;
        }

        row.remove();
        this.refreshThreadEmptyState();
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('deleteThreadFailedError'));
      })
      .finally(() => {
        this.closeThreadMenu();
      });
  }

  private fetchJson(path: string, body: FormData, method = 'POST'): Promise<JsonPayload> {
    const csrfToken = this.csrfToken();
    this.appendAuthenticityToken(body, csrfToken);

    return fetch(path, {
      method,
      body,
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': csrfToken
      }
    }).then(async (response) => {
      const raw = await response.text();
      const data = raw ? (JSON.parse(raw) as JsonPayload) : {};

      if (!response.ok) throw new Error(this.stringValue(data.message) || this.translate('requestFailedError'));

      return data;
    });
  }

  private submitQueryCardAction(event: Event, action: 'save' | 'save-as-new' | 'save-changes'): void {
    event.preventDefault();

    const target = event.currentTarget as HTMLElement;
    const messageId = target.dataset.messageId;
    const threadId = this.currentThreadId();
    if (!messageId || threadId <= 0) return;

    target.setAttribute('aria-busy', 'true');
    (target as HTMLButtonElement).disabled = true;

    const formData = new FormData();
    formData.set('thread_id', String(threadId));

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/query-cards/${messageId}/${action}`;
    this.fetchJson(path, formData)
      .then((data) => {
        this.applyQueryCardResponse(data);
        this.setAttachmentError('');
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('requestFailedError'));
      })
      .finally(() => {
        target.removeAttribute('aria-busy');
        (target as HTMLButtonElement).disabled = false;
      });
  }

  private csrfToken(): string {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';
  }

  private appendAuthenticityToken(body: FormData, csrfToken: string): void {
    if (!csrfToken || body.has('authenticity_token')) return;

    body.set('authenticity_token', csrfToken);
  }

  private syncFileInput(): void {
    const dataTransfer = new DataTransfer();
    this.selectedFiles.forEach((file) => dataTransfer.items.add(file));
    this.fileInputTarget.files = dataTransfer.files;
  }

  private renderAttachmentTray(): void {
    this.revokePreviewUrls();
    this.attachmentTrayTarget.innerHTML = '';

    this.selectedFiles.forEach((file, index) => {
      const wrapper = document.createElement('div');
      wrapper.className = 'chat-attachment-preview';

      const image = document.createElement('img');
      image.className = 'chat-attachment-thumb';
      image.alt = file.name;
      image.src = URL.createObjectURL(file);
      this.previewUrls.push(image.src);

      const removeButton = document.createElement('button');
      removeButton.type = 'button';
      removeButton.className = 'chat-attachment-remove';
      removeButton.dataset.index = String(index);
      removeButton.dataset.action = 'workspace-chat#removeAttachment';
      removeButton.textContent = 'x';
      removeButton.setAttribute('aria-label', this.removeAttachmentAriaLabel(file.name));

      wrapper.appendChild(image);
      wrapper.appendChild(removeButton);
      this.attachmentTrayTarget.appendChild(wrapper);
    });
  }

  private revokePreviewUrls(): void {
    this.previewUrls.forEach((url) => URL.revokeObjectURL(url));
    this.previewUrls = [];
  }

  private setAttachmentError(message: string): void {
    this.attachmentErrorTarget.textContent = message;
  }

  private setSubmittingState(submitting: boolean): void {
    this.element.classList.toggle('is-submitting', submitting);
    this.textInputTarget.readOnly = submitting;
    this.fileInputTarget.disabled = submitting;
  }

  private translate(key: string): string {
    const value = this.i18nValue?.[key];
    return value || '';
  }

  private removeAttachmentAriaLabel(filename: string): string {
    const template = this.translate('removeAttachmentAria');
    return template.replace('%{filename}', filename);
  }

  private appendOptimisticMessages(content: string): void {
    this.removeOptimisticMessages();
    const messageStream = this.ensureMessageStream();
    if (!messageStream) return;

    const inserted: HTMLElement[] = [];

    if (content) {
      const userArticle = document.createElement('article');
      userArticle.className = 'chat-message chat-message-user chat-message-pending';
      userArticle.dataset.optimistic = 'true';

      const userBubble = document.createElement('div');
      userBubble.className = 'chat-user-bubble';

      const userBody = document.createElement('p');
      userBody.className = 'chat-message-body';
      userBody.textContent = content;

      userBubble.appendChild(userBody);
      userArticle.appendChild(userBubble);
      messageStream.appendChild(userArticle);
      inserted.push(userArticle);
    }

    const thinkingArticle = document.createElement('article');
    thinkingArticle.className = 'chat-message chat-message-system chat-message-pending';
    thinkingArticle.dataset.optimistic = 'true';

    const thinkingRow = document.createElement('p');
    thinkingRow.className = 'chat-system-row chat-system-row-thinking';
    thinkingRow.textContent = this.translate('thinkingStatus') || 'Thinking';

    const thinkingDots = document.createElement('span');
    thinkingDots.className = 'chat-thinking-dots';
    thinkingDots.setAttribute('aria-hidden', 'true');
    ['.', '.', '.'].forEach((dot) => {
      const dotSpan = document.createElement('span');
      dotSpan.textContent = dot;
      thinkingDots.appendChild(dotSpan);
    });

    thinkingArticle.appendChild(thinkingRow);
    thinkingRow.appendChild(thinkingDots);
    messageStream.appendChild(thinkingArticle);
    inserted.push(thinkingArticle);

    this.optimisticMessageElements = inserted;
    this.scrollConversationToBottom(true);
  }

  private removeOptimisticMessages(): void {
    this.optimisticMessageElements.forEach((element) => element.remove());
    this.optimisticMessageElements = [];
  }

  private clearComposer(): void {
    this.textInputTarget.value = '';
    this.selectedFiles = [];
    this.syncFileInput();
    this.renderAttachmentTray();
  }

  private restorePendingDraft(): void {
    if (!this.pendingDraft) return;

    this.textInputTarget.value = this.pendingDraft.content;
    this.selectedFiles = [...this.pendingDraft.files];
    this.syncFileInput();
    this.renderAttachmentTray();
    this.pendingDraft = null;
    this.textInputTarget.focus();
  }

  private ensureMessageStream(): HTMLElement | null {
    if (this.hasMessagesTarget) return this.messagesTarget;

    const emptyState = this.element.querySelector('.chat-empty-state');
    if (!(emptyState instanceof HTMLElement)) return null;

    emptyState.classList.add('chat-empty-state-active');

    const stream = document.createElement('section');
    stream.className = 'chat-message-stream';
    stream.dataset.workspaceChatTarget = 'messages';
    emptyState.insertBefore(stream, this.formTarget);

    return stream;
  }

  private scrollConversationToBottom(force = false): void {
    const pane = this.chatPaneElement();
    if (!pane) return;

    const distanceFromBottom = pane.scrollHeight - pane.clientHeight - pane.scrollTop;
    if (!force && distanceFromBottom > 64) return;

    pane.scrollTop = pane.scrollHeight;
  }

  private chatPaneElement(): HTMLElement | null {
    const pane = this.element.querySelector('.chat-pane');
    return pane instanceof HTMLElement ? pane : null;
  }

  private initializeSidebar(): void {
    if (!this.hasSidebarTarget) return;

    const storedPreference = sessionStorage.getItem(this.sidebarPreferenceKey());
    const open = storedPreference === null ? this.sidebarDefaultOpenValue : storedPreference === 'open';
    this.setSidebarOpen(open, false);
  }

  private sidebarOpen(): boolean {
    return this.element.classList.contains('chat-sidebar-open');
  }

  private setSidebarOpen(open: boolean, persist = true): void {
    this.element.classList.toggle('chat-sidebar-open', open);
    this.element.classList.toggle('chat-sidebar-closed', !open);
    this.syncLayoutSidebarState(open);

    if (this.hasSidebarOpenButtonTarget) {
      this.sidebarOpenButtonTarget.setAttribute('aria-label', this.translate('sidebarOpenAria'));
      this.sidebarOpenButtonTarget.setAttribute('aria-expanded', String(open));
    }

    if (this.hasSidebarCloseButtonTarget) {
      this.sidebarCloseButtonTarget.setAttribute('aria-label', this.translate('sidebarCloseAria'));
      this.sidebarCloseButtonTarget.setAttribute('aria-expanded', String(open));
    }

    if (persist) this.persistSidebarPreference(open);
  }

  private syncLayoutSidebarState(open: boolean): void {
    const layout = this.element.closest('.app-content-layout');
    if (!(layout instanceof HTMLElement)) return;

    layout.classList.toggle('chat-history-open', open);
    layout.classList.toggle('chat-history-closed', !open);
  }

  private persistSidebarPreference(open: boolean): void {
    sessionStorage.setItem(this.sidebarPreferenceKey(), open ? 'open' : 'closed');
  }

  private sidebarPreferenceKey(): string {
    return `workspace-chat-sidebar:${this.workspaceIdValue}`;
  }

  private composerFocusRequestKey(): string {
    return `workspace-chat-focus:${this.workspaceIdValue}`;
  }

  private rememberComposerFocus(threadId: number): void {
    sessionStorage.setItem(this.composerFocusRequestKey(), String(threadId));
  }

  private clearComposerFocusRequest(): void {
    sessionStorage.removeItem(this.composerFocusRequestKey());
  }

  private restoreComposerFocus(): void {
    const requestedThreadId = Number(sessionStorage.getItem(this.composerFocusRequestKey()));
    if (Number.isNaN(requestedThreadId) || requestedThreadId <= 0) return;
    if (this.currentThreadId() !== requestedThreadId) return;

    this.focusComposerInputAfterSubmit();
  }

  private focusComposerInputAfterSubmit(attempt = 0): void {
    requestAnimationFrame(() => {
      if (this.textInputTarget.readOnly && attempt < 4) {
        this.focusComposerInputAfterSubmit(attempt + 1);
        return;
      }

      this.textInputTarget.focus({ preventScroll: true });

      if (typeof this.textInputTarget.setSelectionRange === 'function') {
        const cursorPosition = this.textInputTarget.value.length;
        this.textInputTarget.setSelectionRange(cursorPosition, cursorPosition);
      }

      this.clearComposerFocusRequest();
    });
  }

  private visitWorkspace(threadId: number): void {
    const url = new URL(window.location.href);
    if (threadId > 0) {
      url.searchParams.set('thread_id', String(threadId));
    }
    url.searchParams.delete('new_chat');

    const query = url.searchParams.toString();
    const path = query ? `${url.pathname}?${query}` : url.pathname;
    window.Turbo.visit(path, { action: 'replace' });
  }

  private currentThreadId(): number {
    if (this.threadIdValue > 0) return this.threadIdValue;

    if (this.hasThreadInputTarget) {
      const threadId = Number(this.threadInputTarget.value);
      if (!Number.isNaN(threadId) && threadId > 0) return threadId;
    }

    return 0;
  }

  private shouldRenderInlineResponse(data: JsonPayload, threadId: number, requestThreadId: number): boolean {
    const status = this.stringValue(data.status);
    if (!['executed', 'forbidden', 'validation_error', 'execution_error', 'canceled'].includes(status)) {
      return false;
    }

    if (threadId <= 0 || requestThreadId <= 0 || threadId !== requestThreadId) return false;

    return this.payloadMessages(data).length > 0;
  }

  private applyInlineResponse(data: JsonPayload, threadId: number): void {
    if (this.hasThreadInputTarget) this.threadInputTarget.value = String(threadId);

    this.removeOptimisticMessages();
    this.appendServerMessages(this.payloadMessages(data));
    this.updateThreadUrl(threadId);
    this.scrollConversationToBottom(true);
    this.restoreComposerFocus();
  }

  private applyQueryCardResponse(data: JsonPayload): void {
    const updatedMessage = this.updatedMessagePayload(data);
    if (updatedMessage) this.replaceRenderedMessage(updatedMessage);

    this.appendServerMessages(this.payloadMessages(data));
    this.scrollConversationToBottom(true);
  }

  private payloadMessages(data: JsonPayload): ChatMessagePayload[] {
    const rawMessages = data.messages;
    if (!Array.isArray(rawMessages)) return [];

    return rawMessages.filter((message): message is ChatMessagePayload => {
      return Boolean(message && typeof message === 'object' && 'id' in message && 'role' in message);
    });
  }

  private updatedMessagePayload(data: JsonPayload): ChatMessagePayload | null {
    const message = data.updated_message;
    if (!message || typeof message !== 'object') return null;
    if (!('id' in message) || !('role' in message)) return null;

    return message as ChatMessagePayload;
  }

  private appendServerMessages(messages: ChatMessagePayload[]): void {
    const messageStream = this.ensureMessageStream();
    if (!messageStream) return;

    messages.forEach((message) => {
      if (this.messageAlreadyRendered(messageStream, message.id)) return;

      const article = this.buildMessageArticle(message);
      if (!article) return;

      messageStream.appendChild(article);
    });
  }

  private replaceRenderedMessage(message: ChatMessagePayload): void {
    const messageStream = this.ensureMessageStream();
    if (!messageStream) return;

    const existing = messageStream.querySelector(`[data-message-id="${message.id}"]`);
    if (!(existing instanceof HTMLElement)) return;

    const replacement = this.buildMessageArticle(message);
    if (!replacement) return;

    existing.replaceWith(replacement);
  }

  private messageAlreadyRendered(messageStream: HTMLElement, messageId: number): boolean {
    return messageStream.querySelector(`[data-message-id="${messageId}"]`) !== null;
  }

  private buildMessageArticle(message: ChatMessagePayload): HTMLElement | null {
    const article = document.createElement('article');
    article.id = `chat-message-${message.id}`;
    article.className = `chat-message chat-message-${message.role}`;
    article.dataset.messageId = String(message.id);

    if (message.role === 'user') {
      article.appendChild(this.buildUserMessage(message));
      return article;
    }

    if (message.role === 'assistant') {
      article.appendChild(this.buildAssistantMessage(message));
      return article;
    }

    if (message.role === 'system') {
      const row = document.createElement('p');
      row.className = 'chat-system-row chat-system-row-thinking';
      row.textContent = message.content;
      article.appendChild(row);
      return article;
    }

    return null;
  }

  private buildUserMessage(message: ChatMessagePayload): HTMLElement {
    const bubble = document.createElement('div');
    bubble.className = 'chat-user-bubble';

    if (message.content) {
      const body = document.createElement('p');
      body.className = 'chat-message-body';
      body.textContent = message.content;
      bubble.appendChild(body);
    }

    const images = Array.isArray(message.images) ? message.images : [];
    if (images.length > 0) {
      const grid = document.createElement('div');
      grid.className = 'chat-image-grid';

      images.forEach((image) => {
        const imageTag = document.createElement('img');
        imageTag.className = 'chat-image-thumb';
        imageTag.alt = image.filename;
        imageTag.src = image.url;
        grid.appendChild(imageTag);
      });

      bubble.appendChild(grid);
    }

    return bubble;
  }

  private buildAssistantMessage(message: ChatMessagePayload): HTMLElement {
    const block = document.createElement('div');
    block.className = 'chat-assistant-block';

    const body = document.createElement('div');
    body.className = 'chat-message-body';
    const renderedContent = typeof message.content_html === 'string' ? message.content_html.trim() : '';
    if (renderedContent.length > 0) {
      body.innerHTML = renderedContent;
    } else {
      this.appendAssistantContent(body, message.content || '');
    }
    block.appendChild(body);

    return block;
  }

  private appendAssistantContent(container: HTMLElement, content: string): void {
    const normalized = content.replace(/\r\n/g, '\n').trim();
    if (!normalized) return;

    const paragraphs = normalized.split(/\n{2,}/);
    paragraphs.forEach((paragraph) => {
      const trimmed = paragraph.trim();
      if (!trimmed) return;

      if (this.bulletParagraph(trimmed)) {
        container.appendChild(this.buildBulletList(trimmed));
        return;
      }

      const node = document.createElement('p');
      this.appendTextWithLineBreaks(node, trimmed);
      container.appendChild(node);
    });
  }

  private bulletParagraph(paragraph: string): boolean {
    const lines = paragraph.split('\n').map((line) => line.trim()).filter(Boolean);
    if (lines.length === 0) return false;

    return lines.every((line) => /^[-*•]\s+/.test(line));
  }

  private buildBulletList(paragraph: string): HTMLElement {
    const list = document.createElement('ul');
    paragraph
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .forEach((line) => {
        const item = document.createElement('li');
        item.textContent = line.replace(/^[-*•]\s+/, '');
        list.appendChild(item);
      });

    return list;
  }

  private appendTextWithLineBreaks(node: HTMLElement, text: string): void {
    text.split('\n').forEach((line, index) => {
      if (index > 0) node.appendChild(document.createElement('br'));
      node.append(line);
    });
  }

  private updateThreadUrl(threadId: number): void {
    if (threadId <= 0) return;

    const url = new URL(window.location.href);
    url.searchParams.set('thread_id', String(threadId));
    url.searchParams.delete('new_chat');
    window.history.replaceState({}, '', `${url.pathname}?${url.searchParams.toString()}`);
  }

  private updateThreadSearchVisibility(): void {
    if (!this.hasThreadSearchInputTarget) return;

    const query = this.threadSearchInputTarget.value.trim().toLowerCase();
    const filterEnabled = query.length >= 2;
    let visibleRows = 0;

    this.threadRowTargets.forEach((row) => {
      const title = row.dataset.threadTitle || '';
      const visible = !filterEnabled || title.includes(query);
      row.classList.toggle('is-hidden', !visible);
      if (visible) visibleRows += 1;
    });

    if (this.hasThreadSearchClearTarget) {
      this.threadSearchClearTarget.classList.toggle('visible', query.length > 0);
    }

    if (this.hasThreadListEmptyTarget) {
      const showEmptyState = visibleRows === 0;
      this.threadListEmptyTarget.classList.toggle('visible', showEmptyState);
    }
  }

  private refreshThreadEmptyState(): void {
    if (!this.hasThreadListEmptyTarget) return;

    const hasVisibleRows = this.threadRowTargets.some((row) => !row.classList.contains('is-hidden'));
    this.threadListEmptyTarget.classList.toggle('visible', !hasVisibleRows);
  }

  private rowFromEvent(event: Event): HTMLElement | null {
    const target = event.currentTarget;
    if (!(target instanceof Element)) return null;

    return target.closest('.chat-history-thread-row');
  }

  private closeThreadMenu(): void {
    if (!this.openMenuRow) return;

    this.openMenuRow.classList.remove('menu-open');
    this.openMenuRow = null;
  }

  private activateRename(row: HTMLElement): void {
    if (this.renamingRow && this.renamingRow !== row) this.cancelRename();

    this.renamingRow = row;
    row.classList.add('is-editing');

    const input = row.querySelector('.chat-history-thread-title-input');
    if (!(input instanceof HTMLInputElement)) return;

    input.value = this.rowTitle(row);
    input.focus();
    input.select();
  }

  private cancelRename(): void {
    if (!this.renamingRow) return;

    const input = this.renamingRow.querySelector('.chat-history-thread-title-input');
    if (input instanceof HTMLInputElement) input.value = this.rowTitle(this.renamingRow);

    this.renamingRow.classList.remove('is-editing');
    this.renamingRow = null;
  }

  private commitRename(input: HTMLInputElement): void {
    const row = input.closest('.chat-history-thread-row');
    if (!(row instanceof HTMLElement)) return;
    if (!row.classList.contains('is-editing')) return;

    const nextTitle = input.value.trim();
    if (!nextTitle) {
      this.setAttachmentError(this.translate('threadTitleRequiredError'));
      input.focus();
      return;
    }

    const currentTitle = this.rowTitle(row);
    if (nextTitle === currentTitle) {
      this.finishRename(row, currentTitle);
      return;
    }

    const threadId = Number(row.dataset.threadId);
    if (Number.isNaN(threadId)) return;

    const formData = new FormData();
    formData.set('title', nextTitle);

    this.fetchJson(`/app/workspaces/${this.workspaceIdValue}/chat/threads/${threadId}`, formData, 'PATCH')
      .then((data) => {
        const thread = data.thread as JsonPayload | undefined;
        const title = this.stringValue(thread?.title) || nextTitle;
        this.finishRename(row, title);
        this.setAttachmentError('');
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('renameThreadFailedError'));
        input.focus();
      });
  }

  private finishRename(row: HTMLElement, title: string): void {
    const normalizedTitle = title.trim();
    row.dataset.threadTitle = normalizedTitle.toLowerCase();

    const label = row.querySelector('.chat-history-thread-title');
    if (label instanceof HTMLElement) label.textContent = normalizedTitle;

    const input = row.querySelector('.chat-history-thread-title-input');
    if (input instanceof HTMLInputElement) input.value = normalizedTitle;

    row.classList.remove('is-editing');
    if (this.renamingRow === row) this.renamingRow = null;

    this.updateThreadSearchVisibility();
  }

  private rowTitle(row: HTMLElement): string {
    const label = row.querySelector('.chat-history-thread-title');
    if (label instanceof HTMLElement) return label.textContent?.trim() || '';

    return '';
  }

  private stringValue(value: unknown): string {
    return typeof value === 'string' ? value : '';
  }

  private numberValue(value: unknown): number {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
}
