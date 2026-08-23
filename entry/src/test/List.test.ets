import localUnitTest from './LocalUnit.test';
import probeDecoderTest from './ProbeDecoder.test';

export default function testsuite() {
  localUnitTest();
  probeDecoderTest();
}
