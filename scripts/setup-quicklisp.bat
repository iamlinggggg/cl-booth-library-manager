@echo off
REM Quicklispとプロジェクト依存関係をセットアップする
REM 初回セットアップ時に実行する

echo [setup] Installing project dependencies via Quicklisp...

sbcl --eval "(load (merge-pathnames \"quicklisp/setup.lisp\" (user-homedir-pathname)))" ^
     --eval "(push #p\"%cd%/\" ql:*local-project-directories*)" ^
     --eval "(ql:quickload :cl-booth-library-manager)" ^
     --eval "(quit)"

if %errorlevel% neq 0 (
  echo [setup] Failed! Make sure SBCL and Quicklisp are installed.
  echo   SBCL: https://www.sbcl.org/
  echo   Quicklisp: https://www.quicklisp.org/
  exit /b 1
)

echo [setup] Done!
