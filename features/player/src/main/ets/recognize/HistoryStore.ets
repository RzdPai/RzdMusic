import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { RecognitionResult } from './RecognitionTypes';

const STORE_NAME = 'musicRecognition';
const HISTORY_KEY = 'history';
const MAX_HISTORY = 50;

export class HistoryStore {
  private static store: preferences.Preferences | undefined = undefined;

  static init(context: common.UIAbilityContext): void {
    try {
      if (HistoryStore.store === undefined) {
        HistoryStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      }
    } catch (err) {
    }
  }

  static load(): Array<RecognitionResult> {
    const store = HistoryStore.store;
    if (store === undefined) {
      return [];
    }
    let raw: preferences.ValueType;
    try {
      raw = store.getSync(HISTORY_KEY, '[]');
    } catch (err) {
      return [];
    }
    const list: Array<RecognitionResult> = [];
    try {
      const text: string = raw as string;
      const parsed: Array<Object> = JSON.parse(text) as Array<Object>;
      for (const item of parsed) {
        list.push(RecognitionResult.fromRecord(item as Record<string, Object>));
      }
    } catch (err) {
      return [];
    }
    return list;
  }

  static async add(result: RecognitionResult): Promise<void> {
    const store = HistoryStore.store;
    if (store === undefined) {
      return;
    }
    const list: Array<RecognitionResult> = HistoryStore.load();
    list.unshift(result);
    while (list.length > MAX_HISTORY) {
      list.pop();
    }
    await HistoryStore.save(list);
  }

  static async remove(id: string): Promise<Array<RecognitionResult>> {
    const list: Array<RecognitionResult> = HistoryStore.load().filter((item: RecognitionResult): boolean => item.id !== id);
    await HistoryStore.save(list);
    return list;
  }

  static async clear(): Promise<void> {
    await HistoryStore.save([]);
  }

  private static async save(list: Array<RecognitionResult>): Promise<void> {
    const store = HistoryStore.store;
    if (store === undefined) {
      return;
    }
    const records: Array<Record<string, Object>> = [];
    for (const item of list) {
      records.push(item.toRecord());
    }
    try {
      store.putSync(HISTORY_KEY, JSON.stringify(records));
      await store.flush();
    } catch (err) {
    }
  }
}
