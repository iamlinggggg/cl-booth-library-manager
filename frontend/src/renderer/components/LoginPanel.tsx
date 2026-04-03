import React, { useState } from 'react';

interface Props {
  isLoggedIn: boolean;
  onLoginSuccess: () => void;
  onLogout: () => void;
}

export const LoginPanel: React.FC<Props> = ({ isLoggedIn, onLoginSuccess, onLogout }) => {
  const [loading, setLoading] = useState(false);
  const [logoutLoading, setLogoutLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await window.electronAPI.openLoginWindow();
      if (result.ok) {
        onLoginSuccess();
      } else {
        setError(result.error ?? 'ログインに失敗しました');
      }
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  if (isLoggedIn) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-green-400 text-sm">● ログイン済み</span>
        <button
          onClick={async () => {
            setLogoutLoading(true);
            try {
              await onLogout();
            } finally {
              setLogoutLoading(false);
            }
          }}
          disabled={logoutLoading}
          className="text-xs text-gray-400 hover:text-red-400 disabled:opacity-50 transition-colors underline cursor-pointer"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          {logoutLoading ? '処理中...' : 'ログアウト'}
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center py-16 px-8 text-center">
      <div className="w-16 h-16 rounded-full bg-booth-pink/20 flex items-center justify-center mb-6">
        <svg className="w-8 h-8 text-booth-pink" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
        </svg>
      </div>

      <h2 className="text-xl font-bold text-white mb-2">BOOTHにログイン</h2>
      <p className="text-gray-400 text-sm mb-6 max-w-sm">
        ライブラリを自動取得するには、BOOTHアカウントでログインしてください。
        ログイン情報はこのデバイスのみに保存されます。
      </p>

      {error && (
        <p className="text-red-400 text-sm mb-4">{error}</p>
      )}

      <button
        onClick={handleLogin}
        disabled={loading}
        className="px-6 py-3 bg-booth-pink hover:bg-booth-pink/80 disabled:opacity-50
                   text-white rounded-lg font-medium transition-colors mb-4"
      >
        {loading ? 'ログイン中...' : 'ブラウザでログイン'}
      </button>

      <p className="text-gray-500 text-xs">
        ログインせずに手動で商品を登録することもできます
      </p>
    </div>
  );
};
