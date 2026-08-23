import localUnitTest from './LocalUnit.test';
import probeDecoderTest from './ProbeDecoder.test';
import p0bReplyContractTest from './P0BReplyContract.test';

export default function testsuite() {
  localUnitTest();
  probeDecoderTest();
  p0bReplyContractTest();
}
