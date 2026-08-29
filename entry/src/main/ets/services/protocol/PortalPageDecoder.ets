import {
  PortalAction, PortalBadge, PortalCard, PortalDocument, PortalField, PortalLink, PortalMaterial
} from '../../models/PortalModels';
import { collapseWhitespace, hasClass } from './HtmlProbeUtils';
import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';

export class PortalPageDecoder {
  decode(html: string, path: string = ''): PortalDocument {
    const lines: string[] = [];
    const actions: PortalAction[] = [];
    const links: PortalLink[] = [];
    const selectableFields: PortalField[] = [];
    const cards: PortalCard[] = [];
    const badges: PortalBadge[] = [];
    const materials: PortalMaterial[] = [];
    let subStats = '';
    let subStatsDepth = 0;
    let subStatsText = '';
    let cardMaterialName = '';
    let cardMaterialTitleId = '';
    let cardMaterialRarityKey = '';
    let cardMaterialMaxQuantity = 0;
    let mainDepth = 0;
    let skipDepth = 0;
    let currentAction: PortalAction | undefined = undefined;
    let buttonDepth = 0;
    let buttonText = '';
    let formMethod = 'get';
    let textAreaDepth = 0;
    let textAreaField: PortalField | undefined = undefined;
    let selectField: PortalField | undefined = undefined;
    let optionText = '';
    let optionValue = '';
    let optionTitle = '';
    let optionRarity = '';
    let optionSelected = false;
    let linkDepth = 0;
    let linkText = '';
    let linkPath = '';
    let title = '';
    let currentCard: PortalCard | undefined = undefined;
    let cardDepth = 0;
    let badgeDepth = 0;
    let badgeText = '';
    let protectedEmailDepth = 0;
    let protectedEmail = '';
    let notificationQuoteDepth = 0;

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        const entersMain = mainDepth === 0 && hasClass(token.attributes, 'forum-main');
        if (entersMain) {
          mainDepth = token.selfClosing ? 0 : 1;
          return;
        }
        if (mainDepth <= 0) {
          return;
        }
        const structural = !token.selfClosing && !this.isVoidTag(token.name);
        let startedCard = false;
        if (currentCard === undefined) {
          const cardKind = this.cardKind(token, path);
          if (cardKind.length > 0) {
            const directMessagePath = cardKind === 'conversation' ? (token.attributes.get('href') ?? '') : '';
            currentCard = { kind: cardKind,
              key: directMessagePath.startsWith('/direct_messages/') ? directMessagePath :
                `${cardKind}-${cards.length}`,
              lines: [], actionIndexes: [], links: [] };
            cardDepth = structural ? 1 : 0;
            startedCard = true;
          }
        }
        if (currentCard !== undefined && !startedCard && structural) {
          cardDepth++;
        }
        if (currentCard?.kind === 'notification-record') {
          if (notificationQuoteDepth === 0 && token.name === 'blockquote') {
            notificationQuoteDepth = structural ? 1 : 0;
          } else if (notificationQuoteDepth > 0 && structural) {
            notificationQuoteDepth++;
          }
        }
        if (badgeDepth === 0 && this.isTitleBadge(token)) {
          badgeDepth = structural ? 1 : 0;
          badgeText = '';
        } else if (badgeDepth > 0 && structural) {
          badgeDepth++;
        }
        if (subStatsDepth === 0 && hasClass(token.attributes, 'gacha-sub-stats')) {
          subStatsDepth = structural ? 1 : 0;
          subStatsText = '';
        } else if (subStatsDepth > 0 && structural) {
          subStatsDepth++;
        }
        if (skipDepth === 0 && (hasClass(token.attributes, 'breadcrumb') ||
          hasClass(token.attributes, 'gacha-internal-nav'))) {
          skipDepth = token.selfClosing ? 0 : 1;
        } else if (skipDepth > 0 && !token.selfClosing) {
          skipDepth++;
        }
        if (!token.selfClosing) {
          mainDepth++;
        }
        if (skipDepth > 0) {
          return;
        }
        if (currentCard !== undefined && token.name === 'img' &&
          (currentCard.imageUrl ?? '').length === 0) {
          currentCard.imageUrl = this.normalizeAssetUrl(token.attributes.get('src') ?? '');
        }
        if (protectedEmailDepth === 0 && token.attributes.has('data-cfemail')) {
          protectedEmail = this.decodeProtectedEmail(token.attributes.get('data-cfemail') ?? '');
          protectedEmailDepth = structural ? 1 : 0;
        } else if (protectedEmailDepth > 0 && structural) {
          protectedEmailDepth++;
        }
        if (token.name === 'form') {
          formMethod = (token.attributes.get('method') ?? 'get').toLowerCase();
          currentAction = {
            actionUrl: token.attributes.get('action') ?? path,
            label: '',
            context: lines.slice(Math.max(0, lines.length - 3)).join(' · '),
            disabled: false,
            fields: []
          };
        } else if (currentAction !== undefined && token.name === 'input' && !token.attributes.has('form')) {
          const name = token.attributes.get('name') ?? '';
          if (name.length > 0 && name !== '_csrf') {
            const field: PortalField = {
              name: name,
              value: token.attributes.get('value') ?? '',
              type: (token.attributes.get('type') ?? 'text').toLowerCase(),
              placeholder: token.attributes.get('placeholder') ?? '',
              options: []
            };
            currentAction.fields.push(field);
          }
        } else if (currentAction === undefined && token.name === 'input' &&
          (token.attributes.get('type') ?? '').toLowerCase() === 'checkbox') {
          const name = token.attributes.get('name') ?? '';
          const candidateValue = token.attributes.get('value') ?? '';
          if (name.length > 0 && candidateValue.length > 0) {
            const rarity = (token.attributes.get('data-gacha-forge-rarity') ?? 'SSR').toLowerCase();
            const quantity = token.attributes.get('data-gacha-forge-quantity') ??
              token.attributes.get('data-gacha-recycle-quantity') ?? '1';
            const cardLabel = currentCard === undefined ? '' : currentCard.lines.slice(0, 3).join(' · ');
            selectableFields.push({
              name: name,
              value: '',
              type: 'checkbox',
              placeholder: cardLabel.length > 0 ? `${rarity.toUpperCase()} · ${cardLabel} ×${quantity}` :
                `${rarity.toUpperCase()} 称号 #${candidateValue} ×${quantity}`,
              options: [{ label: quantity, value: candidateValue }]
            });
            if (currentCard !== undefined &&
              (name === 'material_title_ids[]' || name === 'recycle_title_ids[]')) {
              cardMaterialName = name;
              cardMaterialTitleId = candidateValue;
              cardMaterialRarityKey = rarity;
              const parsedQuantity = Number(quantity);
              cardMaterialMaxQuantity = Number.isFinite(parsedQuantity) && parsedQuantity > 0 ?
                Math.floor(parsedQuantity) : 1;
            }
          }
        } else if (currentAction !== undefined && token.name === 'textarea') {
          const name = token.attributes.get('name') ?? '';
          if (name.length > 0) {
            textAreaField = {
              name: name,
              value: '',
              type: 'textarea',
              placeholder: token.attributes.get('placeholder') ?? '',
              options: []
            };
            currentAction.fields.push(textAreaField);
            textAreaDepth = 1;
          }
        } else if (currentAction !== undefined && token.name === 'select') {
          const name = token.attributes.get('name') ?? '';
          if (name.length > 0) {
            selectField = { name: name, value: token.attributes.get('value') ?? '',
              type: 'select', placeholder: '', options: [] };
            currentAction.fields.push(selectField);
          }
        } else if (selectField !== undefined && token.name === 'option') {
          optionText = '';
          optionValue = token.attributes.get('value') ?? '';
          optionTitle = token.attributes.get('data-title') ?? '';
          optionRarity = token.attributes.get('data-rarity') ?? '';
          optionSelected = token.attributes.has('selected');
        } else if (currentAction !== undefined && token.name === 'button') {
          buttonDepth = 1;
          buttonText = '';
          currentAction.disabled = token.attributes.has('disabled');
        } else if (currentAction === undefined && token.name === 'button' &&
          (token.attributes.get('onclick') ?? '').indexOf('gachaGiftModalOpen') >= 0) {
          const titleId = this.objectNumber(token.attributes.get('onclick') ?? '', 'id');
          const giftAction: PortalAction = {
            actionUrl: '/gacha_gift', label: '赠送', context: currentCard?.lines.slice(0, 2).join(' · ') ?? '',
            disabled: titleId.length === 0,
            fields: [
              { name: 'title_id', value: titleId, type: 'hidden', placeholder: '', options: [] },
              { name: 'username', value: '', type: 'text', placeholder: '输入接收者用户名', options: [] }
            ]
          };
          actions.push(giftAction);
          if (currentCard !== undefined) {
            currentCard.actionIndexes.push(actions.length - 1);
            this.fillEmptyField(actions, currentCard.actionIndexes, '/gacha_equip', 'title_id', titleId);
          }
        } else if (buttonDepth > 0 && !token.selfClosing) {
          buttonDepth++;
        }
        if (token.name === 'a' && linkDepth === 0) {
          const sourceHref = token.attributes.get('href') ?? '';
          const href = sourceHref.startsWith('https://linux.sb/') ? sourceHref.substring('https://linux.sb'.length) :
            sourceHref;
          if (href.startsWith('/') && !href.startsWith('//')) {
            linkDepth = 1;
            linkText = '';
            linkPath = href;
          }
        } else if (linkDepth > 0 && !token.selfClosing) {
          linkDepth++;
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (mainDepth <= 0 || skipDepth > 0) {
          return;
        }
        let value = collapseWhitespace(token.text);
        if (protectedEmailDepth > 0 && protectedEmail.length > 0) {
          value = protectedEmail;
        }
        if (value.length === 0) {
          return;
        }
        if (currentCard !== undefined && notificationQuoteDepth === 0 &&
          (currentCard.lines.length === 0 || currentCard.lines[currentCard.lines.length - 1] !== value)) {
          currentCard.lines.push(value);
        }
        if (badgeDepth > 0) {
          badgeText = collapseWhitespace(`${badgeText} ${value}`);
        }
        if (subStatsDepth > 0) {
          subStatsText = collapseWhitespace(`${subStatsText} ${value}`);
        }
        if (protectedEmailDepth > 0) {
          protectedEmailDepth--;
          if (protectedEmailDepth === 0) {
            protectedEmail = '';
          }
        }
        if (buttonDepth > 0) {
          buttonText = collapseWhitespace(`${buttonText} ${value}`);
        }
        if (textAreaDepth > 0 && textAreaField !== undefined) {
          textAreaField.value = collapseWhitespace(`${textAreaField.value} ${value}`);
        }
        if (linkDepth > 0) {
          linkText = collapseWhitespace(`${linkText} ${value}`);
        }
        if (selectField !== undefined && optionValue.length > 0) {
          optionText = collapseWhitespace(`${optionText} ${value}`);
        }
        if (lines.length === 0 || lines[lines.length - 1] !== value) {
          lines.push(value);
          if (title.length === 0 && value !== '首页') {
            title = value;
          }
        }
        return;
      }

      if (token.type === HtmlTokenType.END_TAG && mainDepth > 0) {
        if (skipDepth > 0) {
          skipDepth--;
          mainDepth--;
          return;
        }
        if (buttonDepth > 0) {
          buttonDepth--;
          if (buttonDepth === 0 && currentAction !== undefined) {
            currentAction.label = buttonText;
          }
        }
        if (textAreaDepth > 0) {
          textAreaDepth--;
          if (textAreaDepth === 0) {
            textAreaField = undefined;
          }
        }
        if (token.name === 'option' && selectField !== undefined && optionText.length > 0) {
          selectField.options.push({ label: optionText, value: optionValue,
            title: optionTitle.length > 0 ? optionTitle : undefined,
            rarity: optionRarity.length > 0 ? optionRarity : undefined });
          if (optionSelected || selectField.value.length === 0) {
            selectField.value = optionValue;
          }
          optionText = '';
          optionValue = '';
          optionTitle = '';
          optionRarity = '';
          optionSelected = false;
        } else if (token.name === 'select') {
          selectField = undefined;
        }
        if (linkDepth > 0) {
          linkDepth--;
          if (linkDepth === 0 && linkPath.length > 0 && linkText.length > 0) {
            const capturedLink: PortalLink = { label: linkText, path: linkPath };
            links.push(capturedLink);
            if (currentCard !== undefined) {
              currentCard.links.push(capturedLink);
            }
            linkText = '';
            linkPath = '';
          }
        }
        if (token.name === 'form' && currentAction !== undefined) {
          if (formMethod === 'post' && currentAction.actionUrl.length > 0 && currentAction.label.length > 0) {
            actions.push(currentAction);
            if (currentCard !== undefined) {
              currentCard.actionIndexes.push(actions.length - 1);
            }
          }
          currentAction = undefined;
        }
        if (badgeDepth > 0) {
          badgeDepth--;
          if (badgeDepth === 0) {
            this.appendBadge(badgeText, badges);
            badgeText = '';
          }
        }
        if (subStatsDepth > 0) {
          subStatsDepth--;
          if (subStatsDepth === 0) {
            subStats = subStatsText;
            subStatsText = '';
          }
        }
        if (notificationQuoteDepth > 0) {
          notificationQuoteDepth--;
        }
        if (currentCard !== undefined && cardDepth > 0) {
          cardDepth--;
          if (cardDepth === 0) {
            cards.push(currentCard);
            if (cardMaterialTitleId.length > 0) {
              materials.push(this.buildMaterial(currentCard, cardMaterialName, cardMaterialTitleId,
                cardMaterialRarityKey, cardMaterialMaxQuantity));
            }
            currentCard = undefined;
            cardMaterialName = '';
            cardMaterialTitleId = '';
            cardMaterialRarityKey = '';
            cardMaterialMaxQuantity = 0;
            notificationQuoteDepth = 0;
          }
        }
        mainDepth--;
      }
    });

    for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
      const action = actions[actionIndex];
      if (action.actionUrl === '/gacha_forge') {
        let rarity = '';
        for (let fieldIndex = 0; fieldIndex < action.fields.length; fieldIndex++) {
          if (action.fields[fieldIndex].name === 'source_rarity') {
            rarity = action.fields[fieldIndex].value.toLowerCase();
          }
        }
        if (rarity.length === 0) {
          rarity = action.label.split('×')[0].trim().toLowerCase();
        }
        const costText = action.label.split('×')[1]?.split('→')[0]?.trim() ?? '1';
        action.fields.push({ name: '_client_forge_cost', value: costText, type: 'hidden',
          placeholder: '', options: [] });
        for (let optionIndex = 0; optionIndex < selectableFields.length; optionIndex++) {
          const option = selectableFields[optionIndex];
          if (option.name === 'material_title_ids[]' && option.placeholder.toLowerCase().startsWith(rarity)) {
            action.fields.push(option);
            action.disabled = false;
          }
        }
      } else if (action.actionUrl === '/gacha_recycle') {
        for (let optionIndex = 0; optionIndex < selectableFields.length; optionIndex++) {
          const option = selectableFields[optionIndex];
          if (option.name === 'recycle_title_ids[]') {
            action.fields.push(option);
            action.disabled = false;
          }
        }
      }
    }
    for (let fieldIndex = 0; fieldIndex < selectableFields.length; fieldIndex++) {
      const field = selectableFields[fieldIndex];
      if (field.name !== 'material_title_ids[]' && field.name !== 'recycle_title_ids[]') {
        continue;
      }
      const titleId = field.options.length > 0 ? field.options[0].value : '';
      if (titleId.length === 0) {
        continue;
      }
      let exists = false;
      for (let materialIndex = 0; materialIndex < materials.length; materialIndex++) {
        if (materials[materialIndex].titleId === titleId && materials[materialIndex].checkboxName === field.name) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        materials.push(this.buildMaterialFromField(field));
      }
    }
    this.attachNotificationReplyLinks(html, cards);
    return { path: path, title: title, lines: lines.slice(0, 350), actions: actions,
      links: links.slice(0, 120), cards: cards.slice(0, 160), badges: badges.slice(0, 160),
      materials: materials.slice(0, 160), subStats: subStats };
  }

  private attachNotificationReplyLinks(html: string, cards: PortalCard[]): void {
    const notificationCards = cards.filter((card: PortalCard) => card.kind === 'notification-record');
    let offset = 0;
    for (let cardIndex = 0; cardIndex < notificationCards.length; cardIndex++) {
      const marker = html.indexOf('notification-item', offset);
      if (marker < 0) {
        break;
      }
      const end = html.indexOf('</li>', marker);
      if (end < 0) {
        break;
      }
      const segment = html.substring(marker, end);
      const valueStart = segment.indexOf('/direct_messages/');
      if (valueStart >= 0) {
        let valueEnd = valueStart;
        while (valueEnd < segment.length && segment[valueEnd] !== '"' && segment[valueEnd] !== '\'' &&
          segment[valueEnd] !== ' ' && segment[valueEnd] !== '>') {
          valueEnd++;
        }
        if (valueEnd > valueStart) {
          notificationCards[cardIndex].links.push({
            label: '回复TA',
            path: segment.substring(valueStart, valueEnd).replace(/&amp;/g, '&')
          });
        }
      } else if (segment.indexOf('<blockquote') >= 0) {
        const userMarker = segment.indexOf('/user/');
        if (userMarker >= 0) {
          let userEnd = userMarker + '/user/'.length;
          while (userEnd < segment.length && segment[userEnd] >= '0' && segment[userEnd] <= '9') {
            userEnd++;
          }
          const userId = segment.substring(userMarker + '/user/'.length, userEnd);
          let replyText = '';
          for (let lineIndex = 3; lineIndex < notificationCards[cardIndex].lines.length; lineIndex++) {
            const line = notificationCards[cardIndex].lines[lineIndex];
            if (line === '回复TA') {
              continue;
            }
            replyText = replyText.length > 0 ? `${replyText} ${line}` : line;
          }
          if (userId.length > 0 && replyText.length > 0) {
            notificationCards[cardIndex].links.push({
              label: '回复TA',
              path: `/direct_messages/${userId}?draft=${encodeURIComponent(`> ${replyText}\n`)}`
            });
          }
        }
      }
      offset = end + 5;
    }
  }

  private buildMaterial(card: PortalCard, checkboxName: string, titleId: string, rarityKey: string,
    maxQuantity: number): PortalMaterial {
    const lineAt = (index: number): string => index < card.lines.length ? card.lines[index] : '';
    return {
      titleId: titleId,
      icon: lineAt(0),
      name: lineAt(1),
      rarity: lineAt(2),
      description: lineAt(3),
      ownedText: lineAt(4),
      maxQuantity: maxQuantity,
      checkboxName: checkboxName,
      rarityKey: rarityKey
    };
  }

  // Fallback for checkboxes whose surrounding markup did not match a known card
  // class: the placeholder carries "RARITY · icon · name · RARITY ×quantity".
  private buildMaterialFromField(field: PortalField): PortalMaterial {
    const titleId = field.options.length > 0 ? field.options[0].value : '';
    const quantityText = field.options.length > 0 ? field.options[0].label : '1';
    const parsedQuantity = Number(quantityText);
    const segments = field.placeholder.split(' · ');
    const rarity = segments.length > 0 ? segments[0].split(' ')[0].toUpperCase() : '';
    const icon = segments.length > 1 ? segments[1] : '';
    let name = segments.length > 2 ? segments[2] : '';
    if (name.length === 0) {
      name = `称号 #${titleId}`;
    }
    return {
      titleId: titleId,
      icon: icon,
      name: name,
      rarity: rarity,
      description: '',
      ownedText: `×${quantityText}`,
      maxQuantity: Number.isFinite(parsedQuantity) && parsedQuantity > 0 ? Math.floor(parsedQuantity) : 1,
      checkboxName: field.name,
      rarityKey: rarity.toLowerCase()
    };
  }

  private cardKind(token: HtmlToken, path: string): string {
    if (hasClass(token.attributes, 'gacha-profile-item')) {
      return 'title-owned';
    }
    if (hasClass(token.attributes, 'gacha-operation-card')) {
      return 'title-material';
    }
    if (hasClass(token.attributes, 'gacha-recipe-card')) {
      return 'title-recipe';
    }
    if (hasClass(token.attributes, 'gacha-market-card') || hasClass(token.attributes, 'gacha-market-row')) {
      return 'title-market';
    }
    if (hasClass(token.attributes, 'direct-message-item') || hasClass(token.attributes, 'conversation-item') ||
      hasClass(token.attributes, 'direct-messages-conversation')) {
      return 'conversation';
    }
    if (hasClass(token.attributes, 'chat-message') || hasClass(token.attributes, 'message-item') ||
      hasClass(token.attributes, 'direct-messages-message')) {
      return hasClass(token.attributes, 'is-mine') ? 'message-mine' : 'message';
    }
    if (hasClass(token.attributes, 'points-reward-item') || hasClass(token.attributes, 'points-log-item') ||
      hasClass(token.attributes, 'points-rewards-detail')) {
      return 'points-record';
    }
    if (hasClass(token.attributes, 'favorite-item') || hasClass(token.attributes, 'topic-list-item')) {
      return 'topic-record';
    }
    if (hasClass(token.attributes, 'notification-item')) {
      return 'notification-record';
    }
    if (hasClass(token.attributes, 'community-wallet-card')) {
      return 'wallet-section';
    }
    if (hasClass(token.attributes, 'wallet-record') || hasClass(token.attributes, 'community-wallet-section')) {
      return 'wallet-record';
    }
    if (token.name === 'li' && hasClass(token.attributes, 'post-item') && path.indexOf('favorites') >= 0) {
      return 'topic-record';
    }
    return '';
  }

  private normalizeAssetUrl(value: string): string {
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return `https:${value}`;
    }
    if (value.startsWith('/')) {
      return `https://linux.sb${value}`;
    }
    return value.length > 0 ? `https://linux.sb/${value}` : '';
  }

  private decodeProtectedEmail(encoded: string): string {
    if (encoded.length < 4 || encoded.length % 2 !== 0) {
      return '';
    }
    const key = Number.parseInt(encoded.substring(0, 2), 16);
    if (!Number.isFinite(key)) {
      return '';
    }
    let output = '';
    for (let index = 2; index < encoded.length; index += 2) {
      const value = Number.parseInt(encoded.substring(index, index + 2), 16);
      if (!Number.isFinite(value)) {
        return '';
      }
      output += String.fromCharCode(value ^ key);
    }
    return output;
  }

  private isTitleBadge(token: HtmlToken): boolean {
    return hasClass(token.attributes, 'gacha-title-badge') || hasClass(token.attributes, 'title-badge') ||
      hasClass(token.attributes, 'gacha-all-item');
  }

  private appendBadge(value: string, badges: PortalBadge[]): void {
    const label = collapseWhitespace(value);
    if (label.length === 0) {
      return;
    }
    const parts = label.split(' ');
    const last = parts.length > 0 ? parts[parts.length - 1].toUpperCase() : '';
    const rarity = last === 'UR' || last === 'SSR' || last === 'SR' || last === 'R' || last === 'N' ? last : '';
    for (let index = 0; index < badges.length; index++) {
      if (badges[index].label === label) {
        return;
      }
    }
    badges.push({ label: label, rarity: rarity });
  }

  private isVoidTag(name: string): boolean {
    return name === 'br' || name === 'img' || name === 'hr' || name === 'input' || name === 'meta' ||
      name === 'link' || name === 'source' || name === 'track' || name === 'wbr';
  }

  private objectNumber(value: string, key: string): string {
    const quoted = `\"${key}\"`;
    let marker = value.indexOf(quoted);
    if (marker < 0) {
      marker = value.indexOf(key);
    }
    if (marker < 0) {
      return '';
    }
    const colon = value.indexOf(':', marker + key.length);
    if (colon < 0) {
      return '';
    }
    let index = colon + 1;
    while (index < value.length && (value[index] === ' ' || value[index] === '\"' || value[index] === '\'')) {
      index++;
    }
    let output = '';
    while (index < value.length && value[index] >= '0' && value[index] <= '9') {
      output += value[index];
      index++;
    }
    return output;
  }

  private fillEmptyField(actions: PortalAction[], indexes: number[], actionUrl: string,
    fieldName: string, value: string): void {
    if (value.length === 0) {
      return;
    }
    for (let index = 0; index < indexes.length; index++) {
      const action = actions[indexes[index]];
      if (action.actionUrl !== actionUrl) {
        continue;
      }
      for (let fieldIndex = 0; fieldIndex < action.fields.length; fieldIndex++) {
        if (action.fields[fieldIndex].name === fieldName && action.fields[fieldIndex].value.length === 0) {
          action.fields[fieldIndex].value = value;
        }
      }
    }
  }
}
