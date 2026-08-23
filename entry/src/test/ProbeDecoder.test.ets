import { describe, expect, it } from '@ohos/hypium';
import { HomeProbeDecoder } from '../main/ets/services/protocol/HomeProbeDecoder';
import { TopicProbeDecoder } from '../main/ets/services/protocol/TopicProbeDecoder';

const HOME_FIXTURE = `<!doctype html>
<html>
<head>
  <link rel="stylesheet" href="/app/assets/index.css?v=v8.6.5">
  <script>const fake = '<a class="post-title" href="/topic/999">fake</a>';</script>
</head>
<body>
  <nav><a class="forum-link" href="/forum/4">技术 &amp; 交流</a></nav>
  <ul class="post-list">
    <li class="post-item">
      <a class="post-title" href="/topic/123">A &amp; B &#x4E2D;</a>
      <mystery-extension data-new="1"><span>unknown</span></mystery-extension>
      <a class="post-forum-badge" href="/forum/4">技术 &amp; 交流</a>
    </li>
  </ul>
</body>
</html>`;

const TOPIC_FIXTURE = `<!doctype html>
<html><body>
  <h1 class="post-content-title">标题 &lt;验证&gt;</h1>
  <div class="post-content-stats"><span>88</span><span>2</span></div>
  <ul class="post-list topic-post-list">
    <li class="post-item post-entry" id="post-123"><div>main</div></li>
    <li class="post-item post-entry" id="post-9001"><a class="post-floor">#1</a><x-new>ignored</x-new></li>
    <li class="post-item post-entry" id="post-9002" data-floor="2"><div>reply</div></li>
  </ul>
</body></html>`;

export default function probeDecoderTest() {
  describe('P0 lightweight protocol decoders', () => {
    it('decodes home version topics forums and entities', 0, () => {
      const result = new HomeProbeDecoder().decode(HOME_FIXTURE);
      expect(result.protocolMatched).assertTrue();
      expect(result.bbsVersion).assertEqual('v8.6.5');
      expect(result.topics.length).assertEqual(1);
      expect(result.topics[0].topicId).assertEqual(123);
      expect(result.topics[0].title).assertEqual('A & B 中');
      expect(result.topics[0].forumId).assertEqual(4);
      expect(result.topics[0].forumName).assertEqual('技术 & 交流');
      expect(result.forums.length).assertEqual(1);
    });

    it('keeps a home topic when its forum field is missing', 0, () => {
      const fixture = '<link href="/app/assets/index.css?v=v8.6.5"><li class="post-item"><a class="post-title" href="/topic/9">字段缺失</a></li>';
      const result = new HomeProbeDecoder().decode(fixture);
      expect(result.protocolMatched).assertTrue();
      expect(result.topics.length).assertEqual(1);
      expect(result.warnings.indexOf('TOPIC_FORUM_MISSING:9') >= 0).assertTrue();
    });

    it('reports a home protocol mismatch instead of inventing data', 0, () => {
      const result = new HomeProbeDecoder().decode('<html><body><unknown-card /></body></html>');
      expect(result.protocolMatched).assertFalse();
      expect(result.topics.length).assertEqual(0);
      expect(result.warnings.indexOf('BBS_VERSION_MISSING') >= 0).assertTrue();
      expect(result.warnings.indexOf('HOME_TOPIC_LIST_MISSING') >= 0).assertTrue();
    });

    it('decodes topic title counts reply ids and floors', 0, () => {
      const result = new TopicProbeDecoder().decode(TOPIC_FIXTURE, 123);
      expect(result.protocolMatched).assertTrue();
      expect(result.title).assertEqual('标题 <验证>');
      expect(result.viewCount).assertEqual(88);
      expect(result.advertisedReplyCount).assertEqual(2);
      expect(result.mainPostId).assertEqual(123);
      expect(result.replies.length).assertEqual(2);
      expect(result.replies[0].replyId).assertEqual(9001);
      expect(result.replies[0].floor).assertEqual(1);
      expect(result.replies[1].replyId).assertEqual(9002);
      expect(result.replies[1].floor).assertEqual(2);
    });

    it('distinguishes advertised replies from replies absent in the response', 0, () => {
      const fixture = '<h1 class="post-content-title">登录可见</h1><div class="post-content-stats"><span>10</span><span>5</span></div><li class="post-entry" id="post-77"></li>';
      const result = new TopicProbeDecoder().decode(fixture, 77);
      expect(result.protocolMatched).assertTrue();
      expect(result.advertisedReplyCount).assertEqual(5);
      expect(result.replies.length).assertEqual(0);
      expect(result.warnings.indexOf('REPLIES_NOT_PRESENT_IN_RESPONSE:5') >= 0).assertTrue();
    });

    it('reports missing fields and structure mismatch', 0, () => {
      const result = new TopicProbeDecoder().decode('<li class="post-entry" id="post-55"><new-extension /></li>', 56);
      expect(result.protocolMatched).assertFalse();
      expect(result.mainPostId).assertEqual(55);
      expect(result.warnings.indexOf('TOPIC_TITLE_MISSING') >= 0).assertTrue();
      expect(result.warnings.indexOf('TOPIC_ID_MISMATCH:56:55') >= 0).assertTrue();
    });
  });
}
