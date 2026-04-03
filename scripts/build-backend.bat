@echo off
REM CLバックエンドをWindowsの実行ファイルとしてビルドする
REM 前提: SBCLとQuicklispがインストールされていること

echo [build-backend] Building Common Lisp backend...

REM 出力ディレクトリを作成
if not exist ..\dist-cl mkdir ..\dist-cl

cd ..

REM SBCLでビルドスクリプトを実行
sbcl --script build.lisp

if %errorlevel% neq 0 (
  echo [build-backend] Build failed!
  exit /b 1
)

echo [build-backend] Build succeeded: dist-cl\booth-backend.exe
