import { bundleManager, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit';
import { beforeEach, describe, expect, it } from '@ohos/hypium';

const WAIT_MS: number = 20000;
const SETTLE_MS: number = 500;
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

async function returnToHome(): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility(productWant());
  await driver.delayMs(SETTLE_MS);
  for (let attempt = 0; attempt < 4 && !(await hasId('home-page')); attempt++) {
    await driver.pressBack();
    await driver.delayMs(SETTLE_MS);
  }
  await componentById('home-page');
}

export default function m2r1UiTest() {
  describe('M2-R1 semantic UI regression', () => {
    beforeEach(async () => {
      await returnToHome();
    })

    it('starts in the compact formal Home without a Web node', 0, async () => {
      await componentById('root-tab-page');
      await componentById('home-menu');
      await componentById('home-search');
      await componentById('home-account');
      await componentById('home-topic-list');
      expect((await componentsByType('Web')).length).assertEqual(0);
    })

    it('opens and closes the semantic 288vp filter drawer', 0, async () => {
      await (await componentById('home-menu')).click();
      const drawer = await componentById('category-drawer');
      const bounds = await drawer.getBounds();
      expect(bounds.right > bounds.left).assertTrue();
      expect(bounds.bottom > bounds.top).assertTrue();
      await (await componentById('category-drawer-close')).click();
      await driver.delayMs(SETTLE_MS);
      expect(await hasId('category-drawer')).assertFalse();
    })

    it('navigates immediately to Topic UI and returns without a Web node', 0, async () => {
      const firstTopic = await componentById('home-first-topic');
      await firstTopic.click();
      await componentById('topic-detail-page');
      const skeletonOrContent = (await hasId('topic-skeleton')) || (await hasId('topic-post-list'));
      expect(skeletonOrContent).assertTrue();
      await componentById('comment-input-disabled');
      expect((await componentsByType('Web')).length).assertEqual(0);
      await driver.pressBack();
      await componentById('home-page');
    })

    it('keeps the Home write affordance disabled and Web-free', 0, async () => {
      await (await componentById('home-write-fab')).click();
      expect((await componentsByType('Web')).length).assertEqual(0);
    })
  })
}
