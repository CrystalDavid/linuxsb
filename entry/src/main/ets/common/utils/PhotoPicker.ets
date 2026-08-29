import { photoAccessHelper } from '@kit.MediaLibraryKit';

export const MAX_IMAGE_PICK_COUNT: number = 9;

export async function pickImagesFromGallery(maxSelectNumber: number = MAX_IMAGE_PICK_COUNT): Promise<string[]> {
  if (maxSelectNumber <= 0) {
    return [];
  }
  try {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maxSelectNumber;
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select(options);
    return result.photoUris.slice(0, maxSelectNumber);
  } catch (_) {
    return [];
  }
}
