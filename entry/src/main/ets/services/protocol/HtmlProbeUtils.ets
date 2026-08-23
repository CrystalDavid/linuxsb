export function hasClass(attributes: Map<string, string>, expected: string): boolean {
  const classValue = attributes.get('class');
  if (classValue === undefined) {
    return false;
  }
  let cursor = 0;
  while (cursor < classValue.length) {
    while (cursor < classValue.length && isWhitespace(classValue.charAt(cursor))) {
      cursor++;
    }
    const start = cursor;
    while (cursor < classValue.length && !isWhitespace(classValue.charAt(cursor))) {
      cursor++;
    }
    if (classValue.substring(start, cursor) === expected) {
      return true;
    }
  }
  return false;
}

export function collapseWhitespace(value: string): string {
  let output = '';
  let pendingSpace = false;
  for (let index = 0; index < value.length; index++) {
    const current = value.charAt(index);
    if (isWhitespace(current)) {
      pendingSpace = output.length > 0;
      continue;
    }
    if (pendingSpace) {
      output += ' ';
      pendingSpace = false;
    }
    output += current;
  }
  return output;
}

export function parseRouteId(value: string, routePrefix: string): number {
  const origin = 'https://linux.sb';
  let routeOffset = 0;
  if (value.startsWith(origin)) {
    routeOffset = origin.length;
  }
  if (!value.substring(routeOffset).startsWith(routePrefix)) {
    return 0;
  }
  return parseUnsignedAt(value, routeOffset + routePrefix.length);
}

export function parsePrefixedId(value: string, prefix: string): number {
  if (!value.startsWith(prefix)) {
    return 0;
  }
  return parseUnsignedAt(value, prefix.length);
}

export function parseFirstUnsigned(value: string): number {
  for (let index = 0; index < value.length; index++) {
    const current = value.charAt(index);
    if (current >= '0' && current <= '9') {
      return parseUnsignedAt(value, index);
    }
  }
  return 0;
}

export function extractBbsVersion(value: string): string {
  for (let index = 0; index + 2 < value.length; index++) {
    if (value.charAt(index).toLowerCase() !== 'v' || !isDigit(value.charAt(index + 1))) {
      continue;
    }
    let cursor = index + 1;
    let dotCount = 0;
    while (cursor < value.length) {
      const current = value.charAt(cursor);
      if (isDigit(current)) {
        cursor++;
        continue;
      }
      if (current === '.') {
        dotCount++;
        cursor++;
        continue;
      }
      break;
    }
    if (dotCount >= 2) {
      return value.substring(index, cursor);
    }
  }
  return '';
}

function parseUnsignedAt(value: string, start: number): number {
  if (start >= value.length || !isDigit(value.charAt(start))) {
    return 0;
  }
  let result = 0;
  let cursor = start;
  while (cursor < value.length && isDigit(value.charAt(cursor))) {
    result = result * 10 + value.charCodeAt(cursor) - 48;
    if (result > 2147483647) {
      return 0;
    }
    cursor++;
  }
  return result;
}

function isDigit(value: string): boolean {
  return value >= '0' && value <= '9';
}

function isWhitespace(value: string): boolean {
  return value === ' ' || value === '\n' || value === '\r' || value === '\t' || value === '\f';
}
