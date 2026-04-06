(in-package :cl-booth-library-manager)

;;; ---------------------------------------------------------------------------
;;; Entry point
;;; ---------------------------------------------------------------------------

(defun setup-signal-handlers ()
  "終了シグナルに対してクリーンアップを登録する (Unix/Linux環境のみ)"
  #+(and sbcl (not win32))
  (progn
    (sb-sys:enable-interrupt
     sb-unix:sigterm
     (lambda (sig code scp)
       (declare (ignore sig code scp))
       (shutdown 0)))
    (sb-sys:enable-interrupt
     sb-unix:sigint
     (lambda (sig code scp)
       (declare (ignore sig code scp))
       (shutdown 0)))))

(defun shutdown (exit-code)
  "サーバーとスケジューラーを停止してプロセスを終了する"
  (format t "[main] Shutting down...~%")
  (handler-case (cl-booth-library-manager.scheduler:stop) (error ()))
  (handler-case (cl-booth-library-manager.api:stop-server) (error ()))
  (handler-case (cl-booth-library-manager.db:close-db) (error ()))
  (uiop:quit exit-code))

(defun get-port ()
  "使用するポートを決定する (環境変数 BOOTH_PORT または デフォルト)"
  (or (let ((env (uiop:getenv "BOOTH_PORT")))
        (when env (parse-integer env :junk-allowed t)))
      cl-booth-library-manager.api:*port*))

(defun main ()
  (format t "=== BOOTH Order Manager v0.2.0 ===~%")

  ;; シグナルハンドラー設定 (対応OSのみ)
  (setup-signal-handlers)

  ;; DB初期化
  (format t "[main] Initializing database...~%")
  (handler-case
      (cl-booth-library-manager.db:init-db)
    (error (c)
      (format *error-output* "[main] DB init failed: ~A~%" c)
      (uiop:quit 1)))

  ;; HTTPサーバー起動
  (let ((port (get-port)))
    (format t "[main] Starting API server on port ~A...~%" port)
    (handler-case
        (cl-booth-library-manager.api:start-server port)
      (error (c)
        (format *error-output* "[main] API server failed: ~A~%" c)
        (uiop:quit 1)))

    ;; スケジューラー起動
    (format t "[main] Starting scheduler...~%")
    (cl-booth-library-manager.scheduler:start)

    ;; Electronへポートを通知 (stdoutに "READY:<port>" を出力)
    (format t "READY:~A~%" port)
    (force-output)

    ;; メインループ
    (format t "[main] Ready. Waiting for requests...~%")
    (loop (sleep 1))))