import { Radius, SemanticColors, Spacing, Typography } from '../../common/theme/DesignSystem';
import { PortalAction, PortalField } from '../../models/PortalModels';
import { ImmersiveGlassTextButton } from './ImmersiveGlassTextButton';

@Component
export struct PortalActionCard {
  action: PortalAction = { actionUrl: '', label: '', context: '', disabled: true, fields: [] };
  semanticPrefix: string = 'portal-action';
  onAction: (action: PortalAction) => void = () => {};
  @State private selectionRevision: number = 0;

  private editableFields(): PortalField[] {
    return this.action.fields.filter((field: PortalField) => field.type !== 'hidden');
  }

  private selectedOptionLabel(field: PortalField): string {
    for (let index = 0; index < field.options.length; index++) {
      if (field.options[index].value === field.value) {
        return field.options[index].label;
      }
    }
    return field.placeholder.length > 0 ? field.placeholder : '请选择';
  }

  private readyToSubmit(): boolean {
    const fields = this.editableFields();
    let checkboxCount = 0;
    let selectedQuantity = 0;
    for (let index = 0; index < fields.length; index++) {
      if (fields[index].type === 'checkbox') {
        checkboxCount++;
        if (fields[index].value.length > 0) {
          selectedQuantity += Number(fields[index].options[0]?.label ?? '1');
        }
      } else if (fields[index].value.trim().length === 0) {
        return false;
      }
    }
    if (checkboxCount > 0 && selectedQuantity <= 0) {
      return false;
    }
    if (this.action.actionUrl === '/gacha_forge') {
      const cost = this.hiddenNumber('_client_forge_cost', 1);
      return selectedQuantity >= cost;
    }
    return true;
  }

  private hiddenNumber(name: string, fallback: number): number {
    for (let index = 0; index < this.action.fields.length; index++) {
      if (this.action.fields[index].name === name) {
        const parsed = Number(this.action.fields[index].value);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
      }
    }
    return fallback;
  }

  private prepareAction(): void {
    if (this.action.actionUrl !== '/gacha_forge') {
      return;
    }
    let selectedQuantity = 0;
    for (let index = 0; index < this.action.fields.length; index++) {
      const field = this.action.fields[index];
      if (field.type === 'checkbox' && field.value.length > 0) {
        selectedQuantity += Number(field.options[0]?.label ?? '1');
      }
    }
    const forgeCount = Math.floor(selectedQuantity / this.hiddenNumber('_client_forge_cost', 1));
    for (let index = 0; index < this.action.fields.length; index++) {
      if (this.action.fields[index].name === 'forge_count') {
        this.action.fields[index].value = forgeCount.toString();
      }
    }
  }

  private submit(): void {
    this.prepareAction();
    this.onAction(this.action);
  }

  private chooseOption(field: PortalField): void {
    const sheets: SheetInfo[] = [];
    for (let index = 0; index < field.options.length; index++) {
      const option = field.options[index];
      sheets.push({
        title: option.label,
        action: () => {
          field.value = option.value;
          this.selectionRevision++;
        }
      });
    }
    ActionSheet.show({
      title: field.placeholder.length > 0 ? field.placeholder : '请选择',
      message: '选择后再确认提交',
      sheets: sheets
    });
  }

  @Builder
  private fieldEditor(field: PortalField, index: number) {
    if (field.type === 'checkbox') {
      Row({ space: Spacing.SM }) {
        Toggle({ type: ToggleType.Checkbox, isOn: field.value.length > 0 })
          .selectedColor($r('app.color.brand_primary'))
          .onChange((selected: boolean) => {
            field.value = selected ? (field.options[0]?.value ?? '') : '';
            this.selectionRevision++;
          })
        Text(field.placeholder)
          .fontSize(Typography.BODY)
          .fontColor(SemanticColors.textPrimary())
          .layoutWeight(1)
      }
      .width('100%')
      .height(42)
    } else if (field.type === 'select') {
      Button(this.selectedOptionLabel(field), { type: ButtonType.Capsule, stateEffect: true })
        .id(`${this.semanticPrefix}-field-${index}`)
        .width('100%')
        .height(40)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textPrimary())
        .backgroundColor(SemanticColors.surface())
        .border({ width: 1, color: SemanticColors.outline() })
        .onClick(() => this.chooseOption(field))
    } else if (field.type === 'textarea') {
      TextArea({ text: field.value, placeholder: field.placeholder.length > 0 ? field.placeholder : field.name })
        .id(`${this.semanticPrefix}-field-${index}`)
        .width('100%')
        .height(96)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textPrimary())
        .backgroundColor(SemanticColors.surface())
        .border({ width: 1, color: SemanticColors.outline() })
        .borderRadius(Radius.MD)
        .onChange((value: string) => { field.value = value; })
    } else {
      TextInput({ text: field.value, placeholder: field.placeholder.length > 0 ? field.placeholder : field.name })
        .id(`${this.semanticPrefix}-field-${index}`)
        .width('100%')
        .height(40)
        .fontSize(Typography.BODY)
        .fontColor(SemanticColors.textPrimary())
        .backgroundColor(SemanticColors.surface())
        .border({ width: 1, color: SemanticColors.outline() })
        .borderRadius(Radius.MD)
        .type(field.type === 'number' ? InputType.Number : InputType.Normal)
        .onChange((value: string) => { field.value = value; })
    }
  }

  build() {
    Column({ space: Spacing.SM }) {
      if (this.action.context.length > 0) {
        Text(this.action.context)
          .fontSize(Typography.CAPTION)
          .fontColor(SemanticColors.textSecondary())
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      ForEach(this.editableFields(), (field: PortalField, index: number) => {
        this.fieldEditor(field, index)
      }, (field: PortalField, index: number) => `${field.name}-${index}-${this.selectionRevision}`)
      ImmersiveGlassTextButton({
        label: this.action.label,
        semanticId: `${this.semanticPrefix}-submit`,
        actionEnabled: !this.action.disabled && this.readyToSubmit(),
        controlHeight: 40,
        horizontalPadding: Spacing.LG,
        labelFontSize: Typography.BODY,
        onAction: () => this.submit()
      })
    }
    .width('100%')
    .padding(Spacing.SM)
    .backgroundColor($r('app.color.settings_group_bg'))
    .borderRadius(Radius.LG)
  }
}
