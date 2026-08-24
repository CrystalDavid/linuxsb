import localUnitTest from './LocalUnit.test';
import probeDecoderTest from './ProbeDecoder.test';
import p0bReplyContractTest from './P0BReplyContract.test';
import m1VerticalSliceTest from './M1VerticalSlice.test';
import m2r1ContractTest from './M2R1Contract.test';
import m2r11ContractTest from './M2R11Contract.test';
import m3CommunityShellTest from './M3CommunityShell.test';

export default function testsuite() {
  localUnitTest();
  probeDecoderTest();
  p0bReplyContractTest();
  m1VerticalSliceTest();
  m2r1ContractTest();
  m2r11ContractTest();
  m3CommunityShellTest();
}
