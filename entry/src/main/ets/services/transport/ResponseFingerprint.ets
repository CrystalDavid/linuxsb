import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class ResponseFingerprint {
  static sha256Hex(body: ArrayBuffer | undefined): string {
    if (body === undefined) {
      return '';
    }
    try {
      const digest = cryptoFramework.createMd('SHA256');
      digest.updateSync({ data: new Uint8Array(body) });
      const bytes = digest.digestSync().data;
      let hex = '';
      for (let index = 0; index < bytes.length; index++) {
        const value = bytes[index].toString(16);
        hex += value.length === 1 ? `0${value}` : value;
      }
      return hex;
    } catch (_) {
      return '';
    }
  }
}
