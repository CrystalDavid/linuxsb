// 把图片 markdown 片段按“选图那一刻输入框的光标位置”插入正文的共享逻辑。
// 发帖正文（TextArea）与回复输入（TextInput）共用同一套规则：
//   - 多张图按光标位置从大到小插入，先插后面的内容，避免把未插入项的
//     位置顶偏；
//   - 同一光标位置的多张图按选择顺序的逆序插入，保证最终在正文中出现
//     的顺序与选择顺序一致；
//   - 光标位置无效（未取到或越界）时退化为末尾追加，与旧版末尾拼接的
//     行为保持一致，任何异常都不会丢失图片。
export interface PendingMarkdownInsert {
  caretOffset: number;
  markdown: string;
  pickOrder: number;
}

export function insertMarkdownAtCaret(body: string, inserts: PendingMarkdownInsert[]): string {
  if (inserts.length === 0) {
    return body;
  }
  const ordered = inserts.slice().sort((left: PendingMarkdownInsert, right: PendingMarkdownInsert) => {
    if (left.caretOffset !== right.caretOffset) {
      return right.caretOffset - left.caretOffset;
    }
    return right.pickOrder - left.pickOrder;
  });
  let result = body;
  for (let index = 0; index < ordered.length; index++) {
    const insert = ordered[index];
    const fragment = `\n\n${insert.markdown}`;
    if (insert.caretOffset < 0 || insert.caretOffset > result.length) {
      result = result + fragment;
    } else {
      result = result.substring(0, insert.caretOffset) + fragment + result.substring(insert.caretOffset);
    }
  }
  return result;
}
