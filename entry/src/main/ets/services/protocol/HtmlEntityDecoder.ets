export class HtmlEntityDecoder {
  static decode(value: string): string {
    let output = '';
    let cursor = 0;
    while (cursor < value.length) {
      if (value.charAt(cursor) !== '&') {
        output += value.charAt(cursor);
        cursor++;
        continue;
      }

      const semicolon = HtmlEntityDecoder.findSemicolon(value, cursor + 1);
      if (semicolon < 0) {
        output += '&';
        cursor++;
        continue;
      }

      const entity = value.substring(cursor + 1, semicolon);
      const decoded = HtmlEntityDecoder.decodeEntity(entity);
      if (decoded === undefined) {
        output += value.substring(cursor, semicolon + 1);
      } else {
        output += decoded;
      }
      cursor = semicolon + 1;
    }
    return output;
  }

  private static findSemicolon(value: string, from: number): number {
    const limit = Math.min(value.length, from + 12);
    for (let index = from; index < limit; index++) {
      const current = value.charAt(index);
      if (current === ';') {
        return index;
      }
      if (current === '&' || current === '<' || HtmlEntityDecoder.isWhitespace(current)) {
        return -1;
      }
    }
    return -1;
  }

  private static decodeEntity(entity: string): string | undefined {
    const normalized = entity.toLowerCase();
    if (normalized === 'amp') {
      return '&';
    }
    if (normalized === 'lt') {
      return '<';
    }
    if (normalized === 'gt') {
      return '>';
    }
    if (normalized === 'quot') {
      return '"';
    }
    if (normalized === 'apos' || normalized === '#39') {
      return "'";
    }
    if (normalized === 'nbsp') {
      return ' ';
    }

    if (normalized.length > 1 && normalized.charAt(0) === '#') {
      let radix = 10;
      let offset = 1;
      if (normalized.length > 2 && normalized.charAt(1) === 'x') {
        radix = 16;
        offset = 2;
      }
      const codePoint = HtmlEntityDecoder.parseUnsigned(normalized, offset, radix);
      if (codePoint >= 0) {
        return HtmlEntityDecoder.fromCodePoint(codePoint);
      }
    }
    return undefined;
  }

  private static parseUnsigned(value: string, offset: number, radix: number): number {
    if (offset >= value.length) {
      return -1;
    }
    let result = 0;
    for (let index = offset; index < value.length; index++) {
      const current = value.charAt(index);
      let digit = -1;
      if (current >= '0' && current <= '9') {
        digit = current.charCodeAt(0) - 48;
      } else if (radix === 16 && current >= 'a' && current <= 'f') {
        digit = current.charCodeAt(0) - 87;
      }
      if (digit < 0 || digit >= radix) {
        return -1;
      }
      result = result * radix + digit;
      if (result > 0x10FFFF) {
        return -1;
      }
    }
    return result;
  }

  private static fromCodePoint(codePoint: number): string {
    if (codePoint < 0 || codePoint > 0x10FFFF || (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
      return '\uFFFD';
    }
    if (codePoint <= 0xFFFF) {
      return String.fromCharCode(codePoint);
    }
    const adjusted = codePoint - 0x10000;
    const high = 0xD800 + (adjusted >> 10);
    const low = 0xDC00 + (adjusted & 0x3FF);
    return String.fromCharCode(high, low);
  }

  private static isWhitespace(value: string): boolean {
    return value === ' ' || value === '\n' || value === '\r' || value === '\t' || value === '\f';
  }
}
