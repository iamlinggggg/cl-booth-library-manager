import React from 'react';
import { SyncStatus } from '../types';

interface Props {
  status: SyncStatus | null;
  error: string | null;
}

function formatRelativeTime(unixTs: number): string {
  if (!unixTs) return '未実行';
  const diff = Math.floor(Date.now() / 1000) - unixTs;
  if (diff < 60) return `${diff}秒前`;
  if (diff < 3600) return `${Math.floor(diff / 60)}分前`;
  return `${Math.floor(diff / 3600)}時間前`;
}

function formatCountdown(seconds: number): string {
  if (seconds <= 0) return '間もなく';
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return m > 0 ? `${m}分${s}秒後` : `${s}秒後`;
}

export const StatusBar: React.FC<Props> = ({ status, error }) => {
  if (error) {
    return (
      <div className="h-8 bg-red-900/50 border-t border-red-700 flex items-center px-4">
        <span className="text-red-300 text-xs">{error}</span>
      </div>
    );
  }

  if (!status) {
    return (
      <div className="h-8 bg-gray-900 border-t border-gray-700 flex items-center px-4">
        <span className="text-gray-500 text-xs">接続中...</span>
      </div>
    );
  }

  return (
    <div className="h-8 bg-gray-900 border-t border-gray-700 flex items-center px-4">
      <div className="flex items-center gap-4">
        {/* 同期ステータスインジケーター */}
        <div className="flex items-center gap-1.5">
          {status.isSyncing === true ? (
            <>
              <span className="w-2 h-2 rounded-full bg-yellow-400 animate-pulse" />
              <span className="text-yellow-400 text-xs">同期中...</span>
            </>
          ) : status.isLoggedIn === true ? (
            <>
              <span className="w-2 h-2 rounded-full bg-green-400" />
              <span className="text-green-400 text-xs">ログイン済み</span>
            </>
          ) : (
            <>
              <span className="w-2 h-2 rounded-full bg-gray-500" />
              <span className="text-gray-400 text-xs">未ログイン</span>
            </>
          )}
        </div>

        {/* 最終同期時刻 */}
        <span className="text-gray-500 text-xs">
          最終取得: {formatRelativeTime(status.lastSyncedAt)}
        </span>

        {/* 次回同期まで */}
        {status.isLoggedIn === true && status.isSyncing !== true && (
          <span className="text-gray-500 text-xs">
            次回: {formatCountdown(status.secondsUntilNext)}
          </span>
        )}
      </div>
    </div>
  );
};