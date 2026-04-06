(in-package :cl-booth-library-manager.scheduler)

;;; ---------------------------------------------------------------------------
;;; State
;;; ---------------------------------------------------------------------------

(defvar *running* nil "スケジューラー動作フラグ")
(defvar *thread* nil "スケジューラースレッド")
(defvar *sync-lock* (bordeaux-threads:make-lock "sync-lock") "同時スクレイプ防止")
(defvar *is-syncing* nil "現在スクレイピング中かどうか")
(defvar *last-synced-at* 0 "最終同期Unixタイムスタンプ (メモリキャッシュ)")
(defvar *sync-fn* nil "スクレイピングを実行するコールバック関数")
(defvar *sync-progress* nil "同期進捗 plist: (:section :page :items-fetched)")

(defconstant +min-interval-seconds+ (* 55 60)  "最小スクレイピング間隔: 55分")
(defconstant +interval-seconds+     (* 60 60)  "通常スクレイピング間隔: 60分")

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun unix-now ()
  "現在時刻をUnixタイムスタンプで返す"
  (- (get-universal-time) 2208988800))

(defun seconds-since-last-sync ()
  (- (unix-now) *last-synced-at*))

(defun can-sync-p ()
  "55分以上経過 かつ ログイン済み かつ 現在同期中でない"
  (and (not *is-syncing*)
       (cl-booth-library-manager.db:is-logged-in)
       (>= (seconds-since-last-sync) +min-interval-seconds+)))

;;; ---------------------------------------------------------------------------
;;; Core sync
;;; ---------------------------------------------------------------------------

(defun do-sync (&key force)
  "スクレイピングを実行してDBに保存する。forceがtrueなら間隔チェックを無視"
  (unless (or force (can-sync-p))
    (format t "[scheduler] Sync skipped (last sync ~A seconds ago)~%"
            (seconds-since-last-sync))
    (return-from do-sync :skipped))

  (bordeaux-threads:with-lock-held (*sync-lock*)
    (setf *is-syncing* t)
    (unwind-protect
         (handler-case
             (let ((cookies (cl-booth-library-manager.db:get-cookies)))
               (unless cookies
                 (format t "[scheduler] No cookies, skipping sync~%")
                 (return-from do-sync :no-auth))

               (format t "[scheduler] Starting sync at ~A~%" (unix-now))
               (setf *sync-progress* (list :section "library" :page 1 :items-fetched 0))
               (unwind-protect
                    (let ((orders (cl-booth-library-manager.scraper:fetch-orders
                                   cookies
                                   :progress-callback
                                   (lambda (section page items-fetched)
                                     (setf *sync-progress*
                                           (list :section      section
                                                 :page         page
                                                 :items-fetched items-fetched))))))
                      ;; 各注文をDBに保存
                      (let ((new-count 0) (updated-count 0) (skipped-count 0))
                        (dolist (order orders)
                          (dolist (item (getf order :items))
                            (let* ((booth-order-id
                                     (format nil "~A-~A"
                                             (getf order :order-id)
                                             (or (getf item :item-id) "0")))
                                   (existing-id
                                     (cl-booth-library-manager.db:get-order-id-by-booth-id
                                      booth-order-id)))
                              (if existing-id
                                  ;; 既存アイテム: DLリンクが変わっていれば更新、同じならスキップ
                                  (let* ((new-links (getf item :downloads))
                                         (new-urls  (sort (mapcar (lambda (l) (getf l :url)) new-links)
                                                          #'string<))
                                         (old-urls  (sort (cl-booth-library-manager.db:get-download-urls
                                                           existing-id)
                                                          #'string<)))
                                    (if (equal new-urls old-urls)
                                        (incf skipped-count)
                                        (progn
                                          (cl-booth-library-manager.db:replace-download-links
                                           existing-id new-links)
                                          (incf updated-count))))
                                  ;; 新規アイテム: 挿入
                                  (let ((order-id
                                          (cl-booth-library-manager.db:upsert-order
                                           booth-order-id
                                           (getf item :item-id)
                                           (getf item :item-name)
                                           (getf item :shop-name)
                                           (getf item :item-url)
                                           (getf item :thumb-url)
                                           (parse-price (getf item :price))
                                           "JPY"
                                           (getf order :purchased-at))))
                                    (cl-booth-library-manager.db:insert-download-links
                                     order-id
                                     (getf item :downloads))
                                    (incf new-count))))))
                        (format t "[scheduler] Sync DB update: ~A new, ~A dl-updated, ~A skipped~%"
                                new-count updated-count skipped-count))

                      ;; 最終同期時刻を記録
                      (let ((now (unix-now)))
                        (setf *last-synced-at* now)
                        (cl-booth-library-manager.db:set-last-synced-at now))

                      (format t "[scheduler] Sync complete. ~A orders processed~%"
                              (length orders))
                      :success)
                 ;; メモリ上のCookieデータをゼロクリア
                 (fill cookies #\Nul)
                 (setf *sync-progress* nil)))
           (cl-booth-library-manager.scraper:cookie-expired-error (c)
             (format *error-output* "[scheduler] Cookie expired: ~A~%" c)
             (cl-booth-library-manager.db:clear-cookies)
             (format t "[scheduler] Cookies cleared. Re-login required.~%")
             :auth-expired)
           (error (c)
             (format *error-output* "[scheduler] Sync error: ~A~%" c)
             :error))
      (setf *is-syncing* nil))))

(defun parse-price (price-str)
  "価格文字列から数値を抽出する"
  (when price-str
    (let ((digits (cl-ppcre:scan-to-strings "[0-9,]+" price-str)))
      (when digits
        (let ((no-comma (cl-ppcre:regex-replace-all "," digits "")))
          (parse-integer no-comma :junk-allowed t))))))

;;; ---------------------------------------------------------------------------
;;; Scheduler loop
;;; ---------------------------------------------------------------------------

(defun scheduler-loop ()
  "バックグラウンドスレッドのメインループ"
  (loop while *running* do
    (when (can-sync-p)
      ;; 別スレッドで実行してスケジューラーループをブロックしない
      (bordeaux-threads:make-thread
       (lambda () (do-sync))
       :name "booth-sync-worker"))
    ;; 1分ごとにチェック
    (dotimes (i 60)
      (unless *running* (return))
      (sleep 1))))

;;; ---------------------------------------------------------------------------
;;; Public API
;;; ---------------------------------------------------------------------------

(defun start (&key sync-fn)
  "スケジューラーを開始する。sync-fnは現在未使用 (内部でdo-syncを直接呼ぶ)"
  (declare (ignore sync-fn))
  ;; DBから最終同期時刻を復元
  (setf *last-synced-at*
        (or (cl-booth-library-manager.db:get-last-synced-at) 0))

  (format t "[scheduler] Last synced at: ~A (now: ~A, delta: ~As)~%"
          *last-synced-at* (unix-now) (seconds-since-last-sync))

  ;; 初回: 55分以上経過していれば起動5秒後に同期開始
  (when (and (cl-booth-library-manager.db:is-logged-in)
             (>= (seconds-since-last-sync) +min-interval-seconds+))
    (bordeaux-threads:make-thread
     (lambda ()
       (sleep 5)
       (do-sync))
     :name "booth-initial-sync"))

  (setf *running* t)
  (setf *thread*
        (bordeaux-threads:make-thread #'scheduler-loop :name "booth-scheduler"))
  (format t "[scheduler] Started~%"))

(defun stop ()
  "スケジューラーを停止する"
  (setf *running* nil)
  (when (and *thread* (bordeaux-threads:thread-alive-p *thread*))
    (bordeaux-threads:join-thread *thread* :timeout 5))
  (setf *thread* nil)
  (format t "[scheduler] Stopped~%"))

(defun trigger-sync ()
  "手動同期トリガー (強制的に実行する)"
  (if (cl-booth-library-manager.db:is-logged-in)
      (bordeaux-threads:make-thread
       (lambda () (do-sync :force t))  ;; ← ここに :force t を追加！
       :name "booth-manual-sync")
      (error "ログインしていません")))

(defun get-status ()
  "同期ステータスを返す"
  (let ((next-at (+ *last-synced-at* +interval-seconds+))
        (now (unix-now)))
    (list :is-syncing      *is-syncing*
          :last-synced-at  *last-synced-at*
          :next-sync-at    next-at
          :seconds-until-next (max 0 (- next-at now))
          :is-logged-in    (cl-booth-library-manager.db:is-logged-in)
          :sync-progress   *sync-progress*)))
