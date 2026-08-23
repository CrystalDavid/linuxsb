import { describe, expect, it } from '@ohos/hypium';
import { TopicProbeDecoder } from '../main/ets/services/protocol/TopicProbeDecoder';
import { TopicStructureProbe } from '../main/ets/services/protocol/TopicStructureProbe';

const FIVE_REPLY_FIXTURE = `<!doctype html>
<html><head><link rel="stylesheet" href="/app/assets/index.css?v=v8.6.5"></head><body>
  <h1 class="post-content-title">Fictitious topic</h1>
  <div class="post-content-stats"><span>25</span><span>5</span></div>
  <ul class="post-list topic-post-list">
    <li class="post-item post-entry" id="post-605"><a class="post-author" href="/user/100">topic-author</a><div class="post-content">main block</div></li>
    <li class="post-item post-entry" id="post-7101" data-floor="1"><a class="post-author" href="/user/101">user-a</a><a class="post-floor" href="/topic/605?floor=1">#1</a><div class="post-content">reply &amp; one</div></li>
    <li class="post-item post-entry" id="post-7102" data-floor="2"><a class="post-author" href="/user/102">user-b</a><a class="post-floor" href="/topic/605?floor=2">#2</a><div class="post-content">reply two</div></li>
    <li class="post-item post-entry" id="post-7103" data-floor="3"><a class="post-author" href="/user/103">user-c</a><a class="post-floor" href="/topic/605?floor=3">#3</a><div class="post-content">reply three</div></li>
    <li class="post-item post-entry" id="post-7104" data-floor="4"><a class="post-author" href="/user/104">user-d</a><a class="post-floor" href="/topic/605?floor=4">#4</a><div class="post-content">reply four</div></li>
    <li class="post-item post-entry" id="post-7105" data-floor="5"><a class="post-author" href="/user/105">user-e</a><a class="post-floor" href="/topic/605?floor=5">#5</a><div class="post-content">reply five</div></li>
  </ul>
</body></html>`;

export default function p0bReplyContractTest() {
  describe('P0-B reply source and decoder contract', () => {
    it('decodes five same-page replies with unique ids and consecutive floors', 0, () => {
      const result = new TopicProbeDecoder().decode(FIVE_REPLY_FIXTURE, 605);
      expect(result.protocolMatched).assertTrue();
      expect(result.advertisedReplyCount).assertEqual(5);
      expect(result.replies.length).assertEqual(5);
      for (let index = 0; index < result.replies.length; index++) {
        expect(result.replies[index].replyId).assertEqual(7101 + index);
        expect(result.replies[index].floor).assertEqual(index + 1);
      }
    });

    it('keeps the main post out of the reply list', 0, () => {
      const result = new TopicProbeDecoder().decode(FIVE_REPLY_FIXTURE, 605);
      expect(result.mainPostId).assertEqual(605);
      expect(result.replies.findIndex(item => item.replyId === 605)).assertEqual(-1);
    });

    it('decodes fictitious author body and HTML entities', 0, () => {
      const result = new TopicProbeDecoder().decode(FIVE_REPLY_FIXTURE, 605);
      expect(result.replies[0].author).assertEqual('user-a');
      expect(result.replies[0].bodyText).assertEqual('reply & one');
    });

    it('accepts a floor anchor when data-floor is absent', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>1</span></div>' +
        '<li class="post-entry" id="post-605"></li><li class="post-entry" id="post-8001"><a class="post-author">user-x</a>' +
        '<a class="post-floor" href="#reply8001">#1</a><div class="post-content">body-x</div></li>';
      const result = new TopicProbeDecoder().decode(fixture, 605);
      const structure = new TopicStructureProbe().scan(fixture);
      expect(result.replies.length).assertEqual(1);
      expect(result.replies[0].floor).assertEqual(1);
      expect(structure.floorAnchorCount).assertEqual(1);
    });

    it('deduplicates duplicate reply containers by reply id', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>1</span></div>' +
        '<li class="post-entry" id="post-605"></li>' +
        '<li class="post-entry" id="post-8101" data-floor="1"><a class="post-author">a</a><div class="post-content">one</div></li>' +
        '<li class="post-entry" id="post-8101" data-floor="1"><a class="post-author">a</a><div class="post-content">duplicate</div></li>';
      const result = new TopicProbeDecoder().decode(fixture, 605);
      expect(result.replies.length).assertEqual(1);
      expect(result.warnings.indexOf('DUPLICATE_REPLY_ID:8101') >= 0).assertTrue();
    });

    it('does not treat quote and reference links as reply containers', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>0</span></div>' +
        '<li class="post-entry" id="post-605"><a href="/topic/605?replyid=999">quoted</a><a href="#reply999">reference</a></li>';
      const decoded = new TopicProbeDecoder().decode(fixture, 605);
      const structure = new TopicStructureProbe().scan(fixture);
      expect(decoded.replies.length).assertEqual(0);
      expect(structure.replyReferenceLinkCount).assertEqual(2);
      expect(structure.candidateReplyContainerCount).assertEqual(0);
    });

    it('counts actual pagination links without constructing a route', 0, () => {
      const fixture = FIVE_REPLY_FIXTURE + '<div class="pagination-bar"><div class="pagination"><ul>' +
        '<li><a href="/topic/605?p=1">1</a></li><li><a href="/topic/605?p=2">next</a></li></ul></div></div>';
      const structure = new TopicStructureProbe().scan(fixture);
      expect(structure.paginationLinkCount).assertEqual(2);
      expect(structure.topicLinkCount >= 7).assertTrue();
    });

    it('keeps a reply intact when an unknown plugin inserts nested list content', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>1</span></div>' +
        '<li class="post-entry" id="post-605"></li><li class="post-entry" id="post-8201" data-floor="1">' +
        '<a class="post-author">user-plugin</a><div class="post-content">before<plugin-box><ul><li>plugin item</li></ul></plugin-box>after</div></li>';
      const result = new TopicProbeDecoder().decode(fixture, 605);
      expect(result.replies.length).assertEqual(1);
      expect(result.replies[0].replyId).assertEqual(8201);
      expect(result.replies[0].bodyText).assertEqual('beforeplugin itemafter');
    });

    it('reports an explicit mismatch for an unknown reply container contract', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>1</span></div>' +
        '<li class="post-entry" id="post-605"></li><article id="reply-8301" data-floor="1"><p>unknown shape</p></article>';
      const decoded = new TopicProbeDecoder().decode(fixture, 605);
      const structure = new TopicStructureProbe().scan(fixture);
      expect(decoded.replies.length).assertEqual(0);
      expect(decoded.warnings.indexOf('REPLY_STRUCTURE_MISMATCH') >= 0).assertTrue();
      expect(structure.replyIdPrefixCount).assertEqual(1);
      expect(structure.candidateReplyContainerCount).assertEqual(1);
    });

    it('distinguishes an explicit anonymous login gate from an unknown structure', 0, () => {
      const fixture = '<h1 class="post-content-title">x</h1><div class="post-content-stats"><span>1</span><span>5</span></div>' +
        '<li class="post-entry" id="post-605"></li><section class="replies-login-visible" data-replies-login-visible="1"></section>';
      const decoded = new TopicProbeDecoder().decode(fixture, 605);
      const structure = new TopicStructureProbe().scan(fixture);
      expect(decoded.warnings.indexOf('REPLIES_LOGIN_GATED:5') >= 0).assertTrue();
      expect(decoded.warnings.indexOf('REPLY_STRUCTURE_MISMATCH')).assertEqual(-1);
      expect(structure.loginVisibleMarkerCount).assertEqual(1);
    });

    it('reports declared and actual reply count mismatch without inventing data', 0, () => {
      const fixture = FIVE_REPLY_FIXTURE.replace('<span>5</span></div>', '<span>4</span></div>');
      const result = new TopicProbeDecoder().decode(fixture, 605);
      expect(result.replies.length).assertEqual(5);
      expect(result.warnings.indexOf('REPLY_COUNT_MISMATCH:4:5') >= 0).assertTrue();
    });

    it('reports the BBS version and the known same-page marker counts', 0, () => {
      const structure = new TopicStructureProbe().scan(FIVE_REPLY_FIXTURE);
      expect(structure.detectedBbsVersion).assertEqual('v8.6.5');
      expect(structure.postIdPrefixCount).assertEqual(6);
      expect(structure.dataFloorCount).assertEqual(5);
      expect(structure.knownPostEntryMarkerCount).assertEqual(6);
      expect(structure.candidateReplyContainerCount).assertEqual(5);
      expect(structure.floorAnchorCount).assertEqual(5);
    });
  });
}
