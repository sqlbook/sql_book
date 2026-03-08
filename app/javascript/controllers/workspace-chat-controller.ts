import { Controller } from '@hotwired/stimulus';

const MAX_IMAGE_COUNT = 6;
const MAX_IMAGE_SIZE_BYTES = 25 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

type JsonPayload = Record<string, unknown>;

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

        this.visitWorkspace(threadId);
      })
      .catch((error) => {
        this.removeOptimisticMessages();
        this.restorePendingDraft();
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
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

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

    const timestamp = this.formatCurrentTime();
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

      const userMeta = document.createElement('p');
      userMeta.className = 'chat-message-meta';
      userMeta.textContent = timestamp;

      userBubble.appendChild(userBody);
      userArticle.appendChild(userBubble);
      userArticle.appendChild(userMeta);
      messageStream.appendChild(userArticle);
      inserted.push(userArticle);
    }

    const thinkingArticle = document.createElement('article');
    thinkingArticle.className = 'chat-message chat-message-system chat-message-pending';
    thinkingArticle.dataset.optimistic = 'true';

    const thinkingRow = document.createElement('p');
    thinkingRow.className = 'chat-system-row';
    thinkingRow.textContent = this.translate('thinkingStatus') || 'Thinking';

    const thinkingMeta = document.createElement('p');
    thinkingMeta.className = 'chat-message-meta';
    thinkingMeta.textContent = timestamp;

    thinkingArticle.appendChild(thinkingRow);
    thinkingArticle.appendChild(thinkingMeta);
    messageStream.appendChild(thinkingArticle);
    inserted.push(thinkingArticle);

    this.optimisticMessageElements = inserted;
    thinkingArticle.scrollIntoView({ block: 'end', behavior: 'smooth' });
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

  private formatCurrentTime(): string {
    const now = new Date();
    const hour = String(now.getHours()).padStart(2, '0');
    const minute = String(now.getMinutes()).padStart(2, '0');

    return `${hour}:${minute}`;
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

  private persistSidebarPreference(open: boolean): void {
    sessionStorage.setItem(this.sidebarPreferenceKey(), open ? 'open' : 'closed');
  }

  private sidebarPreferenceKey(): string {
    return `workspace-chat-sidebar:${this.workspaceIdValue}`;
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
