export enum ContentBlockKind {
  Paragraph = 'Paragraph',
  Heading = 'Heading',
  ListItem = 'ListItem',
  LineBreak = 'LineBreak',
  Link = 'Link',
  Quote = 'Quote',
  InlineCode = 'InlineCode',
  CodeBlock = 'CodeBlock',
  Image = 'Image',
  UnsupportedExtension = 'UnsupportedExtension'
}

export interface ContentBlock {
  kind: ContentBlockKind;
  text: string;
  url: string;
  description: string;
}

export function paragraphBlock(text: string): ContentBlock {
  return {
    kind: ContentBlockKind.Paragraph,
    text: text,
    url: '',
    description: ''
  };
}

export function unsupportedBlock(description: string): ContentBlock {
  return {
    kind: ContentBlockKind.UnsupportedExtension,
    text: '',
    url: '',
    description: description
  };
}
