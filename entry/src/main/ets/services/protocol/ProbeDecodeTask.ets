import { taskpool } from '@kit.ArkTS';
import { HomeProbeDecoder } from './HomeProbeDecoder';
import { TopicProbeDecoder } from './TopicProbeDecoder';
import { BackgroundProbeDecodeResult, ProbeDecodeKind, ProbeDecodeWireResult } from './ProbeModels';

@Concurrent
export function executeProbeDecode(kind: ProbeDecodeKind, html: string, inputBytes: number, topicId: number): string {
  const startedAt = Date.now();
  let wire: ProbeDecodeWireResult;
  if (kind === 'home') {
    const home = new HomeProbeDecoder().decode(html);
    wire = {
      kind: 'home',
      parseMs: Date.now() - startedAt,
      inputBytes: inputBytes,
      outputCount: home.topics.length,
      home: home
    };
  } else {
    const topic = new TopicProbeDecoder().decode(html, topicId);
    wire = {
      kind: 'topic',
      parseMs: Date.now() - startedAt,
      inputBytes: inputBytes,
      outputCount: 1 + topic.replies.length,
      topic: topic
    };
  }
  return JSON.stringify(wire);
}

export class ProbeDecodeTaskRunner {
  async decode(kind: ProbeDecodeKind, html: string, inputBytes: number, topicId: number = 0): Promise<BackgroundProbeDecodeResult> {
    try {
      const serialized = await taskpool.execute(executeProbeDecode, kind, html, inputBytes, topicId) as string;
      const wire = JSON.parse(serialized) as ProbeDecodeWireResult;
      return this.withExecution(wire, 'TASKPOOL', '');
    } catch (error) {
      const startedAt = Date.now();
      let wire: ProbeDecodeWireResult;
      if (kind === 'home') {
        const home = new HomeProbeDecoder().decode(html);
        wire = {
          kind: 'home',
          parseMs: Date.now() - startedAt,
          inputBytes: inputBytes,
          outputCount: home.topics.length,
          home: home
        };
      } else {
        const topic = new TopicProbeDecoder().decode(html, topicId);
        wire = {
          kind: 'topic',
          parseMs: Date.now() - startedAt,
          inputBytes: inputBytes,
          outputCount: 1 + topic.replies.length,
          topic: topic
        };
      }
      return this.withExecution(wire, 'UI_FALLBACK', this.safeErrorMessage(error));
    }
  }

  private withExecution(wire: ProbeDecodeWireResult, execution: 'TASKPOOL' | 'UI_FALLBACK', warning: string): BackgroundProbeDecodeResult {
    return {
      kind: wire.kind,
      parseMs: wire.parseMs,
      inputBytes: wire.inputBytes,
      outputCount: wire.outputCount,
      home: wire.home,
      topic: wire.topic,
      execution: execution,
      executionWarning: warning
    };
  }

  private safeErrorMessage(error: Object): string {
    const message = (error as Error).message;
    return message === undefined || message.length === 0 ? 'TaskPool execution failed' : message;
  }
}
