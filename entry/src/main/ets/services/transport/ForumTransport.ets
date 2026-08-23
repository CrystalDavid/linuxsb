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
  elapsedMs: number;
  effectiveUrl: string;
}

export interface TransportProbeResponse {
  metadata: TransportProbeMetadata;
  body: string;
  error?: TransportProbeError;
}

export interface ForumTransport {
  getHome(): Promise<TransportProbeResponse>;
  getTopic(topicId: number): Promise<TransportProbeResponse>;
  getAuthenticatedNotifications(cookieHeader: string): Promise<TransportProbeResponse>;
  cancelAll(): void;
  close(): void;
}
