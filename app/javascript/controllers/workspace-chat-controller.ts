import { Controller } from '@hotwired/stimulus';

const MAX_IMAGE_COUNT = 6;
const MAX_IMAGE_SIZE_BYTES = 25 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'textInput', 'fileInput', 'attachmentTray', 'attachmentError', 'messages'];
  static values = {
    workspaceId: Number,
    threadId: Number,
    i18n: Object
  };

  declare readonly formTarget: HTMLFormElement;
  declare readonly textInputTarget: HTMLInputElement;
  declare readonly fileInputTarget: HTMLInputElement;
  declare readonly attachmentTrayTarget: HTMLDivElement;
  declare readonly attachmentErrorTarget: HTMLParagraphElement;
  declare readonly messagesTarget: HTMLDivElement;
  declare readonly hasMessagesTarget: boolean;
  declare readonly workspaceIdValue: number;
  declare readonly threadIdValue: number;
  declare readonly i18nValue: Record<string, string>;

  private selectedFiles: File[] = [];
  private previewUrls: string[] = [];
  private optimisticMessageElements: HTMLElement[] = [];
  private pendingDraft: { content: string; files: File[] } | null = null;
  private submitting = false;

  public connect(): void {
    this.renderAttachmentTray();
  }

  public disconnect(): void {
    this.revokePreviewUrls();
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
        const redirectPath = data.redirect_path as string | undefined;
        if (redirectPath) {
          window.Turbo.visit(redirectPath);
          return;
        }

        window.Turbo.visit(window.location.pathname, { action: 'replace' });
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
    if (!actionId || !confirmationToken) return;

    const formData = new FormData();
    formData.set('thread_id', String(this.threadIdValue));
    formData.set('confirmation_token', confirmationToken);

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/actions/${actionId}/confirm`;
    this.fetchJson(path, formData)
      .then((data) => {
        const redirectPath = data.redirect_path as string | undefined;
        if (redirectPath) {
          window.Turbo.visit(redirectPath);
          return;
        }

        window.Turbo.visit(window.location.pathname, { action: 'replace' });
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('confirmActionError'));
      });
  }

  public cancelAction(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const actionId = target.dataset.actionId;
    if (!actionId) return;

    const formData = new FormData();
    formData.set('thread_id', String(this.threadIdValue));

    const path = `/app/workspaces/${this.workspaceIdValue}/chat/actions/${actionId}/cancel`;
    this.fetchJson(path, formData)
      .then(() => {
        window.Turbo.visit(window.location.pathname, { action: 'replace' });
      })
      .catch((error) => {
        this.setAttachmentError(error.message || this.translate('cancelActionError'));
      });
  }

  private fetchJson(path: string, body: FormData): Promise<Record<string, unknown>> {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

    return fetch(path, {
      method: 'POST',
      body,
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': csrfToken
      }
    }).then(async (response) => {
      const data = await response.json();
      if (!response.ok) {
        throw new Error((data.message as string) || this.translate('requestFailedError'));
      }

      return data as Record<string, unknown>;
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
}
