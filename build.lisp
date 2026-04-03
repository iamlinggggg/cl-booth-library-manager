;;; CLバックエンドをスタンドアロン実行ファイルとしてビルドするスクリプト
;;; 使い方: sbcl --script build.lisp

(load (merge-pathnames "setup.lisp"
                       (merge-pathnames "quicklisp/"
                                        (user-homedir-pathname))))

(ql:quickload :cl-booth-order-manager :silent t)

(let ((out-dir (merge-pathnames "dist-cl/" *default-pathname-defaults*)))
  (ensure-directories-exist out-dir)
  (sb-ext:save-lisp-and-die
   (merge-pathnames "booth-backend.exe" out-dir)
   :toplevel #'cl-booth-order-manager:main
   :executable t
   :compression t))  ; SBCLビルドオプションでcore compressionを有効化
