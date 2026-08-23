export interface WriteContractProbe {
  readonly enabled: boolean;
  readonly statusText: string;
}

export class DisabledWriteContractProbe implements WriteContractProbe {
  readonly enabled: boolean = false;
  readonly statusText: string = '真实写测试：未启用（需要用户明确授权和测试主题）';
}
