/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Moved from common/mediacommon/src/main/ets/utils/BackgroundUtil.ets
 */

import { wantAgent, common } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from 'musicbasic';

/** Wraps BackgroundTasksKit audio background running start/stop for playback in background. */
export class BackgroundUtil {
  /**
   * Requests continuous audio background running with a WantAgent back to this ability.
   *
   * @param context UIAbility context; no-op when undefined.
   */
  public static startContinuousTask(context?: common.UIAbilityContext): void {
    if (!context) {
      Logger.error('this avPlayer: ', `context undefined`);
      return;
    }
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
      try {
        if (canIUse('SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask')) {
          backgroundTaskManager.startBackgroundRunning(context,
            backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
            Logger.info('this avPlayer: ', 'startBackgroundRunning succeeded');
          }).catch((error: BusinessError) => {
            Logger.error('this avPlayer: ', `startBackgroundRunning failed Cause: code ${error.code}`);
          });
        }
      } catch (error) {
        Logger.error('this avPlayer: ',
          `startBackgroundRunning failed. code ${(error as BusinessError).code} ` +
          `message ${(error as BusinessError).message}`);
      }
    }).catch((err: BusinessError) => {
      Logger.error(`getWantAgent failed, code: ${JSON.stringify(err.code)}, message: ${JSON.stringify(err.message)}`);
    })
  }

  /**
   * Stops continuous background running when the capability is available on device.
   *
   * @param context UIAbility context that started background running.
   */
  public static stopContinuousTask(context: common.UIAbilityContext): void {
    if (canIUse('SystemCapability.ResourceSchedule.BackgroundTaskManager.Core')) {
      try {
        backgroundTaskManager.stopBackgroundRunning(context).then(() => {
          Logger.info('this avPlayer: ', 'stopBackgroundRunning succeeded');
        }).catch((error: BusinessError) => {
          Logger.error('this avPlayer: ', `stopBackgroundRunning failed Cause: code ${error.code}`);
        });
      } catch (error) {
        Logger.error('this avPlayer: ',
          `stopBackgroundRunning failed. code ${(error as BusinessError).code} ` +
          `message ${(error as BusinessError).message}`);
      }
    }
  }
}

