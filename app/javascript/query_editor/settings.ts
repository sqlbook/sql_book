import type { QueryPayload, TranslationPayload } from './types';
import {
  filterGroupNames,
  hasGroupName,
  normalizeGroupName,
  resolveExistingGroupName
} from './groups';
import { escapeAttribute, escapeHtml, interpolate } from './utils';

type RenderSettingsPaneParams = {
  query: QueryPayload;
  readOnly: boolean;
  i18n: TranslationPayload;
  chatSource?: { path: string } | null;
  availableGroups: string[];
  groupInputValue: string;
  groupMenuOpen: boolean;
};

export function renderQuerySettingsPane({
  query,
  readOnly,
  i18n,
  chatSource,
  availableGroups,
  groupInputValue,
  groupMenuOpen
}: RenderSettingsPaneParams): string {
  if (readOnly) {
    return `<p>${escapeHtml(i18n.settings.read_only)}</p>`;
  }

  const normalizedInput = normalizeGroupName(groupInputValue);
  const matchingGroups = filterGroupNames(availableGroups, query.group_names, normalizedInput);
  const exactExistingGroup = resolveExistingGroupName(availableGroups, normalizedInput);
  const alreadySelected = hasGroupName(query.group_names, normalizedInput);
  const showCreateOption = Boolean(normalizedInput && !alreadySelected && !exactExistingGroup);
  const showDropdown = groupMenuOpen && (matchingGroups.length > 0 || showCreateOption);

  return `
    <div class="new-query-form query-settings-form">
      <div class="message">
        <i class="ri-information-line ri-lg red-500"></i>
        <div class="body">
          <p>${escapeHtml(i18n.settings.notice)}</p>
        </div>
      </div>

      <div class="mt24">
        <label class="label block">${escapeHtml(i18n.settings.name_label)}</label>
        <input
          type="text"
          class="input block fluid"
          placeholder="${escapeAttribute(i18n.settings.name_placeholder)}"
          value="${escapeAttribute(query.name || '')}"
          data-action="input->query-editor#changeName">
      </div>

      <div class="mt24 query-group-picker">
        <label class="label block">${escapeHtml(i18n.settings.groups_label)}</label>
        <p class="gray-300 query-group-picker__description">${escapeHtml(i18n.settings.groups_description)}</p>
        <input
          type="text"
          class="input block fluid"
          placeholder="${escapeAttribute(i18n.settings.groups_placeholder)}"
          value="${escapeAttribute(groupInputValue)}"
          data-query-editor-group-input
          data-action="focus->query-editor#focusGroupInput input->query-editor#changeGroupInput keydown->query-editor#handleGroupInputKeydown">
        ${showDropdown ? `
          <div class="query-group-picker__dropdown">
            <p class="query-group-picker__hint gray-400">${escapeHtml(i18n.settings.groups_dropdown_hint)}</p>
            ${matchingGroups.map((groupName) => {
              return `
                <button
                  type="button"
                  class="query-group-picker__option"
                  data-group-name="${escapeAttribute(groupName)}"
                  data-action="mousedown->query-editor#selectGroupOption">
                  <span>${highlightGroupMatch(groupName, normalizedInput)}</span>
                </button>
              `;
            }).join('')}
            ${showCreateOption ? `
              <button
                type="button"
                class="query-group-picker__option query-group-picker__option--create"
                data-create-group="true"
                data-action="mousedown->query-editor#selectGroupOption">
                ${escapeHtml(interpolate(i18n.settings.groups_create_hint, { name: normalizedInput }))}
              </button>
            ` : ''}
          </div>
        ` : ''}
        ${query.group_names.length > 0 ? `
          <div class="query-group-picker__chips">
            ${query.group_names.map((groupName) => {
              return `
                <button
                  type="button"
                  class="query-group-picker__chip"
                  data-group-name="${escapeAttribute(groupName)}"
                  data-action="click->query-editor#removeGroup">
                  <span class="query-group-picker__chip-label">${escapeHtml(groupName)}</span>
                  <i class="ri-close-line" aria-hidden="true"></i>
                </button>
              `;
            }).join('')}
          </div>
        ` : ''}
      </div>

      ${chatSource?.path ? `
        <p class="small gray-300 mt24">
          <strong>${escapeHtml(i18n.settings.chat_source_label)}:</strong>
          <a class="link secondary" href="${escapeAttribute(chatSource.path)}" target="_blank" rel="noopener noreferrer">
            ${escapeHtml(i18n.settings.chat_source_link)}
          </a>
        </p>
      ` : ''}
    </div>
  `;
}

function highlightGroupMatch(groupName: string, query: string): string {
  if (!query) return escapeHtml(groupName);

  const loweredName = groupName.toLocaleLowerCase();
  const loweredQuery = query.toLocaleLowerCase();
  const matchIndex = loweredName.indexOf(loweredQuery);

  if (matchIndex < 0) return escapeHtml(groupName);

  const before = groupName.slice(0, matchIndex);
  const match = groupName.slice(matchIndex, matchIndex + query.length);
  const after = groupName.slice(matchIndex + query.length);

  return `${escapeHtml(before)}<span class="red-500">${escapeHtml(match)}</span>${escapeHtml(after)}`;
}
