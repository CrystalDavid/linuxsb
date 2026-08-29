import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { PageMetrics, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { pickImagesFromGallery } from '../../common/utils/PhotoPicker';
import { buildImmersiveTitleBarStyle } from '../../common/ui/ImmersiveTitleBarStyle';
import {
  ImmersiveLightArea,
  requiresHdsComponentSafeArea,
  requiresHdsLayoutSafeAreaAvoidance
} from '../../common/ui/ImmersiveLightMaterial';
import { CurrentUserSummary, HomeFeedRequest } from '../../models/HomeModels';
import {
  PortalAction, PortalActionResult, PortalCard, PortalDocument, PortalLink, PortalLoadResult
} from '../../models/PortalModels';
import { TopicUiModel, UserUiModel } from '../../models/presentation/ForumUiModels';
import { ArrayDataSource } from '../../models/presentation/ArrayDataSource';
import { AttachmentUploadResult, WriteResult } from '../../services/repository/WriteRepository';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { ViewLoadState } from '../../viewmodels/ViewState';
import { AccountLoginGate } from '../components/AccountLoginGate';
import { CommentInputBar } from '../components/CommentInputBar';
import { ImmersiveGlassTextButton } from '../components/ImmersiveGlassTextButton';
import {
  ImmersiveIconButton, TITLE_BAR_BACK_BUTTON_SIZE, TITLE_BAR_BACK_ICON_SIZE, TITLE_BAR_BACK_ICON_WEIGHT
} from '../components/ImmersiveIconButton';
import { PaginatedTopicList } from '../components/PaginatedTopicList';
import { UserAvatar } from '../components/UserAvatar';

enum ProfileTab {
  Topics = 0,
  Replies = 1
}

const PROFILE_AVATAR_PRESET_SEEDS: string[] = [
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24'
];

@Component({ freezeWhenInactive: true })
export struct ProfilePage {
  @ObjectLink sessionViewModel: HomeViewModel;
  @ObjectLink profileViewModel: HomeViewModel;
  @Prop @Watch('onAuthenticatedChanged') authenticated: boolean = false;
  @Prop @Watch('onLoginGenerationChanged') loginGeneration: number = 0;
  bottomContentInset: number = PageMetrics.BOTTOM_TAB_BAR_CONTENT_INSET;
  onLogin: () => void = () => {};
  onTopicSelected: (topic: TopicUiModel) => void = () => {};
  onOpenTopicLocation: (topicId: number, replyId: number, title: string) => void = () => {};
  onLoadPortal: (path: string) => Promise<PortalLoadResult> =
    async () => ({ ok: false, message: '当前服务不可用' });
  onSubmitPortal: (action: PortalAction) => Promise<PortalActionResult> =
    async () => ({ ok: false, message: '当前服务不可用' });
  onUploadImage: (uri: string) => Promise<AttachmentUploadResult> =
    async () => ({ ok: false, markdown: '', message: '上传服务不可用', networkMs: 0 });
  onUploadAvatar: (uri: string) => Promise<PortalActionResult> =
    async () => ({ ok: false, message: '头像上传服务不可用' });
  @State private selectedTab: ProfileTab = ProfileTab.Topics;
  @State private selectedFeature: number = 0;
  @State private portalTitle: string = '';
  @State private portalPath: string = '';
  @State private portalLoading: boolean = false;
  @State private portalError: string = '';
  @State private portalDocument: PortalDocument | undefined = undefined;
  private portalPendingReload: boolean = false;
  @State private resolvingProfile: boolean = false;
  @State private profileError: string = '';
  @State private user: CurrentUserSummary | undefined = undefined;
  @State private walletRedeemCode: string = '';
  @State private walletSubmitting: boolean = false;
  @State private directMessageDraft: string = '';
  @State private profileUsernameDraft: string = '';
  @State private profileCurrentPassword: string = '';
  @State private profileBioDraft: string = '';
  @State private profilePasswordDraft: string = '';
  @State private profilePasswordConfirm: string = '';
  @State private profileAvatarSeed: string = '';
  @State private profileAvatarStyle: string = 'bottts-neutral';
  @State private bioSubmitting: boolean = false;
  @State private passwordSubmitting: boolean = false;
  @State private usernameSubmitting: boolean = false;
  @State private avatarSubmitting: boolean = false;
  private avatarPresetDataSource: ArrayDataSource<string> =
    new ArrayDataSource<string>(PROFILE_AVATAR_PRESET_SEEDS);
  private portalCardDataSource: ArrayDataSource<PortalCard> = new ArrayDataSource<PortalCard>();

  aboutToAppear(): void {
    this.resolveProfile();
  }

  private onAuthenticatedChanged(): void {
    if (this.authenticated) {
      this.resolveProfile(true);
    } else {
      this.user = undefined;
      this.profileError = '';
    }
  }

  // Fires on every completed official login, including re-logins that keep the
  // authenticated flag unchanged, so the profile never shows a previous account.
  private onLoginGenerationChanged(): void {
    if (this.authenticated) {
      this.resolveProfile(true);
    }
  }

  private async resolveProfile(forceRefresh: boolean = false): Promise<void> {
    if (!this.authenticated || this.resolvingProfile) {
      return;
    }
    this.resolvingProfile = true;
    this.profileError = '';
    if (forceRefresh || this.sessionViewModel.currentUser === undefined) {
      await this.sessionViewModel.load(true);
    }
    this.user = this.sessionViewModel.currentUser;
    if (this.user === undefined || this.user.userId <= 0) {
      this.profileError = '暂时无法识别当前登录用户';
      this.resolvingProfile = false;
      return;
    }
    this.profileViewModel.configure(HomeFeedRequest.user(this.user.userId, this.selectedTab === ProfileTab.Replies));
    if (this.profileViewModel.state === ViewLoadState.Idle || forceRefresh) {
      await this.profileViewModel.load(forceRefresh);
    }
    this.resolvingProfile = false;
  }

  private async changeTab(tab: ProfileTab): Promise<void> {
    this.selectedFeature = tab === ProfileTab.Topics ? 0 : 1;
    this.portalPath = '';
    this.portalDocument = undefined;
    this.portalError = '';
    if (this.selectedTab === tab || this.user === undefined) {
      return;
    }
    this.selectedTab = tab;
    this.profileViewModel.configure(HomeFeedRequest.user(this.user.userId, tab === ProfileTab.Replies));
    await this.profileViewModel.load(false);
  }

  private async openFeature(index: number): Promise<void> {
    if (index <= 1) {
      await this.changeTab(index === 0 ? ProfileTab.Topics : ProfileTab.Replies);
      return;
    }
    const currentUser = this.user;
    if (currentUser === undefined) {
      return;
    }
    this.selectedFeature = index;
    if (index === 2) {
      this.portalTitle = '我的私信';
      this.portalPath = '/direct_messages';
    } else if (index === 3) {
      this.portalTitle = '我的积分';
      this.portalPath = `/user/${currentUser.userId}?tab=points_rewards`;
    } else if (index === 4) {
      this.portalTitle = '我的收藏';
      this.portalPath = `/user/${currentUser.userId}?tab=favorites`;
    } else if (index === 5) {
      this.portalTitle = '我的消息';
      this.portalPath = `/user/${currentUser.userId}?tab=notifications`;
    } else if (index === 6) {
      this.portalTitle = '我的烧饼';
      this.portalPath = '/community_wallet';
    } else {
      this.portalTitle = '个人设置';
      this.portalPath = '/profile';
    }
    this.portalDocument = undefined;
    await this.loadPortal();
  }

  private async loadPortal(): Promise<void> {
    if (this.portalPath.length === 0) {
      return;
    }
    if (this.portalLoading) {
      this.portalPendingReload = true;
      return;
    }
    const path = this.portalPath;
    this.portalLoading = true;
    this.portalError = '';
    try {
      const result = await this.onLoadPortal(path);
      if (path === this.portalPath) {
        this.portalDocument = result.document;
        if (!result.ok || result.document === undefined) {
          this.portalCardDataSource.reset([]);
          this.portalError = result.message;
        } else {
          this.portalCardDataSource.reset(this.portalCards());
          if (path === '/profile') {
            this.hydrateProfileSettings(result.document);
          }
        }
      }
    } finally {
      this.portalLoading = false;
      if (this.portalPendingReload || path !== this.portalPath) {
        this.portalPendingReload = false;
        this.loadPortal();
      }
    }
  }

  private async followPortalLink(link: PortalLink): Promise<void> {
    const topicId = this.routeId(link.path, '/topic/');
    if (topicId > 0) {
      this.onOpenTopicLocation(topicId, this.queryNumber(link.path, 'replyid'), link.label.replace(/\s+/g, ' '));
      return;
    }
    this.portalPath = link.path;
    this.portalTitle = link.label.split('\n')[0];
    this.portalDocument = undefined;
    await this.loadPortal();
  }

  private async openConversation(card: PortalCard): Promise<void> {
    let link = this.firstLink(card, '/direct_messages/');
    if (link === undefined && card.key.startsWith('/direct_messages/')) {
      link = { label: this.cardLine(card, 0), path: card.key };
    }
    if (link === undefined) {
      this.showPortalToast('暂时无法识别这个会话');
      return;
    }
    this.portalTitle = this.cardLine(card, 0).length > 0 ? this.cardLine(card, 0) : '私信对话';
    this.portalPath = link.path;
    this.portalDocument = undefined;
    await this.loadPortal();
  }

  private queryText(path: string, key: string): string {
    const marker = `${key}=`;
    const offset = path.indexOf(marker);
    if (offset < 0) {
      return '';
    }
    const valueStart = offset + marker.length;
    const valueEnd = path.indexOf('&', valueStart);
    const encoded = path.substring(valueStart, valueEnd >= 0 ? valueEnd : path.length).replace(/\+/g, '%20');
    try {
      return decodeURIComponent(encoded);
    } catch (_) {
      return '';
    }
  }

  private async openNotificationReply(card: PortalCard): Promise<void> {
    const link = this.firstLink(card, '/direct_messages/');
    if (link === undefined) {
      this.showPortalToast('暂时无法识别对应私信');
      return;
    }
    this.directMessageDraft = this.queryText(link.path, 'draft');
    this.portalTitle = this.cardLine(card, 0).length > 0 ? this.cardLine(card, 0) : '私信对话';
    this.portalPath = link.path;
    this.portalDocument = undefined;
    await this.loadPortal();
  }

  private isConversationDetail(): boolean {
    return this.portalPath.startsWith('/direct_messages/') && this.portalPath !== '/direct_messages';
  }

  private async backToConversationList(): Promise<void> {
    this.portalPath = '/direct_messages';
    this.portalTitle = '我的私信';
    this.portalDocument = undefined;
    await this.loadPortal();
  }

  private routeId(path: string, prefix: string): number {
    const marker = path.indexOf(prefix);
    if (marker < 0) {
      return 0;
    }
    let value = 0;
    let found = false;
    for (let index = marker + prefix.length; index < path.length; index++) {
      const ch = path.charAt(index);
      if (ch < '0' || ch > '9') {
        break;
      }
      found = true;
      value = value * 10 + ch.charCodeAt(0) - 48;
    }
    return found ? value : 0;
  }

  private queryNumber(path: string, key: string): number {
    const marker = `${key}=`;
    const offset = path.indexOf(marker);
    if (offset < 0) {
      return 0;
    }
    let value = 0;
    let found = false;
    for (let index = offset + marker.length; index < path.length; index++) {
      const ch = path.charAt(index);
      if (ch < '0' || ch > '9') {
        break;
      }
      found = true;
      value = value * 10 + ch.charCodeAt(0) - 48;
    }
    return found ? value : 0;
  }

  private firstLink(card: PortalCard, prefix: string): PortalLink | undefined {
    for (let index = 0; index < card.links.length; index++) {
      if (card.links[index].path.indexOf(prefix) >= 0) {
        return card.links[index];
      }
    }
    return undefined;
  }

  private cardLine(card: PortalCard, index: number): string {
    return index >= 0 && index < card.lines.length ? card.lines[index] : '';
  }

  private cardUser(card: PortalCard): UserUiModel {
    const output = new UserUiModel();
    const userLink = this.firstLink(card, '/user/');
    output.userId = userLink === undefined ? 0 : this.routeId(userLink.path, '/user/');
    output.displayName = this.cardLine(card, 0).length > 0 ? this.cardLine(card, 0) : '社区用户';
    output.avatarUrl = card.imageUrl ?? '';
    output.initial = output.displayName.substring(0, 1).toUpperCase();
    return output;
  }

  private portalCards(): PortalCard[] {
    const source = this.portalDocument?.cards ?? [];
    if (this.portalPath === '/direct_messages') {
      return source.filter((card: PortalCard) => card.kind === 'conversation');
    }
    if (this.isConversationDetail()) {
      return source.filter((card: PortalCard) => card.kind === 'message' || card.kind === 'message-mine');
    }
    return source;
  }

  private portalActionWithField(fieldName: string): PortalAction | undefined {
    const source = this.portalDocument?.actions ?? [];
    for (let index = 0; index < source.length; index++) {
      const action = source[index];
      if (this.hasField(action, fieldName)) {
        return action;
      }
    }
    return undefined;
  }

  private hasField(action: PortalAction, name: string): boolean {
    for (let index = 0; index < action.fields.length; index++) {
      if (action.fields[index].name === name) {
        return true;
      }
    }
    return false;
  }

  private walletBalance(): string {
    const lines = this.portalDocument?.lines ?? [];
    for (let index = 0; index < Math.min(lines.length, 12); index++) {
      const value = lines[index].trim();
      if (value.length > 0 && Number.isFinite(Number(value))) {
        return value;
      }
    }
    return '0';
  }

  private setActionField(action: PortalAction, name: string, value: string): void {
    for (let index = 0; index < action.fields.length; index++) {
      if (action.fields[index].name === name) {
        action.fields[index].value = value;
        return;
      }
    }
  }

  private showPortalToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (_) {}
  }

  private async redeemWallet(): Promise<void> {
    const action = this.portalActionWithField('code');
    const code = this.walletRedeemCode.trim();
    if (action === undefined || code.length === 0 || this.walletSubmitting) {
      return;
    }
    this.walletSubmitting = true;
    this.setActionField(action, 'code', code);
    const result = await this.onSubmitPortal(action);
    this.walletSubmitting = false;
    this.showPortalToast(result.message);
    if (result.ok) {
      this.walletRedeemCode = '';
      await this.loadPortal();
    }
  }

  private confirmWalletRedeem(): void {
    if (this.walletRedeemCode.trim().length === 0 || this.walletSubmitting) {
      return;
    }
    AlertDialog.show({
      title: '确认兑换',
      message: '兑换码将提交到 linux.sb，兑换成功后立即计入当前账号。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '立即兑换', action: () => { this.redeemWallet(); } }
    });
  }

  private async submitDirectMessage(body: string): Promise<WriteResult> {
    const content = body.trim();
    if (content.length > 500) {
      return { ok: false, topicId: 0, message: '私信最多 500 字', networkMs: 0 };
    }
    const action = this.portalActionWithField('content');
    if (action === undefined) {
      return { ok: false, topicId: 0, message: '当前会话暂时无法发送', networkMs: 0 };
    }
    this.setActionField(action, 'content', content);
    const beforeOccurrences = this.directMessageOccurrences(content);
    const result = await this.onSubmitPortal(action);
    let verifiedOk = result.ok;
    let verifiedMessage = result.message;
    if (result.ok || result.uncertain === true) {
      await this.loadPortal();
      if (!result.ok && result.uncertain === true) {
        verifiedOk = this.directMessageOccurrences(content) > beforeOccurrences;
        verifiedMessage = verifiedOk ? '私信已发送，已同步服务器记录' :
          '网络回执中断，未在对话中确认到本次发送';
      }
    }
    return {
      ok: verifiedOk,
      topicId: 0,
      message: verifiedMessage,
      networkMs: 0,
      authExpired: result.authExpired
    };
  }

  private directMessageOccurrences(content: string): number {
    const cards = this.portalCards();
    let count = 0;
    for (let index = 0; index < cards.length; index++) {
      if (cards[index].kind === 'message-mine' && cards[index].lines.join('\n').indexOf(content) >= 0) {
        count++;
      }
    }
    return count;
  }

  private userUiModel(): UserUiModel {
    const output = new UserUiModel();
    const source = this.user;
    if (source !== undefined) {
      output.userId = source.userId;
      output.displayName = source.name;
      output.avatarUrl = source.avatarUrl;
      output.initial = source.name.length > 0 ? source.name.substring(0, 1).toUpperCase() : '我';
    }
    return output;
  }

  private actionFieldValue(action: PortalAction | undefined, name: string): string {
    if (action === undefined) {
      return '';
    }
    for (let index = 0; index < action.fields.length; index++) {
      if (action.fields[index].name === name) {
        return action.fields[index].value;
      }
    }
    return '';
  }

  private documentValueAfter(document: PortalDocument, label: string, fallback: string = ''): string {
    for (let index = 0; index < document.lines.length - 1; index++) {
      if (document.lines[index] === label) {
        return document.lines[index + 1];
      }
    }
    return fallback;
  }

  private hydrateProfileSettings(document: PortalDocument): void {
    const profileAction = document.actions.find((action: PortalAction) => this.hasField(action, 'bio'));
    this.profileUsernameDraft = this.user?.name ?? this.documentValueAfter(document, '用户名');
    this.profileCurrentPassword = '';
    this.profileBioDraft = this.actionFieldValue(profileAction, 'bio');
    if (this.profileBioDraft.length === 0) {
      this.profileBioDraft = this.user?.bio ?? '';
    }
    this.profilePasswordDraft = '';
    this.profilePasswordConfirm = '';
    const style = this.actionFieldValue(profileAction, 'avatar_style');
    this.profileAvatarStyle = style.length > 0 ? style : 'bottts-neutral';
    this.profileAvatarSeed = this.actionFieldValue(profileAction, 'avatar_seed');
  }

  private profileSaveAction(): PortalAction {
    const parsed = this.portalActionWithField('bio');
    if (parsed !== undefined) {
      return parsed;
    }
    return {
      actionUrl: '/profile', label: '保存', context: '个人资料', disabled: false,
      fields: [
        { name: 'avatar_style', value: this.profileAvatarStyle, type: 'select', placeholder: '', options: [] },
        { name: 'avatar_seed', value: this.profileAvatarSeed, type: 'hidden', placeholder: '', options: [] },
        { name: 'bio', value: this.profileBioDraft, type: 'textarea', placeholder: '', options: [] },
        { name: 'password', value: '', type: 'password', placeholder: '', options: [] },
        { name: 'password2', value: '', type: 'password', placeholder: '', options: [] }
      ]
    };
  }

  private prepareProfileAction(password: string = '', passwordConfirm: string = ''): PortalAction {
    const action = this.profileSaveAction();
    this.setActionField(action, 'avatar_style', this.profileAvatarStyle);
    this.setActionField(action, 'avatar_seed', this.profileAvatarSeed);
    this.setActionField(action, 'bio', this.profileBioDraft.trim());
    this.setActionField(action, 'password', password);
    this.setActionField(action, 'password2', passwordConfirm);
    return action;
  }

  private async submitBioSettings(): Promise<void> {
    if (this.bioSubmitting) {
      return;
    }
    const action = this.prepareProfileAction();
    this.bioSubmitting = true;
    const result = await this.onSubmitPortal(action);
    this.bioSubmitting = false;
    let message = result.message;
    if (result.ok || result.uncertain === true) {
      const expectedBio = this.profileBioDraft.trim();
      await this.loadPortal();
      await this.resolveProfile(true);
      if (!result.ok && result.uncertain === true) {
        message = this.profileBioDraft.trim() === expectedBio ? '资料已保存，已同步服务器状态' :
          '网络回执中断，服务器资料未变化';
      }
    }
    this.showPortalToast(message);
  }

  private async submitPasswordSettings(): Promise<void> {
    if (this.passwordSubmitting) {
      return;
    }
    if (this.profilePasswordDraft.length === 0 || this.profilePasswordConfirm.length === 0) {
      this.showPortalToast('请输入并再次确认新密码');
      return;
    }
    if (this.profilePasswordDraft !== this.profilePasswordConfirm) {
      this.showPortalToast('两次输入的密码不一致');
      return;
    }
    const action = this.prepareProfileAction(this.profilePasswordDraft, this.profilePasswordConfirm);
    this.passwordSubmitting = true;
    const result = await this.onSubmitPortal(action);
    this.passwordSubmitting = false;
    this.showPortalToast(result.message);
    if (result.ok) {
      this.profilePasswordDraft = '';
      this.profilePasswordConfirm = '';
      await this.loadPortal();
      await this.resolveProfile(true);
    }
  }

  private async submitUsername(): Promise<void> {
    const username = this.profileUsernameDraft.trim();
    if (this.usernameSubmitting || username.length === 0 || this.profileCurrentPassword.length === 0) {
      this.showPortalToast('请输入新用户名和当前密码');
      return;
    }
    const action: PortalAction = {
      actionUrl: '/username_change', label: '修改用户名', context: '个人资料', disabled: false,
      fields: [
        { name: 'new_username', value: username, type: 'text', placeholder: '', options: [] },
        { name: 'current_password', value: this.profileCurrentPassword, type: 'password', placeholder: '', options: [] }
      ]
    };
    this.usernameSubmitting = true;
    const result = await this.onSubmitPortal(action);
    this.usernameSubmitting = false;
    let message = result.message;
    if (result.ok || result.uncertain === true) {
      await this.resolveProfile(true);
      await this.loadPortal();
      if (!result.ok && result.uncertain === true) {
        message = this.user?.name === username ? '用户名已修改，已同步服务器状态' :
          '网络回执中断，用户名未变化';
      }
      if (result.ok || this.user?.name === username) {
        this.profileCurrentPassword = '';
      }
    }
    this.showPortalToast(message);
  }

  private async submitPresetAvatar(): Promise<void> {
    if (this.avatarSubmitting || this.profileAvatarSeed.length === 0) {
      return;
    }
    const action: PortalAction = {
      actionUrl: '/avatar_upload', label: '使用预置头像', context: '个人资料', disabled: false,
      fields: [
        { name: 'avatar_upload_action', value: 'preset', type: 'hidden', placeholder: '', options: [] },
        { name: 'avatar_seed', value: this.profileAvatarSeed, type: 'hidden', placeholder: '', options: [] }
      ]
    };
    this.avatarSubmitting = true;
    const result = await this.onSubmitPortal(action);
    this.avatarSubmitting = false;
    this.showPortalToast(result.message);
    if (result.ok) {
      await this.resolveProfile(true);
      await this.loadPortal();
    }
  }

  private confirmPresetAvatar(): void {
    if (this.profileAvatarSeed.length === 0 || this.avatarSubmitting) {
      return;
    }
    AlertDialog.show({
      title: '更换头像',
      message: '使用所选预置头像会真实更新 linux.sb 当前账号头像。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认更换', action: () => { this.submitPresetAvatar(); } }
    });
  }

  private async uploadPickedAvatar(uri: string): Promise<void> {
    if (this.avatarSubmitting) {
      return;
    }
    this.avatarSubmitting = true;
    const result = await this.onUploadAvatar(uri);
    this.avatarSubmitting = false;
    this.showPortalToast(result.message);
    if (result.ok) {
      await this.resolveProfile(true);
      await this.loadPortal();
    }
  }

  private async chooseAvatarImage(): Promise<void> {
    if (this.avatarSubmitting) {
      return;
    }
    const uris = await pickImagesFromGallery(1);
    if (uris.length === 0) {
      return;
    }
    AlertDialog.show({
      title: '上传头像',
      message: '图片将居中裁成正方形并上传到 linux.sb，确认继续吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认上传', action: () => { this.uploadPickedAvatar(uris[0]); } }
    });
  }

  private avatarPresetUrl(seed: string): string {
    // The picker only displays a 48vp circle. Requesting a bounded raster avoids
    // decoding 24 independent remote SVG trees while the parent List is moving.
    return `https://api.dicebear.com/10.x/bottts-neutral/png?seed=${seed}&size=96`;
  }

  private cardAmount(card: PortalCard): string {
    for (let index = 0; index < card.lines.length; index++) {
      const line = card.lines[index].trim();
      if ((line.startsWith('+') || line.startsWith('-')) && Number.isFinite(Number(line))) {
        return line;
      }
    }
    return '';
  }

  private cardPreview(card: PortalCard, start: number = 1): string {
    let output = '';
    for (let index = start; index < card.lines.length; index++) {
      const line = card.lines[index].trim();
      if (line.length === 0 || line === '积分' || line === '购买' || line === '查看主题' ||
        line === '回复TA' || line === this.cardAmount(card)) {
        continue;
      }
      if (output.length > 0) {
        output += ' · ';
      }
      output += line;
      if (output.length >= 100) {
        break;
      }
    }
    return output;
  }

  @Builder
  private featureButton(label: string, icon: Resource, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: Spacing.XS }) {
        SymbolGlyph(icon)
          .fontSize(24)
          .fontWeight(600)
          .fontColor([this.selectedFeature === index ? $r('app.color.brand_primary') :
            SemanticColors.textPrimary()])
        Text(label)
          .fontSize(Typography.LABEL)
          .fontWeight(this.selectedFeature === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedFeature === index ? $r('app.color.brand_primary') : SemanticColors.textPrimary())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .id(`profile-feature-${index}`)
    .layoutWeight(1)
    .height(66)
    .padding(0)
    .backgroundColor(this.selectedFeature === index ? $r('app.color.brand_soft') : SemanticColors.surface())
    .borderRadius(12)
    .onClick(() => this.openFeature(index))
  }

  @Builder
  private featurePanel() {
    Column({ space: Spacing.SM }) {
      Row({ space: Spacing.SM }) {
        this.featureButton('我的主题', $r('sys.symbol.doc_text_fill'), 0)
        this.featureButton('我的回帖', $r('sys.symbol.message_fill'), 1)
        this.featureButton('我的收藏', $r('sys.symbol.bookmark_fill'), 4)
        this.featureButton('我的消息', $r('sys.symbol.bell_fill'), 5)
      }
      .width('100%')
      Row({ space: Spacing.SM }) {
        this.featureButton('我的私信', $r('sys.symbol.envelope_fill'), 2)
        this.featureButton('我的积分', $r('sys.symbol.coins_badge_coin_fill'), 3)
        this.featureButton('我的烧饼', $r('sys.symbol.wallet_fill'), 6)
        this.featureButton('个人设置', $r('sys.symbol.gearshape_fill'), 7)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private titleBar() {
    Row() {
      Text('我的')
        .id('profile-page-title')
        .fontSize(Typography.ROOT_PAGE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
    }
    .width('100%').height('100%')
    .padding({ left: Spacing.MD, right: Spacing.MD })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private profileHeader() {
    if (this.user !== undefined) {
      Column({ space: Spacing.MD }) {
        Row({ space: Spacing.MD }) {
          UserAvatar({ user: this.userUiModel(), avatarSize: 64, semanticId: 'profile-avatar' })
          Column({ space: Spacing.XS }) {
            Text(this.user?.name ?? '')
              .fontSize(Typography.TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.textPrimary())
              .maxLines(1)
            Row({ space: Spacing.MD }) {
              if ((this.user?.groupName ?? '').length > 0) {
                Text(this.user?.groupName ?? '')
                  .fontSize(Typography.LABEL)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SemanticColors.textSecondary())
                  .maxLines(1)
              }
              Text(`积分 ${this.user?.points ?? 0}`)
                .fontSize(Typography.LABEL)
                .fontColor(SemanticColors.textSecondary())
                .maxLines(1)
            }
            .alignItems(VerticalAlign.Center)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        if ((this.user?.bio ?? '').length > 0) {
          Text(this.user?.bio ?? '')
            .fontSize(Typography.BODY)
            .lineHeight(Typography.BODY_LINE_HEIGHT)
            .fontColor(SemanticColors.textSecondary())
            .width('100%')
        }

        this.featurePanel()
      }
      .width('100%')
      .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.LG, bottom: Spacing.SM })
      .backgroundColor(Color.Transparent)
    }
  }

  @Builder
  private profileInfoCard(label: string, value: string, semanticId: string) {
    Column({ space: Spacing.XS }) {
      Text(label)
        .fontSize(Typography.METADATA)
        .fontColor(SemanticColors.textSecondary())
      Text(value.length > 0 ? value : '—')
        .fontSize(Typography.BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .id(semanticId)
    .width('100%')
    .height(68)
    .padding(Spacing.MD)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.settings_group_bg'))
    .borderRadius(12)
  }

  @Builder
  private profileSectionTitle(title: string) {
    Text(title)
      .fontSize(Typography.SECTION_TITLE)
      .fontWeight(FontWeight.Bold)
      .fontColor(SemanticColors.textPrimary())
      .width('100%')
  }

  @Builder
  private profileSettingsContent() {
    List({ space: Spacing.SM }) {
      ListItem() { this.portalTitleRow(false) }
      ListItem() {
        Column({ space: Spacing.SM }) {
          this.profileSectionTitle('个人资料')
          Grid() {
            GridItem() {
              this.profileInfoCard('用户名', this.user?.name ?? '', 'profile-settings-name')
            }
            GridItem() {
              this.profileInfoCard('用户 UID', `${this.user?.userId ?? 0}`, 'profile-settings-uid')
            }
            GridItem() {
              this.profileInfoCard('邮箱',
                this.documentValueAfter(this.portalDocument as PortalDocument, '邮箱'), 'profile-settings-email')
            }
            GridItem() {
              this.profileInfoCard('注册时间',
                this.documentValueAfter(this.portalDocument as PortalDocument, '注册时间'),
                'profile-settings-created')
            }
            GridItem() {
              this.profileInfoCard('积分', `${this.user?.points ?? 0}`, 'profile-settings-points')
            }
            GridItem() {
              this.profileInfoCard('账号安全', '已登录', 'profile-settings-security')
            }
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(Spacing.SM)
          .rowsGap(Spacing.SM)
          .width('100%')
          .height(220)
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG })
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() {
        Column({ space: Spacing.SM }) {
          this.profileSectionTitle('修改用户名')
          TextInput({ text: this.profileUsernameDraft, placeholder: '输入新用户名' })
            .id('profile-settings-username')
            .height(44)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .backgroundColor(SemanticColors.surface())
            .border({ width: 1, color: SemanticColors.outline() })
            .borderRadius(18)
            .onChange((value: string) => { this.profileUsernameDraft = value; })
          TextInput({ text: this.profileCurrentPassword, placeholder: '当前密码' })
            .id('profile-settings-current-password')
            .type(InputType.Password)
            .height(44)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .backgroundColor(SemanticColors.surface())
            .border({ width: 1, color: SemanticColors.outline() })
            .borderRadius(18)
            .onChange((value: string) => { this.profileCurrentPassword = value; })
          Text('当前密码仅用于验证本人，不会修改密码；原站当前规则每次消耗 10 积分。')
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
            .lineHeight(Typography.BODY)
            .width('100%')
          ImmersiveGlassTextButton({
            label: this.usernameSubmitting ? '修改中' : '支付 10 积分修改',
            semanticId: 'profile-settings-submit-username',
            actionEnabled: !this.usernameSubmitting && this.profileUsernameDraft.trim().length > 0 &&
              this.profileCurrentPassword.length > 0,
            controlHeight: 42,
            horizontalPadding: Spacing.LG,
            labelFontSize: Typography.BODY,
            onAction: () => this.submitUsername()
          })
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() {
        Column({ space: Spacing.SM }) {
          this.profileSectionTitle('头像')
          Row({ space: Spacing.MD }) {
            UserAvatar({ user: this.userUiModel(), avatarSize: 64, semanticId: 'profile-settings-avatar' })
            Column({ space: Spacing.XS }) {
              Text('上传图片会居中裁成 200 × 200；也可选择统一预置头像。')
                .fontSize(Typography.METADATA)
                .fontColor(SemanticColors.textSecondary())
                .lineHeight(Typography.CONTENT_TITLE)
              ImmersiveGlassTextButton({
                label: this.avatarSubmitting ? '处理中' : '上传头像',
                semanticId: 'profile-settings-upload-avatar',
                actionEnabled: !this.avatarSubmitting,
                controlHeight: 38,
                horizontalPadding: Spacing.LG,
                labelFontSize: Typography.BODY_SMALL,
                onAction: () => this.chooseAvatarImage()
              })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          List({ space: Spacing.SM }) {
            LazyForEach(this.avatarPresetDataSource, (seed: string) => {
              ListItem() {
                Image(this.avatarPresetUrl(seed))
                  .id(`profile-settings-avatar-seed-${seed}`)
                  .width(48)
                  .height(48)
                  .sourceSize({ width: 48, height: 48 })
                  .syncLoad(false)
                  .borderRadius(24)
                  .objectFit(ImageFit.Cover)
                  .border({ width: this.profileAvatarSeed === seed ? 2 : 0,
                    color: $r('app.color.brand_primary') })
                  .onClick(() => { this.profileAvatarSeed = seed; })
              }
              .width(48)
              .height(48)
            }, (seed: string) => seed)
          }
          .width('100%')
          .height(56)
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
          .cachedCount(2)
          ImmersiveGlassTextButton({
            label: this.avatarSubmitting ? '处理中' : '使用所选预置头像',
            semanticId: 'profile-settings-use-preset-avatar',
            actionEnabled: !this.avatarSubmitting && this.profileAvatarSeed.length > 0,
            controlHeight: 42,
            horizontalPadding: Spacing.LG,
            labelFontSize: Typography.BODY,
            onAction: () => this.confirmPresetAvatar()
          })
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() {
        Column({ space: Spacing.SM }) {
          this.profileSectionTitle('简介')
          TextArea({ text: this.profileBioDraft, placeholder: '介绍一下自己' })
            .id('profile-settings-bio')
            .width('100%')
            .height(112)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .backgroundColor(SemanticColors.surface())
            .border({ width: 1, color: SemanticColors.outline() })
            .borderRadius(12)
            .onChange((value: string) => { this.profileBioDraft = value; })
          ImmersiveGlassTextButton({
            label: this.bioSubmitting ? '保存中' : '保存资料',
            semanticId: 'profile-settings-save-bio',
            actionEnabled: !this.bioSubmitting,
            controlHeight: 44,
            horizontalPadding: Spacing.LG,
            labelFontSize: Typography.BODY,
            onAction: () => this.submitBioSettings()
          })
          this.profileSectionTitle('密码')
          TextInput({ text: this.profilePasswordDraft, placeholder: '新密码（留空则不修改）' })
            .id('profile-settings-password')
            .type(InputType.Password)
            .height(44)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .backgroundColor(SemanticColors.surface())
            .border({ width: 1, color: SemanticColors.outline() })
            .borderRadius(18)
            .onChange((value: string) => { this.profilePasswordDraft = value; })
          TextInput({ text: this.profilePasswordConfirm, placeholder: '再次输入新密码' })
            .id('profile-settings-password-confirm')
            .type(InputType.Password)
            .height(44)
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textPrimary())
            .backgroundColor(SemanticColors.surface())
            .border({ width: 1, color: SemanticColors.outline() })
            .borderRadius(18)
            .onChange((value: string) => { this.profilePasswordConfirm = value; })
          ImmersiveGlassTextButton({
            label: this.passwordSubmitting ? '修改中' : '确认修改',
            semanticId: 'profile-settings-save-password',
            actionEnabled: !this.passwordSubmitting && this.profilePasswordDraft.length > 0 &&
              this.profilePasswordConfirm.length > 0,
            controlHeight: 44,
            horizontalPadding: Spacing.LG,
            labelFontSize: Typography.BODY,
            onAction: () => this.submitPasswordSettings()
          })
        }
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.LG })
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() { Row().height(this.bottomContentInset) }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .cachedCount(2)
  }

  @Builder
  private conversationRow(card: PortalCard, index: number) {
    Row({ space: Spacing.MD }) {
      UserAvatar({ user: this.cardUser(card), avatarSize: 48, semanticId: `profile-dm-avatar-${index}` })
      Column({ space: Spacing.XXS }) {
        Text(this.cardLine(card, 0))
          .fontSize(Typography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(1)
        Text(this.cardPreview(card, 2))
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textTertiary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(this.cardLine(card, 1))
        .fontSize(Typography.CAPTION)
        .fontColor(SemanticColors.textTertiary())
        .alignSelf(ItemAlign.Start)
    }
    .id(`profile-conversation-${index}`)
    .width('100%')
    .height(78)
    .padding({ left: Spacing.LG, right: Spacing.LG })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: SemanticColors.outline() })
    .backgroundColor(Color.Transparent)
    .onClick(() => this.openConversation(card))
  }

  @Builder
  private pointsRow(card: PortalCard, index: number) {
    Row({ space: Spacing.MD }) {
      UserAvatar({ user: this.cardUser(card), avatarSize: 44, semanticId: `profile-points-avatar-${index}` })
      Column({ space: Spacing.XS }) {
        Text(this.cardLine(card, 0))
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.cardPreview(card, 1))
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textTertiary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.cardAmount(card).length > 0) {
        Text(`${this.cardAmount(card)} 积分`)
          .fontSize(Typography.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.cardAmount(card).startsWith('-') ? Color.Red : $r('app.color.brand_primary'))
          .padding({ left: Spacing.SM, right: Spacing.SM, top: Spacing.XS, bottom: Spacing.XS })
          .border({ width: 1, color: this.cardAmount(card).startsWith('-') ? Color.Red :
            $r('app.color.brand_primary') })
          .borderRadius(18)
      }
    }
    .id(`profile-points-${index}`)
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: SemanticColors.outline() })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private notificationRow(card: PortalCard, index: number) {
    Row({ space: Spacing.MD }) {
      UserAvatar({ user: this.cardUser(card), avatarSize: 44, semanticId: `profile-notice-avatar-${index}` })
      Column({ space: Spacing.XS }) {
        Row({ space: Spacing.SM }) {
          Text(this.cardLine(card, 0))
            .fontSize(Typography.LIST_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.textPrimary())
            .maxLines(1)
          Text(this.cardLine(card, 1))
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textTertiary())
          Blank()
          Text(this.cardLine(card, 2))
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textTertiary())
        }
        .width('100%')
        Text(this.cardPreview(card, 3))
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textSecondary())
          .lineHeight(Typography.CONTENT_TITLE)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.firstLink(card, '/topic/') !== undefined) {
          Button('查看原帖', { type: ButtonType.Capsule, stateEffect: true })
            .id(`profile-notice-topic-${index}`)
            .height(32)
            .padding({ left: Spacing.MD, right: Spacing.MD })
            .fontSize(Typography.CAPTION)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.brand_soft'))
            .alignSelf(ItemAlign.Start)
            .onClick(() => {
              const link = this.firstLink(card, '/topic/');
              if (link !== undefined) {
                this.followPortalLink(link);
              }
            })
        }
        if (this.firstLink(card, '/direct_messages/') !== undefined) {
          Button('回复TA', { type: ButtonType.Capsule, stateEffect: true })
            .id(`profile-notice-reply-${index}`)
            .height(32)
            .padding({ left: Spacing.MD, right: Spacing.MD })
            .fontSize(Typography.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.brand_soft'))
            .alignSelf(ItemAlign.Start)
            .onClick(() => this.openNotificationReply(card))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .id(`profile-notification-${index}`)
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
    .alignItems(VerticalAlign.Top)
    .border({ width: { bottom: 1 }, color: SemanticColors.outline() })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private topicRecordRow(card: PortalCard, index: number) {
    Row({ space: Spacing.MD }) {
      UserAvatar({ user: this.cardUser(card), avatarSize: 44, semanticId: `profile-favorite-avatar-${index}` })
      Column({ space: Spacing.XS }) {
        Text(this.firstLink(card, '/topic/')?.label.replace(/\s+/g, ' ') ?? this.cardLine(card, 0))
          .fontSize(Typography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.textPrimary())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.cardPreview(card, 1))
          .fontSize(Typography.METADATA)
          .fontColor(SemanticColors.textTertiary())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(18)
        .fontColor([SemanticColors.textTertiary()])
    }
    .id(`profile-favorite-${index}`)
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: SemanticColors.outline() })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      const link = this.firstLink(card, '/topic/');
      if (link !== undefined) {
        this.followPortalLink(link);
      }
    })
  }

  @Builder
  private messageRow(card: PortalCard, index: number) {
    Row({ space: Spacing.SM }) {
      if (card.kind !== 'message-mine') {
        UserAvatar({ user: this.cardUser(card), avatarSize: 36, semanticId: `profile-message-avatar-${index}` })
      }
      Column({ space: Spacing.XS }) {
        Text(`${this.cardLine(card, 0)} · ${this.cardLine(card, 1)}`)
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textTertiary())
          .maxLines(1)
        if (card.lines.length > 3) {
          Text(this.cardLine(card, 2))
            .fontSize(Typography.CAPTION)
            .fontColor(SemanticColors.textSecondary())
            .lineHeight(Typography.BODY_LINE_HEIGHT)
            .maxLines(4)
            .padding({ left: Spacing.SM })
            .border({ width: { left: 2 }, color: SemanticColors.outline() })
        }
        Text(this.cardLine(card, card.lines.length > 3 ? card.lines.length - 1 : 2))
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textPrimary())
          .lineHeight(Typography.BODY_LINE_HEIGHT)
          .maxLines(12)
      }
      .width('78%')
      .padding({ left: Spacing.MD, right: Spacing.MD, top: Spacing.SM, bottom: Spacing.SM })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(card.kind === 'message-mine' ? $r('app.color.brand_soft') :
        $r('app.color.settings_group_bg'))
      .borderRadius(18)
    }
    .id(`profile-message-${index}`)
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XS, bottom: Spacing.XS })
    .justifyContent(card.kind === 'message-mine' ? FlexAlign.End : FlexAlign.Start)
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private portalCard(card: PortalCard, index: number) {
    if (card.kind === 'conversation') {
      this.conversationRow(card, index)
    } else if (card.kind === 'points-record') {
      this.pointsRow(card, index)
    } else if (card.kind === 'notification-record') {
      this.notificationRow(card, index)
    } else if (card.kind === 'topic-record') {
      this.topicRecordRow(card, index)
    } else if (card.kind === 'message' || card.kind === 'message-mine') {
      this.messageRow(card, index)
    }
  }

  @Builder
  private portalTitleRow(showBack: boolean = false) {
    Row({ space: Spacing.SM }) {
      if (showBack) {
        ImmersiveIconButton({
          icon: $r('sys.symbol.chevron_left'),
          semanticId: 'profile-conversation-back',
          semanticLabel: '返回私信列表',
          buttonSize: TITLE_BAR_BACK_BUTTON_SIZE,
          iconSize: TITLE_BAR_BACK_ICON_SIZE,
          iconWeight: TITLE_BAR_BACK_ICON_WEIGHT,
          iconColor: SemanticColors.textPrimary(),
          onAction: () => this.backToConversationList()
        })
      }
      Text(this.portalTitle)
        .fontSize(Typography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.SM })
    .alignItems(VerticalAlign.Center)
  }

  private walletEmptyMessage(keyword: string, fallback: string): string {
    const cards = this.portalDocument?.cards ?? [];
    for (let cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      for (let lineIndex = 0; lineIndex < cards[cardIndex].lines.length; lineIndex++) {
        const line = cards[cardIndex].lines[lineIndex];
        if (line.indexOf(keyword) >= 0) {
          return line;
        }
      }
    }
    return fallback;
  }

  @Builder
  private walletRecordSection(title: string, message: string, semanticId: string) {
    Column({ space: Spacing.SM }) {
      Text(title)
        .fontSize(Typography.SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.textPrimary())
        .width('100%')
      Text(message)
        .id(semanticId)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textTertiary())
        .width('100%')
    }
    .width('100%')
    .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private walletContent() {
    List() {
      ListItem() { this.portalTitleRow(false) }
      ListItem() {
        Row({ space: Spacing.MD }) {
          Column({ space: Spacing.XS }) {
            Text('当前烧饼').fontSize(Typography.LABEL).fontColor(SemanticColors.textSecondary())
            Text(this.walletBalance()).fontSize(Typography.ROOT_PAGE_TITLE).fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.textPrimary())
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.wallet_fill'))
            .fontSize(28)
            .fontWeight(600)
            .fontColor([$r('app.color.brand_primary')])
        }
        .id('profile-wallet-balance')
        .width('100%')
        .padding(Spacing.LG)
        .backgroundColor($r('app.color.brand_soft'))
        .borderRadius(16)
        .margin({ bottom: Spacing.SM })
      }
      .padding({ left: Spacing.LG, right: Spacing.LG })
      ListItem() {
        Column({ space: Spacing.SM }) {
          Text('兑换码充值')
            .fontSize(Typography.SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.textPrimary())
            .width('100%')
          Row({ space: Spacing.SM }) {
            TextInput({ text: this.walletRedeemCode, placeholder: 'SB-XXXX-XXXX-XXXX-XXXX' })
              .id('profile-wallet-code-input')
              .layoutWeight(1)
              .height(42)
              .fontSize(Typography.BODY)
              .fontColor(SemanticColors.textPrimary())
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: SemanticColors.outline() })
              .borderRadius(18)
              .onChange((value: string) => { this.walletRedeemCode = value; })
            ImmersiveGlassTextButton({
              label: this.walletSubmitting ? '兑换中' : '立即兑换',
              semanticId: 'profile-wallet-redeem',
              actionEnabled: this.walletRedeemCode.trim().length > 0 && !this.walletSubmitting &&
                this.portalActionWithField('code') !== undefined,
              controlHeight: 42,
              horizontalPadding: Spacing.LG,
              labelFontSize: Typography.BODY,
              onAction: () => this.confirmWalletRedeem()
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .id('profile-wallet-redeem-panel')
        .width('100%')
        .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.MD })
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() {
        this.walletRecordSection('收支明细',
          this.walletEmptyMessage('还没有收支记录', '还没有收支记录。'), 'profile-wallet-empty-records')
      }
      ListItem() {
        this.walletRecordSection('充值申请',
          this.walletEmptyMessage('还没有充值申请', '还没有充值申请。'), 'profile-wallet-empty-recharges')
      }
      ListItem() { Row().height(this.bottomContentInset) }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private conversationContent() {
    Column() {
      List() {
        ListItem() { this.portalTitleRow(true) }
        LazyForEach(this.portalCardDataSource, (card: PortalCard, index: number) => {
          ListItem() { this.messageRow(card, index) }
        }, (card: PortalCard, index: number) => `${card.key}-${index}`)
        if (this.portalCards().length === 0) {
          ListItem() {
            Text('还没有私信内容')
              .fontSize(Typography.BODY)
              .fontColor(SemanticColors.textTertiary())
              .width('100%')
              .height(96)
              .textAlign(TextAlign.Center)
          }
        }
        ListItem() { Row().height(Spacing.SM) }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .cachedCount(3)

      CommentInputBar({
        draft: $directMessageDraft,
        authenticated: this.authenticated,
        bottomAvoidance: this.bottomContentInset,
        onLogin: () => this.onLogin(),
        onSubmit: (body: string) => this.submitDirectMessage(body),
        onUploadImage: (uri: string) => this.onUploadImage(uri)
      })
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private genericPortalContent() {
    List() {
      ListItem() { this.portalTitleRow(false) }
      LazyForEach(this.portalCardDataSource, (card: PortalCard, index: number) => {
        ListItem() { this.portalCard(card, index) }
      }, (card: PortalCard, index: number) => `${card.key}-${index}`)
      if (this.portalCards().length === 0) {
        ListItem() {
          Text(this.portalPath.indexOf('favorites') >= 0 ? '暂无收藏' :
            (this.portalPath === '/direct_messages' ? '暂无私信' : '暂无记录'))
            .fontSize(Typography.BODY)
            .fontColor(SemanticColors.textTertiary())
            .width('100%')
            .height(96)
            .textAlign(TextAlign.Center)
        }
      }
      ListItem() { Row().height(this.bottomContentInset) }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .cachedCount(3)
  }

  @Builder
  private portalContent() {
    if (this.portalLoading) {
      Column({ space: Spacing.SM }) {
        LoadingProgress().width(30).height(30).color($r('app.color.brand_primary'))
        Text(`正在读取${this.portalTitle}`)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textSecondary())
      }
      .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      .padding({ bottom: this.bottomContentInset })
    } else if (this.portalError.length > 0 || this.portalDocument === undefined) {
      Column({ space: Spacing.MD }) {
        Text(this.portalError.length > 0 ? this.portalError : '暂无数据')
          .fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
        Button('重试', { type: ButtonType.Capsule }).onClick(() => this.loadPortal())
      }
      .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      .padding({ bottom: this.bottomContentInset })
    } else {
      if (this.isConversationDetail()) {
        this.conversationContent()
      } else if (this.portalPath === '/community_wallet') {
        this.walletContent()
      } else if (this.portalPath === '/profile') {
        this.profileSettingsContent()
      } else {
        this.genericPortalContent()
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      HdsNavigation() {
        Column() {
          if (!this.authenticated) {
            Column() {
              AccountLoginGate({
                title: '登录后查看个人主页',
                semanticPrefix: 'profile',
                onLogin: () => this.onLogin()
              })
              Blank()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.XXL,
              bottom: this.bottomContentInset })
          } else if (this.resolvingProfile && this.user === undefined) {
            Column({ space: Spacing.SM }) {
              LoadingProgress().width(30).height(30).color($r('app.color.brand_primary'))
              Text('正在读取个人主页')
                .fontSize(Typography.BODY)
                .fontColor(SemanticColors.textSecondary())
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
            .padding({ bottom: this.bottomContentInset })
          } else if (this.profileError.length > 0) {
            Column({ space: Spacing.MD }) {
              Text(this.profileError).fontSize(Typography.BODY).fontColor(SemanticColors.textSecondary())
              Button('重试', { type: ButtonType.Capsule }).onClick(() => this.resolveProfile(true))
            }
            .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
            .padding({ bottom: this.bottomContentInset })
          } else {
            this.profileHeader()
            if (this.portalPath.length > 0) {
              this.portalContent()
            } else {
              Text(this.selectedTab === ProfileTab.Replies ? '我的回帖' : '我的主题')
                .id('profile-topic-section-title')
                .fontSize(Typography.TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(SemanticColors.textPrimary())
                .width('100%')
                .padding({ left: Spacing.LG, right: Spacing.LG, top: Spacing.MD, bottom: Spacing.XS })
              PaginatedTopicList({
                viewModel: this.profileViewModel,
                bottomInset: this.bottomContentInset,
                semanticPrefix: 'profile',
                emptyTitle: this.selectedTab === ProfileTab.Replies ? '还没有回帖' : '还没有主题',
                avatarSizeOverride: 40,
                metadataGapOverride: Spacing.XS,
                onTopicSelected: (topic: TopicUiModel) => this.onTopicSelected(topic),
                onRetry: () => this.resolveProfile(true)
              })
                .layoutWeight(1)
            }
          }
        }
        .id('profile-page')
        .width('100%').height('100%')
        .backgroundColor(SemanticColors.page())
      }
      .titleBar({
        avoidLayoutSafeArea: requiresHdsLayoutSafeAreaAvoidance(ImmersiveLightArea.TITLE_BAR),
        enableComponentSafeArea: requiresHdsComponentSafeArea(ImmersiveLightArea.TITLE_BAR),
        style: buildImmersiveTitleBarStyle(),
        content: { stackBuilder: () => { this.titleBar(); } }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%').height('100%')

    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.page())
  }
}
