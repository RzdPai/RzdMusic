import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MusicStoreService, PlayedSongRecord } from 'musicbasic';
import { CardImageHelper } from './CardImageHelper';

export default class MusicCardAbility extends FormExtensionAbility {
  private static pushSeq: number = 0;

  onCreate(): void {
    MusicStoreService.getInstance().attachContext(this.context);
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const params: Record<string, Object> | undefined = want.parameters;
    const formId: string = params === undefined ? '' :
      (params[formInfo.FormParam.IDENTITY_KEY] as string ?? '');
    const dimension: number = params === undefined ? formInfo.FormDimension.Dimension_2_4 :
      (params[formInfo.FormParam.DIMENSION_KEY] as number ?? formInfo.FormDimension.Dimension_2_4);
    if (formId.length > 0) {
      MusicStoreService.getInstance().addCardFormId(formId);
      setTimeout((): void => {
        this.pushData(formId, dimension);
      }, 0);
    }
    return formBindingData.createFormBindingData(MusicCardAbility.buildCardData(dimension, formId));
  }

  onUpdateForm(formId: string): void {
    MusicStoreService.getInstance().refreshStoreCache(this.context);
    this.pushData(formId, 0);
  }

  onFormEvent(formId: string, message: string): void {
    MusicStoreService.getInstance().refreshStoreCache(this.context);
    setTimeout((): void => {
      this.pushData(formId, 0);
    }, 300);
  }

  onRemoveForm(formId: string): void {
    MusicStoreService.getInstance().removeCardFormId(formId);
  }

  private static buildCardData(dimension: number, formId: string): Record<string, Object> {
    const store: MusicStoreService = MusicStoreService.getInstance();
    const record: PlayedSongRecord | undefined = store.getLastRecord();
    const data: Record<string, Object> = {};
    data['title'] = record !== undefined && record.name.length > 0 ? record.name : '暂无播放';
    data['singer'] = record !== undefined ? record.singer : '';
    data['playing'] = store.getCardPlaying();
    data['lyric'] = store.getCardLyric();
    if (dimension > 0) {
      data['dimension'] = dimension;
    }
    data['formId'] = formId;
    return data;
  }

  private async pushData(formId: string, dimension: number): Promise<void> {
    const payload: Record<string, Object> = MusicCardAbility.buildCardData(dimension, formId);
    const record: PlayedSongRecord | undefined = MusicStoreService.getInstance().getLastRecord();
    const cover: string = record === undefined ? '' : record.img;
    if (cover.length > 0) {
      MusicCardAbility.pushSeq++;
      const imageName: string = 'cover' + MusicCardAbility.pushSeq + '_' + Date.now();
      const fd: number = await CardImageHelper.prepareCover(this.context.tempDir, cover, imageName);
      if (fd >= 0) {
        const formImages: Record<string, number> = {};
        formImages[imageName] = fd;
        payload['imgName'] = imageName;
        payload['formImages'] = formImages;
      }
    }
    try {
      const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(payload);
      await formProvider.updateForm(formId, data);
    } catch (_err) {
    }
  }
}
