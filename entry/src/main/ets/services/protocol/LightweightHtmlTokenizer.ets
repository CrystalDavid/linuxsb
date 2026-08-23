import { HtmlEntityDecoder } from './HtmlEntityDecoder';

export enum HtmlTokenType {
  START_TAG,
  END_TAG,
  TEXT
}

export interface HtmlToken {
  type: HtmlTokenType;
  name: string;
  attributes: Map<string, string>;
  text: string;
  selfClosing: boolean;
}

export type HtmlTokenVisitor = (token: HtmlToken) => void;

export class LightweightHtmlTokenizer {
  scan(html: string, visitor: HtmlTokenVisitor): void {
    let cursor = 0;
    let rawTextTag = '';
    while (cursor < html.length) {
      if (rawTextTag.length > 0) {
        const rawEnd = this.findRawTextEnd(html, cursor, rawTextTag);
        if (rawEnd < 0) {
          return;
        }
        cursor = rawEnd;
        rawTextTag = '';
      }

      if (html.charAt(cursor) !== '<') {
        const nextTag = html.indexOf('<', cursor);
        const end = nextTag < 0 ? html.length : nextTag;
        this.emitText(html.substring(cursor, end), visitor);
        cursor = end;
        continue;
      }

      if (this.startsWithAt(html, cursor, '<!--')) {
        const commentEnd = html.indexOf('-->', cursor + 4);
        cursor = commentEnd < 0 ? html.length : commentEnd + 3;
        continue;
      }

      if (cursor + 1 < html.length && (html.charAt(cursor + 1) === '!' || html.charAt(cursor + 1) === '?')) {
        cursor = this.skipUntilTagEnd(html, cursor + 2);
        continue;
      }

      if (cursor + 1 < html.length && html.charAt(cursor + 1) === '/') {
        cursor = this.readEndTag(html, cursor, visitor);
        continue;
      }

      const startResult = this.readStartTag(html, cursor, visitor);
      if (startResult.nextCursor === cursor + 1) {
        this.emitText('<', visitor);
      } else if (!startResult.selfClosing && (startResult.name === 'script' || startResult.name === 'style')) {
        rawTextTag = startResult.name;
      }
      cursor = startResult.nextCursor;
    }
  }

  private readStartTag(html: string, start: number, visitor: HtmlTokenVisitor): StartTagReadResult {
    let cursor = start + 1;
    if (cursor >= html.length || !this.isNameCharacter(html.charAt(cursor))) {
      return { nextCursor: start + 1, name: '', selfClosing: false };
    }

    const nameStart = cursor;
    while (cursor < html.length && this.isNameCharacter(html.charAt(cursor))) {
      cursor++;
    }
    const name = html.substring(nameStart, cursor).toLowerCase();
    const attributes = new Map<string, string>();
    let selfClosing = false;

    while (cursor < html.length) {
      cursor = this.skipWhitespace(html, cursor);
      if (cursor >= html.length) {
        break;
      }
      if (html.charAt(cursor) === '>') {
        cursor++;
        break;
      }
      if (html.charAt(cursor) === '/' && cursor + 1 < html.length && html.charAt(cursor + 1) === '>') {
        selfClosing = true;
        cursor += 2;
        break;
      }

      const attributeStart = cursor;
      while (cursor < html.length && this.isAttributeNameCharacter(html.charAt(cursor))) {
        cursor++;
      }
      if (attributeStart === cursor) {
        cursor++;
        continue;
      }
      const attributeName = html.substring(attributeStart, cursor).toLowerCase();
      cursor = this.skipWhitespace(html, cursor);
      let attributeValue = '';
      if (cursor < html.length && html.charAt(cursor) === '=') {
        cursor++;
        cursor = this.skipWhitespace(html, cursor);
        const valueResult = this.readAttributeValue(html, cursor);
        attributeValue = HtmlEntityDecoder.decode(valueResult.value);
        cursor = valueResult.nextCursor;
      }
      attributes.set(attributeName, attributeValue);
    }

    visitor({
      type: HtmlTokenType.START_TAG,
      name: name,
      attributes: attributes,
      text: '',
      selfClosing: selfClosing
    });
    return { nextCursor: cursor, name: name, selfClosing: selfClosing };
  }

  private readEndTag(html: string, start: number, visitor: HtmlTokenVisitor): number {
    let cursor = this.skipWhitespace(html, start + 2);
    const nameStart = cursor;
    while (cursor < html.length && this.isNameCharacter(html.charAt(cursor))) {
      cursor++;
    }
    const name = html.substring(nameStart, cursor).toLowerCase();
    cursor = this.skipUntilTagEnd(html, cursor);
    if (name.length > 0) {
      visitor({
        type: HtmlTokenType.END_TAG,
        name: name,
        attributes: new Map<string, string>(),
        text: '',
        selfClosing: false
      });
    }
    return cursor;
  }

  private readAttributeValue(html: string, start: number): AttributeReadResult {
    if (start >= html.length) {
      return { value: '', nextCursor: start };
    }
    const quote = html.charAt(start);
    if (quote === '"' || quote === "'") {
      const valueStart = start + 1;
      let cursor = valueStart;
      while (cursor < html.length && html.charAt(cursor) !== quote) {
        cursor++;
      }
      const value = html.substring(valueStart, cursor);
      return { value: value, nextCursor: cursor < html.length ? cursor + 1 : cursor };
    }

    let cursor = start;
    while (cursor < html.length) {
      const current = html.charAt(cursor);
      if (this.isWhitespace(current) || current === '>' || (current === '/' && cursor + 1 < html.length && html.charAt(cursor + 1) === '>')) {
        break;
      }
      cursor++;
    }
    return { value: html.substring(start, cursor), nextCursor: cursor };
  }

  private emitText(value: string, visitor: HtmlTokenVisitor): void {
    if (value.length === 0) {
      return;
    }
    visitor({
      type: HtmlTokenType.TEXT,
      name: '',
      attributes: new Map<string, string>(),
      text: HtmlEntityDecoder.decode(value),
      selfClosing: false
    });
  }

  private findRawTextEnd(html: string, start: number, tagName: string): number {
    for (let cursor = start; cursor + tagName.length + 2 <= html.length; cursor++) {
      if (html.charAt(cursor) !== '<' || html.charAt(cursor + 1) !== '/') {
        continue;
      }
      if (this.regionEqualsIgnoreCase(html, cursor + 2, tagName)) {
        return cursor;
      }
    }
    return -1;
  }

  private regionEqualsIgnoreCase(value: string, offset: number, expected: string): boolean {
    if (offset + expected.length > value.length) {
      return false;
    }
    for (let index = 0; index < expected.length; index++) {
      if (value.charAt(offset + index).toLowerCase() !== expected.charAt(index)) {
        return false;
      }
    }
    const boundary = offset + expected.length;
    return boundary >= value.length || this.isWhitespace(value.charAt(boundary)) || value.charAt(boundary) === '>';
  }

  private startsWithAt(value: string, offset: number, expected: string): boolean {
    if (offset + expected.length > value.length) {
      return false;
    }
    for (let index = 0; index < expected.length; index++) {
      if (value.charAt(offset + index) !== expected.charAt(index)) {
        return false;
      }
    }
    return true;
  }

  private skipUntilTagEnd(value: string, start: number): number {
    const end = value.indexOf('>', start);
    return end < 0 ? value.length : end + 1;
  }

  private skipWhitespace(value: string, start: number): number {
    let cursor = start;
    while (cursor < value.length && this.isWhitespace(value.charAt(cursor))) {
      cursor++;
    }
    return cursor;
  }

  private isWhitespace(value: string): boolean {
    return value === ' ' || value === '\n' || value === '\r' || value === '\t' || value === '\f';
  }

  private isNameCharacter(value: string): boolean {
    return (value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z') ||
      (value >= '0' && value <= '9') || value === '-' || value === '_' || value === ':';
  }

  private isAttributeNameCharacter(value: string): boolean {
    return this.isNameCharacter(value) || value === '.' || value === '@';
  }
}

interface StartTagReadResult {
  nextCursor: number;
  name: string;
  selfClosing: boolean;
}

interface AttributeReadResult {
  value: string;
  nextCursor: number;
}
