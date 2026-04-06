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

(defvar *log-stream* nil)

(defun open-log-file ()
  "起動ログをファイルに書き出す (問題診断用)"
  (handler-case
      (let* ((log-dir
               #+windows
               (merge-pathnames "cl-booth-library-manager/"
                                (uiop:ensure-directory-pathname
                                 (or (uiop:getenv "APPDATA")
                                     (uiop:native-namestring (user-homedir-pathname)))))
               #-windows
               (merge-pathnames "cl-booth-library-manager/"
                                (uiop:ensure-directory-pathname
                                 (or (uiop:getenv "XDG_DATA_HOME")
                                     (merge-pathnames ".local/share/"
                                                      (user-homedir-pathname))))))
             (log-path (merge-pathnames "startup.log" log-dir)))
        (ensure-directories-exist log-dir)
        (setf *log-stream*
              (open log-path :direction :output
                             :if-exists :supersede
                             :if-does-not-exist :create)))
    (error () nil)))

(defun log-message (fmt &rest args)
  (let ((msg (apply #'format nil fmt args)))
    (format t "~A~%" msg)
    (when *log-stream*
      (format *log-stream* "~A~%" msg)
      (force-output *log-stream*))
    (force-output)))

(defun main ()
  (open-log-file)
  (log-message "=== BOOTH Library Manager v~A ==="
               (cl-booth-library-manager.scraper:app-version))

  ;; シグナルハンドラー設定 (対応OSのみ)
  (setup-signal-handlers)

  ;; DB初期化
  (log-message "[main] Initializing database...")
  (handler-case
      (cl-booth-library-manager.db:init-db)
    (error (c)
      (log-message "[main] DB init failed: ~A" c)
      (uiop:quit 1)))

  ;; HTTPサーバー起動
  (let ((port (get-port)))
    (log-message "[main] Starting API server on port ~A..." port)
    (handler-case
        (cl-booth-library-manager.api:start-server port)
      (error (c)
        (log-message "[main] API server failed: ~A" c)
        (uiop:quit 1)))

    ;; スケジューラー起動
    (log-message "[main] Starting scheduler...")
    (cl-booth-library-manager.scheduler:start)

    ;; Electronへポートを通知 (stdoutに "READY:<port>" を出力)
    (log-message "READY:~A" port)

    ;; メインループ
    (log-message "[main] Ready. Waiting for requests...")
    (loop (sleep 1))))