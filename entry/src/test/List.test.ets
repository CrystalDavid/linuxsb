import localUnitTest from './LocalUnit.test';
import probeDecoderTest from './ProbeDecoder.test';
import p0bReplyContractTest from './P0BReplyContract.test';
import m1VerticalSliceTest from './M1VerticalSlice.test';

export default function testsuite() {
  localUnitTest();
  probeDecoderTest();
  p0bReplyContractTest();
  m1VerticalSliceTest();
}
