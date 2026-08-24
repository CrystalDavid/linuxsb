import { bundleManager, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';
import { beforeEach, describe, expect, it } from '@ohos/hypium';

const WAIT_MS: number = 20000;
const SETTLE_MS: number = 450;
let driver: Driver = Driver.create();

function productWant(): Want {
  const flags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
    bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_ABILITY;
  const info = bundleManager.getBundleInfoForSelfSync(flags);
  let abilityName: string = '';
  for (let index = 0; index < info.hapModulesInfo.length; index++) {
    if (info.hapModulesInfo[index].mainElementName.length > 0) {
      abilityName = info.hapModulesInfo[index].mainElementName;
      break;
    }
  }
  expect(abilityName.length > 0).assertTrue();
  return { bundleName: info.name, abilityName: abilityName };
}

async function componentById(id: string): Promise<Component> {
  const component = await driver.waitForComponent(ON.id(id), WAIT_MS);
  if (component === null || component === undefined) {
    throw new Error(`UI component not found: ${id}`);
  }
  return component;
}

async function componentsByType(type: string): Promise<Component[]> {
  const components = await driver.findComponents(ON.type(type));
  return components === null || components === undefined ? [] : components;
}

async function hasId(id: string): Promise<boolean> {
  const components = await driver.findComponents(ON.id(id));
  return components !== null && components !== undefined && components.length > 0;
}

async function openTab(id: string, pageId: string): Promise<void> {
  await (await componentById(id)).click();
  await componentById(pageId);
}

async function returnToHome(): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility(productWant());
  await componentById('root-tab-page');
  for (let attempt = 0; attempt < 3 && !(await hasId('immersive-bottom-tab-bar')); attempt++) {
    await driver.pressBack();
    await driver.delayMs(SETTLE_MS);
  }
  await componentById('immersive-bottom-tab-bar');
  if (!(await hasId('home-page'))) {
    await (await componentById('bottom-tab-首页')).click();
  }
  await componentById('home-page');
}

export default function m2r1UiTest() {
  describe('M3 native community shell semantic UI regression', () => {
    beforeEach(async () => {
      await returnToHome();
    });

    it('starts in the native Home with the five-position immersive tab bar', 0, async () => {
      await componentById('home-topic-list');
      await componentById('bottom-tab-首页');
      await componentById('bottom-tab-板块');
      await componentById('bottom-tab-compose');
      await componentById('bottom-tab-搜索');
      await componentById('bottom-tab-我的');
      expect((await componentsByType('Web')).length).assertEqual(0);
    });

    it('switches among Boards Search Mine and Home without a Web node', 0, async () => {
      await openTab('bottom-tab-板块', 'forums-page');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await openTab('bottom-tab-搜索', 'search-page');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await openTab('bottom-tab-我的', 'profile-page');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await openTab('bottom-tab-首页', 'home-page');
    });

    it('opens the native composer without submitting real content', 0, async () => {
      await (await componentById('bottom-tab-compose')).click();
      await componentById('compose-topic-page');
      await componentById('compose-title');
      await componentById('compose-body');
      await componentById('compose-submit');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await (await componentById('compose-back')).click();
      await componentById('home-page');
    });

    it('closes the temporary login Web before resuming the native page', 0, async () => {
      await openTab('bottom-tab-我的', 'profile-page');
      if (await hasId('profile-login-required')) {
        await (await componentById('profile-login-action')).click();
        await componentById('official-login-complete');
        expect((await componentsByType('Web')).length).assertEqual(1);
        await (await componentById('official-login-complete')).click();
        await componentById('profile-page');
        await driver.delayMs(SETTLE_MS);
        expect((await componentsByType('Web')).length).assertEqual(0);
      }
      await openTab('bottom-tab-首页', 'home-page');
    });

    it('navigates immediately to a native Topic and exposes the simple reply bar', 0, async () => {
      const firstTopic = await componentById('home-first-topic');
      await firstTopic.click();
      await componentById('topic-detail-page');
      const skeletonOrContent = (await hasId('topic-skeleton')) || (await hasId('topic-post-list'));
      expect(skeletonOrContent).assertTrue();
      await componentById('comment-input-bar');
      await componentById('topic-reply-input');
      await componentById('topic-reply-send');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await driver.pressBack();
      await componentById('home-page');
    });
  });
}
