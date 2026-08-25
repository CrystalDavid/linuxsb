import { bundleManager, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';
import { beforeEach, describe, expect, it } from '@ohos/hypium';
import display from '@ohos.display';

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

    it('starts in the native Home with the centered four-tab immersive bar and Home FAB', 0, async () => {
      await componentById('home-topic-list');
      const tabBar = await componentById('immersive-bottom-tab-bar');
      const tabBounds = await tabBar.getBounds();
      const screenWidth = display.getDefaultDisplaySync().width;
      expect(Math.abs(tabBounds.left + tabBounds.right - screenWidth) <= 6).assertTrue();
      await componentById('bottom-tab-首页');
      await componentById('bottom-tab-板块');
      await componentById('bottom-tab-搜索');
      await componentById('bottom-tab-我的');
      await componentById('bottom-tab-selection-indicator');
      const homeIconBounds = await (await componentById('bottom-tab-icon-首页')).getBounds();
      const forumIconBounds = await (await componentById('bottom-tab-icon-板块')).getBounds();
      const searchIconBounds = await (await componentById('bottom-tab-icon-搜索')).getBounds();
      const profileIconBounds = await (await componentById('bottom-tab-icon-我的')).getBounds();
      expect(homeIconBounds.top).assertEqual(forumIconBounds.top);
      expect(homeIconBounds.top).assertEqual(searchIconBounds.top);
      expect(homeIconBounds.top).assertEqual(profileIconBounds.top);
      expect(homeIconBounds.bottom).assertEqual(forumIconBounds.bottom);
      expect(homeIconBounds.bottom).assertEqual(searchIconBounds.bottom);
      expect(homeIconBounds.bottom).assertEqual(profileIconBounds.bottom);
      const homeLabelBounds = await (await componentById('bottom-tab-label-首页')).getBounds();
      const forumLabelBounds = await (await componentById('bottom-tab-label-板块')).getBounds();
      const searchLabelBounds = await (await componentById('bottom-tab-label-搜索')).getBounds();
      const profileLabelBounds = await (await componentById('bottom-tab-label-我的')).getBounds();
      expect(homeLabelBounds.top).assertEqual(forumLabelBounds.top);
      expect(homeLabelBounds.top).assertEqual(searchLabelBounds.top);
      expect(homeLabelBounds.top).assertEqual(profileLabelBounds.top);
      expect(homeLabelBounds.bottom).assertEqual(forumLabelBounds.bottom);
      expect(homeLabelBounds.bottom).assertEqual(searchLabelBounds.bottom);
      expect(homeLabelBounds.bottom).assertEqual(profileLabelBounds.bottom);
      const fab = await componentById('home-write-fab');
      const fabBounds = await fab.getBounds();
      expect(fabBounds.bottom < tabBounds.top).assertTrue();
      expect((await componentsByType('Web')).length).assertEqual(0);
    });

    it('moves the single glass selection to another native tab', 0, async () => {
      const indicator = await componentById('bottom-tab-selection-indicator');
      const initialBounds = await indicator.getBounds();
      const board = await componentById('bottom-tab-板块');
      await board.click();
      await driver.delayMs(SETTLE_MS);
      await componentById('forums-page');
      const movedBounds = await (await componentById('bottom-tab-selection-indicator')).getBounds();
      expect(movedBounds.left > initialBounds.left).assertTrue();
      await openTab('bottom-tab-首页', 'home-page');
    });

    it('keeps the movable Home glass FAB clear of the bottom bar', 0, async () => {
      const fab = await componentById('home-write-fab');
      const tabBar = await componentById('immersive-bottom-tab-bar');
      const fabBounds = await fab.getBounds();
      const tabBounds = await tabBar.getBounds();
      expect(fabBounds.bottom < tabBounds.top).assertTrue();
      const centerX = Math.round((fabBounds.left + fabBounds.right) / 2);
      const centerY = Math.round((fabBounds.top + fabBounds.bottom) / 2);
      await driver.drag(centerX, centerY, centerX - 140, centerY - 160, 1200);
      await driver.delayMs(180);
      const movedBounds = await (await componentById('home-write-fab')).getBounds();
      expect(movedBounds.left < fabBounds.left).assertTrue();
      expect(movedBounds.top < fabBounds.top).assertTrue();
      expect(movedBounds.bottom < tabBounds.top).assertTrue();
      expect(await hasId('compose-topic-page')).assertFalse();
    });

    it('switches among Boards Search Mine and Home without a Web node', 0, async () => {
      await openTab('bottom-tab-板块', 'forums-page');
      await componentById('forum-directory');
      await openTab('bottom-tab-搜索', 'search-page');
      await componentById('search-field-title');
      await componentById('search-field-body');
      await componentById('search-field-reply');
      await openTab('bottom-tab-我的', 'profile-page');
      await openTab('bottom-tab-首页', 'home-page');
      // One tree-wide scan after all native destinations avoids four expensive TestKit traversals
      // while preserving the NoWebOutsideLogin invariant.
      expect((await componentsByType('Web')).length).assertEqual(0);
    });

    it('opens movable glass Settings and switches the persisted app theme', 0, async () => {
      await openTab('bottom-tab-我的', 'profile-page');
      const settingsFab = await componentById('profile-settings-fab');
      const tabBar = await componentById('immersive-bottom-tab-bar');
      const settingsBounds = await settingsFab.getBounds();
      const tabBounds = await tabBar.getBounds();
      expect(settingsBounds.bottom < tabBounds.top).assertTrue();
      await settingsFab.click();
      await componentById('settings-page');
      await componentById('settings-theme-picker');
      await (await componentById('theme-mode-light')).click();
      await driver.delayMs(SETTLE_MS);
      await componentById('settings-page');
      await (await componentById('theme-mode-dark')).click();
      await driver.delayMs(SETTLE_MS);
      await componentById('settings-page');
      await (await componentById('theme-mode-system')).click();
      await driver.delayMs(SETTLE_MS);
      await componentById('settings-page');
      await componentById('settings-home-layout-picker');
      await (await componentById('home-layout-author-first')).click();
      await driver.delayMs(SETTLE_MS);
      await (await componentById('home-layout-title-first')).click();
      await driver.delayMs(SETTLE_MS);
      await (await componentById('settings-back')).click();
      await componentById('profile-page');
      await openTab('bottom-tab-首页', 'home-page');
      await componentById('home-layout-title-first-active');
    });

    it('renders all four bottom icons with the single native ArkUI icon system', 0, async () => {
      await componentById('bottom-tab-native-icon-首页');
      await componentById('bottom-tab-native-icon-板块');
      await componentById('bottom-tab-native-icon-搜索');
      await componentById('bottom-tab-native-icon-我的');
      expect(await hasId('bottom-tab-vector-icon-首页')).assertFalse();
      expect(await hasId('bottom-tab-vector-icon-板块')).assertFalse();
      expect(await hasId('bottom-tab-vector-icon-搜索')).assertFalse();
      expect(await hasId('bottom-tab-vector-icon-我的')).assertFalse();
    });

    it('enters a Board before showing its feed and exposes the shared compact sort control', 0, async () => {
      await openTab('bottom-tab-板块', 'forums-page');
      await componentById('forum-directory');
      expect(await hasId('forums-topic-list')).assertFalse();
      await (await componentById('forum-first-row')).click();
      await componentById('forums-back');
      await componentById('forums-sort-comments');
      await componentById('forums-sort-topics');
      await (await componentById('forums-back')).click();
      await componentById('forum-directory');
    });

    it('opens the native composer without submitting real content', 0, async () => {
      await (await componentById('home-write-fab')).click();
      const composePage = await componentById('compose-topic-page');
      if (await hasId('compose-login-action')) {
        const density = display.getDefaultDisplaySync().densityPixels;
        const pageBounds = await composePage.getBounds();
        const gateBounds = await (await componentById('compose-login-gate')).getBounds();
        expect(gateBounds.top >= pageBounds.top).assertTrue();
        expect(gateBounds.top - pageBounds.top <= Math.round(density * 16)).assertTrue();
        expect(await hasId('compose-title')).assertFalse();
        expect(await hasId('compose-body')).assertFalse();
        expect(await hasId('compose-submit')).assertFalse();
        expect(await hasId('compose-forum-grid')).assertFalse();
      } else {
        await componentById('compose-title');
        await componentById('compose-body');
        await componentById('compose-submit');
        await componentById('compose-forum-grid');
      }
      expect((await componentsByType('Web')).length).assertEqual(0);
      await (await componentById('compose-back')).click();
      await componentById('home-page');
    });

    it('closes the temporary login Web before resuming the native page', 0, async () => {
      await openTab('bottom-tab-我的', 'profile-page');
      if (await hasId('profile-login-required')) {
        await (await componentById('profile-login-action')).click();
        await componentById('official-login-complete');
        const density = display.getDefaultDisplaySync().densityPixels;
        const rootBounds = await (await componentById('root-tab-page')).getBounds();
        const loginTitleBounds = await (await componentById('official-login-title')).getBounds();
        const completeBounds = await (await componentById('official-login-complete')).getBounds();
        expect(loginTitleBounds.top - rootBounds.top >= Math.round(density * 6)).assertTrue();
        expect(completeBounds.top - rootBounds.top >= Math.round(density * 6)).assertTrue();
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
      await componentById('topic-back');
      await componentById('topic-reply-input');
      await componentById('topic-reply-send');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await driver.pressBack();
      await componentById('home-page');
    });
  });
}
