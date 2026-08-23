import { HtmlToken, HtmlTokenType, LightweightHtmlTokenizer } from './LightweightHtmlTokenizer';
import { collapseWhitespace, hasClass, parseFirstUnsigned, parsePrefixedId } from './HtmlProbeUtils';
import { ProtocolContentBlock, ProtocolPostDocument } from './ProductProtocolModels';

const MAX_BLOCKS_PER_POST = 64;
const MAX_TEXT_PER_BLOCK = 8192;

class PostContentDraft {
  postId: number = 0;
  floor: number = 0;
  author: string = '';
  blocks: ProtocolContentBlock[] = [];
  unsupportedTags: Set<string> = new Set<string>();
}

export class TopicContentDecoder {
  decode(html: string): ProtocolPostDocument[] {
    const posts: ProtocolPostDocument[] = [];
    let currentPost: PostContentDraft | undefined = undefined;
    let postListItemDepth = 0;
    let authorDepth = 0;
    let authorText = '';
    let contentDepth = 0;
    let pendingText = '';
    let captureKind = '';
    let captureTag = '';
    let captureDepth = 0;
    let captureText = '';
    let captureUrl = '';

    const flushPendingText = (): void => {
      if (currentPost === undefined) {
        pendingText = '';
        return;
      }
      const text = collapseWhitespace(pendingText);
      pendingText = '';
      if (text.length > 0) {
        this.addBlock(currentPost, 'Paragraph', text, '', '');
      }
    };

    const finishCapture = (): void => {
      if (currentPost === undefined || captureKind.length === 0) {
        captureKind = '';
        captureTag = '';
        captureDepth = 0;
        captureText = '';
        captureUrl = '';
        return;
      }
      const value = captureKind === 'CodeBlock' ? captureText.trim() : collapseWhitespace(captureText);
      if (value.length > 0 || captureKind === 'Link') {
        this.addBlock(currentPost, captureKind, value, captureUrl, '');
      }
      captureKind = '';
      captureTag = '';
      captureDepth = 0;
      captureText = '';
      captureUrl = '';
    };

    new LightweightHtmlTokenizer().scan(html, (token: HtmlToken) => {
      if (token.type === HtmlTokenType.START_TAG) {
        if (token.name === 'li' && hasClass(token.attributes, 'post-entry') && currentPost === undefined) {
          currentPost = new PostContentDraft();
          currentPost.postId = parsePrefixedId(token.attributes.get('id') ?? '', 'post-');
          currentPost.floor = parseFirstUnsigned(token.attributes.get('data-floor') ?? '');
          postListItemDepth = 1;
          return;
        }
        if (currentPost === undefined) {
          return;
        }
        if (token.name === 'li' && !this.isVoidTag(token.name) && !token.selfClosing) {
          postListItemDepth++;
        }
        if (token.name === 'a' && hasClass(token.attributes, 'post-author') && contentDepth === 0) {
          authorDepth = 1;
          authorText = '';
          return;
        }
        if (authorDepth > 0 && !token.selfClosing && !this.isVoidTag(token.name)) {
          authorDepth++;
          return;
        }
        if (token.name === 'div' && hasClass(token.attributes, 'post-content') && contentDepth === 0) {
          contentDepth = 1;
          pendingText = '';
          return;
        }
        if (contentDepth <= 0) {
          return;
        }

        if (!token.selfClosing && !this.isVoidTag(token.name)) {
          contentDepth++;
        }
        if (captureKind.length > 0) {
          if (token.name === 'br') {
            captureText += '\n';
          } else if (!token.selfClosing && !this.isVoidTag(token.name)) {
            captureDepth++;
          }
          return;
        }

        if (token.name === 'p') {
          flushPendingText();
        } else if (token.name === 'br') {
          flushPendingText();
          this.addBlock(currentPost, 'LineBreak', '', '', '');
        } else if (token.name === 'a') {
          flushPendingText();
          captureKind = 'Link';
          captureTag = 'a';
          captureDepth = 1;
          captureText = '';
          captureUrl = this.normalizeUrl(token.attributes.get('href') ?? '');
        } else if (token.name === 'blockquote') {
          flushPendingText();
          captureKind = 'Quote';
          captureTag = 'blockquote';
          captureDepth = 1;
          captureText = '';
        } else if (token.name === 'pre') {
          flushPendingText();
          captureKind = 'CodeBlock';
          captureTag = 'pre';
          captureDepth = 1;
          captureText = '';
        } else if (token.name === 'code') {
          flushPendingText();
          captureKind = 'InlineCode';
          captureTag = 'code';
          captureDepth = 1;
          captureText = '';
        } else if (token.name === 'img') {
          flushPendingText();
          const source = this.normalizeUrl(token.attributes.get('src') ?? '');
          const description = collapseWhitespace(token.attributes.get('alt') ?? '');
          if (source.length > 0) {
            this.addBlock(currentPost, 'Image', '', source, description);
          }
        } else if (this.isUnsupportedExtensionTag(token.name) && !currentPost.unsupportedTags.has(token.name)) {
          flushPendingText();
          currentPost.unsupportedTags.add(token.name);
          this.addBlock(currentPost, 'UnsupportedExtension', '', '', token.name);
        } else if (token.name === 'li') {
          pendingText += ' • ';
        }
        return;
      }

      if (token.type === HtmlTokenType.TEXT) {
        if (currentPost === undefined) {
          return;
        }
        if (authorDepth > 0) {
          authorText += token.text;
        } else if (contentDepth > 0) {
          if (captureKind.length > 0) {
            if (captureText.length < MAX_TEXT_PER_BLOCK) {
              captureText += token.text.substring(0, MAX_TEXT_PER_BLOCK - captureText.length);
            }
          } else if (pendingText.length < MAX_TEXT_PER_BLOCK) {
            pendingText += token.text.substring(0, MAX_TEXT_PER_BLOCK - pendingText.length);
          }
        }
        return;
      }

      if (token.type !== HtmlTokenType.END_TAG || currentPost === undefined) {
        return;
      }
      if (authorDepth > 0) {
        authorDepth--;
        if (authorDepth === 0 && token.name === 'a') {
          currentPost.author = collapseWhitespace(authorText);
          authorText = '';
        }
      }
      if (contentDepth > 0) {
        if (captureKind.length > 0) {
          captureDepth--;
          if (captureDepth === 0 && token.name === captureTag) {
            finishCapture();
          }
        } else if (token.name === 'p') {
          flushPendingText();
        }
        contentDepth--;
        if (contentDepth === 0) {
          finishCapture();
          flushPendingText();
        }
      }
      if (token.name === 'li') {
        postListItemDepth--;
        if (postListItemDepth === 0) {
          finishCapture();
          flushPendingText();
          this.finalizePost(currentPost, posts);
          currentPost = undefined;
          authorDepth = 0;
          contentDepth = 0;
        }
      }
    });

    if (currentPost !== undefined) {
      finishCapture();
      flushPendingText();
      this.finalizePost(currentPost, posts);
    }
    return posts;
  }

  private addBlock(post: PostContentDraft, kind: string, text: string, url: string, description: string): void {
    if (post.blocks.length >= MAX_BLOCKS_PER_POST) {
      return;
    }
    post.blocks.push({ kind: kind, text: text, url: url, description: description });
  }

  private finalizePost(post: PostContentDraft, posts: ProtocolPostDocument[]): void {
    if (post.postId <= 0) {
      return;
    }
    posts.push({
      postId: post.postId,
      floor: post.floor,
      author: post.author,
      blocks: post.blocks
    });
  }

  private normalizeUrl(value: string): string {
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return `https:${value}`;
    }
    if (value.startsWith('/')) {
      return `https://linux.sb${value}`;
    }
    return value;
  }

  private isUnsupportedExtensionTag(name: string): boolean {
    return name.indexOf('-') > 0 && name !== 'post-content';
  }

  private isVoidTag(name: string): boolean {
    return name === 'br' || name === 'img' || name === 'hr' || name === 'input' || name === 'meta' ||
      name === 'link' || name === 'source' || name === 'track' || name === 'wbr';
  }
}
