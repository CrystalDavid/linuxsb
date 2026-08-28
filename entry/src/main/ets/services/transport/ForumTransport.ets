export type TransportErrorKind =
  'CANCELED' |
  'TIMEOUT' |
  'TLS' |
  'NETWORK' |
  'REDIRECT' |
  'HTTP_CLIENT' |
  'HTTP_SERVER' |
  'CONTENT_TYPE' |
  'BODY_DECODE' |
  'SESSION_CLOSED' |
  'UNKNOWN';

export interface TransportProbeError {
  kind: TransportErrorKind;
  code: number;
  message: string;
}

export interface TransportProbeMetadata {
  statusCode: number;
  byteLength: number;
  contentType: string;
  contentEncoding: string;
  elapsedMs: number;
  effectiveUrl: string;
  sha256: string;
  etag?: string;
  lastModified?: string;
  location?: string;
}

export interface TransportProbeResponse {
  metadata: TransportProbeMetadata;
  body: string;
  error?: TransportProbeError;
}

export class ForumFormFields {
  _csrf: string = '';
  id?: number;
  forum_id?: number;
  title?: string;
  body?: string;
  topic_id?: number;
}

export enum TransportCachePolicy {
  Product = 'Product',
  ProbeNoStore = 'ProbeNoStore'
}

export interface ForumTransport {
  getHome(cachePolicy?: TransportCachePolicy): Promise<TransportProbeResponse>;
  getFeedPage?(pageUrl: string, cookieHeader?: string,
    cachePolicy?: TransportCachePolicy): Promise<TransportProbeResponse>;
  getTopic(topicId: number, cachePolicy?: TransportCachePolicy,
    allowConditional?: boolean): Promise<TransportProbeResponse>;
  getAuthenticatedTopic(topicId: number, cookieHeader: string,
    cachePolicy?: TransportCachePolicy, allowConditional?: boolean): Promise<TransportProbeResponse>;
  getTopicPage?(topicId: number, pageUrl: string,
    cachePolicy?: TransportCachePolicy, allowConditional?: boolean): Promise<TransportProbeResponse>;
  getAuthenticatedTopicPage?(topicId: number, pageUrl: string, cookieHeader: string,
    cachePolicy?: TransportCachePolicy, allowConditional?: boolean): Promise<TransportProbeResponse>;
  getAuthenticatedNotifications(cookieHeader: string): Promise<TransportProbeResponse>;
  postForm?(pageUrl: string, fields: ForumFormFields,
    cookieHeader: string): Promise<TransportProbeResponse>;
  cancelAll(): void;
  close(): void;
}
