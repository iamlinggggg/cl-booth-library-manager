import { contextBridge, ipcRenderer } from 'electron';

// レンダラープロセスに安全なAPIを公開
contextBridge.exposeInMainWorld('electronAPI', {
  // バックエンドのポート番号を取得
  getClPort: (): Promise<number | null> =>
    ipcRenderer.invoke('get-cl-port'),

  // BOOTHログインウィンドウを開く
  openLoginWindow: (): Promise<{ ok: boolean; error?: string }> =>
    ipcRenderer.invoke('open-login-window'),

  // 外部URLをデフォルトブラウザで開く
  openExternal: (url: string): Promise<void> =>
    ipcRenderer.invoke('open-external', url),

  // ログイン成功イベントのリスナー
  onLoginSuccess: (callback: () => void) => {
    ipcRenderer.on('login-success', callback);
    // クリーンアップ関数を返す
    return () => ipcRenderer.removeListener('login-success', callback);
  },
});
