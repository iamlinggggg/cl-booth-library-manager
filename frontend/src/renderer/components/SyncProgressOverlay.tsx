import React from 'react';
import { SyncProgress } from '../types';

interface Props {
  progress: SyncProgress | null;
}

const SECTION_LABEL: Record<string, string> = {
  library: 'ライブラリ',
  gifts:   'ギフト',
};

export const SyncProgressOverlay: React.FC<Props> = ({ progress }) => {
  const section = progress ? (SECTION_LABEL[progress.section] ?? progress.section) : 'ライブラリ';
  const page = progress?.page ?? 1;
  const items = progress?.itemsFetched ?? 0;

  return (
    <div className="flex-1 flex flex-col items-center justify-center gap-6">
      {/* スピナー */}
      <div className="relative w-16 h-16">
        <div className="absolute inset-0 rounded-full border-4 border-gray-700" />
        <div className="absolute inset-0 rounded-full border-4 border-booth-pink border-t-transparent animate-spin" />
      </div>

      {/* メッセージ */}
      <div className="text-center space-y-2">
        <p className="text-white font-medium">BOOTHライブラリを同期中...</p>
        <p className="text-gray-400 text-sm">
          {section} &nbsp;·&nbsp; {page} ページ目
        </p>
        {items > 0 && (
          <p className="text-booth-pink text-sm font-medium">
            {items} 件取得済み
          </p>
        )}
      </div>

      <p className="text-gray-600 text-xs">
        ページ数に応じて数分かかる場合があります
      </p>
    </div>
  );
};
