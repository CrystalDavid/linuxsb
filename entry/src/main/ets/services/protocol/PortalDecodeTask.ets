import { taskpool } from '@kit.ArkTS';
import { PortalDocument } from '../../models/PortalModels';
import { PortalPageDecoder } from './PortalPageDecoder';

interface PortalDecodeWireResult {
  document: PortalDocument;
}

@Concurrent
export function executePortalDecode(html: string, path: string): string {
  const wire: PortalDecodeWireResult = { document: new PortalPageDecoder().decode(html, path) };
  return JSON.stringify(wire);
}

export class PortalDecodeTaskRunner {
  async decode(html: string, path: string): Promise<PortalDocument> {
    const serialized = await taskpool.execute(executePortalDecode, html, path) as string;
    return (JSON.parse(serialized) as PortalDecodeWireResult).document;
  }
}
