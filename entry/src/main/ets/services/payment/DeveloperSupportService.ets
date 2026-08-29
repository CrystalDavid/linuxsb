import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { iap } from '@kit.IAPKit';

export class DeveloperSupportProduct {
  productId: string;
  label: string;
  priceLabel: string;

  constructor(productId: string, label: string, priceLabel: string) {
    this.productId = productId;
    this.label = label;
    this.priceLabel = priceLabel;
  }
}

export class DeveloperSupportResult {
  completed: boolean = false;
  canceled: boolean = false;
  message: string = '';
}

interface PurchasePayload {
  purchaseToken?: string;
  purchaseOrderId?: string;
}

export const DEVELOPER_SUPPORT_PRODUCTS: DeveloperSupportProduct[] = [
  new DeveloperSupportProduct('linuxsb_tip_coin_1', '投喂一个硬币', '¥1.00'),
  new DeveloperSupportProduct('linuxsb_tip_water_5', '投喂一瓶水', '¥5.00'),
  new DeveloperSupportProduct('linuxsb_tip_coffee_9_9', '投喂一杯咖啡', '¥9.90'),
  new DeveloperSupportProduct('linuxsb_tip_pro_50', '投喂一个 pro 订阅', '¥50.00')
];

class DeveloperSupportService {
  async purchase(context: common.UIAbilityContext, product: DeveloperSupportProduct): Promise<DeveloperSupportResult> {
    const feedback = new DeveloperSupportResult();
    try {
      await iap.queryEnvironmentStatus(context);
      const purchaseResult = await iap.createPurchase(context, {
        productId: product.productId,
        productType: iap.ProductType.CONSUMABLE,
        developerPayload: 'linuxsb-developer-support'
      });
      let payload: PurchasePayload | undefined = undefined;
      try {
        payload = JSON.parse(purchaseResult.purchaseData) as PurchasePayload;
      } catch (_) {}
      if (payload?.purchaseToken === undefined || payload.purchaseToken.length === 0 ||
        payload.purchaseOrderId === undefined || payload.purchaseOrderId.length === 0) {
        feedback.message = '支付结果无法确认，请在华为订单中核对，勿重复支付';
        return feedback;
      }
      if (payload.purchaseToken.length > 0 && payload.purchaseOrderId.length > 0) {
        try {
          await iap.finishPurchase(context, {
            productType: iap.ProductType.CONSUMABLE,
            purchaseToken: payload.purchaseToken,
            purchaseOrderId: payload.purchaseOrderId
          });
        } catch (_) {
          feedback.completed = true;
          feedback.message = '支付已完成，订单确认处理中，请勿重复支付';
          return feedback;
        }
      }
      feedback.completed = true;
      feedback.message = `感谢你的支持：${product.label}`;
      return feedback;
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code === iap.IAPErrorCode.USER_CANCELED) {
        feedback.canceled = true;
        feedback.message = '已取消支付';
      } else if (businessError.code === iap.IAPErrorCode.APP_NOT_AUTHORIZED) {
        feedback.message = '华为支付尚未为当前应用授权';
      } else if (businessError.code === iap.IAPErrorCode.INVALID_PRODUCT) {
        feedback.message = '该投喂商品尚未在华为支付后台启用';
      } else if (businessError.code === 1001860050) {
        feedback.message = '请先登录华为账号后再支付';
      } else if (businessError.code === 1001860054) {
        feedback.message = '当前华为账号所在地区暂不支持支付';
      } else {
        feedback.message = businessError.code > 0 ? `华为支付暂不可用（${businessError.code}）` :
          '华为支付暂不可用，请稍后再试';
      }
      return feedback;
    }
  }
}

export const developerSupportService = new DeveloperSupportService();
