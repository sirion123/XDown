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

import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeControl, window } from '@kit.ArkUI';
import { DownloadService } from '../services/DownloadService';
import { MediaSaveService } from '../services/MediaSaveService';
import { ResolveService } from '../services/ResolveService';
import { CookieService } from '../services/CookieService';
import { HistoryRepository } from '../storage/HistoryRepository';
import { SettingsRepository } from '../storage/SettingsRepository';
import { ShareIntentService } from '../services/ShareIntentService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'XDown', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onCreate');

    // 覆盖系统默认品牌色（默认蓝色），让 Button/Toggle 等系统控件跟随应用的
    // 鸢尾紫主色，而不是继续使用系统推荐色。
    try {
      ThemeControl.setDefaultTheme({
        colors: {
          brand: '#FF5B4BE0',
          primary: '#FF5B4BE0',
          onPrimary: '#FFFFFFFF',
          confirm: '#FF3F8F6B'
        },
        darkColors: {
          brand: '#FFA99BFF',
          primary: '#FFA99BFF',
          onPrimary: '#FF0B0A10',
          confirm: '#FF5FD0A0'
        }
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'XDown', 'setDefaultTheme failed: %{public}s', JSON.stringify(err));
    }

    // 初始化下载服务和媒体保存服务，存入 AppStorage 供页面使用
    const downloadService = new DownloadService();
    downloadService.setContext(this.context);
    AppStorage.setOrCreate<DownloadService>('downloadService', downloadService);

    const mediaSaveService = new MediaSaveService();
    mediaSaveService.setContext(this.context);
    AppStorage.setOrCreate<MediaSaveService>('mediaSaveService', mediaSaveService);

    // 初始化 CookieService（用于平台登录 cookie 管理）
    // 必须先于 ResolveService 创建，否则 ResolveService 会拿到一个空的 CookieService 实例
    const cookieService = new CookieService();
    cookieService.init(this.context);
    AppStorage.setOrCreate<CookieService>('cookieService', cookieService);

    // 初始化解析服务（路线 B：纯本地 Provider，无后端依赖）
    const resolveService = new ResolveService();
    AppStorage.setOrCreate<ResolveService>('resolveService', resolveService);

    // 初始化 HistoryRepository（持久化存储）
    const historyRepository = new HistoryRepository();
    historyRepository.init(this.context);
    AppStorage.setOrCreate<HistoryRepository>('historyRepository', historyRepository);

    // 初始化 SettingsRepository（持久化存储）
    const settingsRepository = new SettingsRepository();
    settingsRepository.init(this.context);
    AppStorage.setOrCreate<SettingsRepository>('settingsRepository', settingsRepository);

    // 处理通过分享启动的情况
    if (ShareIntentService.isShareIntent(want)) {
      const sharedUrl: string | null = ShareIntentService.extractUrlFromShare(want);
      if (sharedUrl) {
        hilog.info(DOMAIN, 'XDown', 'Received share URL');
        AppStorage.setOrCreate<string>('shareUrl', sharedUrl);
      } else {
        // URL 提取失败时回退到原始文本
        const sharedText: string | null = ShareIntentService.extractSharedText(want);
        if (sharedText) {
          hilog.info(DOMAIN, 'XDown', 'Received share text (URL not extracted)');
          AppStorage.setOrCreate<string>('shareText', sharedText);
        }
      }
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onNewWant');

    // 处理通过分享再次进入的情况
    if (ShareIntentService.isShareIntent(want)) {
      const sharedUrl: string | null = ShareIntentService.extractUrlFromShare(want);
      if (sharedUrl) {
        hilog.info(DOMAIN, 'XDown', 'Received new share URL');
        AppStorage.setOrCreate<string>('shareUrl', sharedUrl);
      } else {
        const sharedText: string | null = ShareIntentService.extractSharedText(want);
        if (sharedText) {
          hilog.info(DOMAIN, 'XDown', 'Received new share text (URL not extracted)');
          AppStorage.setOrCreate<string>('shareText', sharedText);
        }
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'XDown', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'XDown', 'Succeeded in loading the content.');
      this.applyImmersiveWindow(windowStage);
    });
  }

  /**
   * 全屏沉浸：内容铺到状态栏与系统手势区下方，系统条本身透明。
   * 页面内容再按状态栏高度自行留出顶部安全距离。
   */
  private applyImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync();
      this.mainWindow = win;
      win.setWindowLayoutFullScreen(true).then(() => {
        this.updateSystemBarProperties();
      }).catch((err: Error) => {
        hilog.warn(DOMAIN, 'XDown', 'setWindowLayoutFullScreen failed: %{public}s', err.message);
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'XDown', 'getMainWindowSync failed: %{public}s', JSON.stringify(err));
    }
  }

  private updateSystemBarProperties(): void {
    if (!this.mainWindow) {
      return;
    }
    const isDark: boolean =
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000',
      navigationBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000'
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'XDown', 'setWindowSystemBarProperties failed: %{public}s', err.message);
    });
  }

  onConfigurationUpdate(config: Configuration): void {
    hilog.info(DOMAIN, 'XDown', 'onConfigurationUpdate');
    this.updateSystemBarProperties();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'XDown', '%{public}s', 'Ability onBackground');
  }
}