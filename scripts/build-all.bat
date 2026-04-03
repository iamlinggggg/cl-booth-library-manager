@echo off
REM 全体ビルドスクリプト (CLバックエンド + Electron フロントエンド)

echo === BOOTH Library Manager Full Build ===

REM 1. CLバックエンドのビルド
echo.
echo [1/3] Building Common Lisp backend...
call scripts\build-backend.bat
if %errorlevel% neq 0 exit /b 1

REM 2. フロントエンドの依存関係インストール
echo.
echo [2/3] Installing frontend dependencies...
cd frontend
call npm install
if %errorlevel% neq 0 (
  echo [build-all] npm install failed!
  exit /b 1
)

REM 3. Electronアプリのビルドと.exe生成
echo.
echo [3/3] Building Electron app...
call npm run dist:win
if %errorlevel% neq 0 (
  echo [build-all] Electron build failed!
  exit /b 1
)

cd ..
echo.
echo === Build Complete ===
echo Output: frontend\release\
