(in-package :cl-booth-library-manager.db)

;;; ---------------------------------------------------------------------------
;;; Connection management
;;; ---------------------------------------------------------------------------

(defvar *db* nil)
(defvar *db-lock* (bordeaux-threads:make-lock "db-lock"))

(defmacro with-db (&body body)
  `(bordeaux-threads:with-lock-held (*db-lock*)
     ,@body))

(defun get-app-data-dir ()
  "アプリケーションデータディレクトリを返す (プラットフォーム対応)"
  (let ((base
          #+windows
          (or (uiop:getenv "APPDATA")
              (uiop:native-namestring (user-homedir-pathname)))
          #+darwin
          (uiop:native-namestring
           (merge-pathnames "Library/Application Support/"
                            (user-homedir-pathname)))
          #-(or windows darwin)
          (or (uiop:getenv "XDG_DATA_HOME")
              (uiop:native-namestring
               (merge-pathnames ".local/share/"
                                (user-homedir-pathname))))))
    (let ((dir (merge-pathnames "cl-booth-library-manager/"
                                (uiop:ensure-directory-pathname base))))
      (ensure-directories-exist dir)
      dir)))

(defun init-db (&optional path)
  "DBを初期化する。pathが省略された場合はデフォルトパスを使用"
  (let ((db-path (or path
                     (merge-pathnames "orders.db" (get-app-data-dir)))))
    (setf *db* (sqlite:connect (uiop:native-namestring db-path)))
    (create-schema)
    (format t "DB initialized: ~A~%" db-path)
    *db*))

(defun close-db ()
  (when *db*
    (sqlite:disconnect *db*)
    (setf *db* nil)))

;;; ---------------------------------------------------------------------------
;;; Schema
;;; ---------------------------------------------------------------------------

(defun create-schema ()
  (with-db
    (sqlite:execute-non-query *db*
      "PRAGMA foreign_keys = ON")
    (sqlite:execute-non-query *db*
      "CREATE TABLE IF NOT EXISTS orders (
         id              INTEGER PRIMARY KEY AUTOINCREMENT,
         booth_order_id  TEXT UNIQUE,
         item_id         TEXT,
         item_name       TEXT NOT NULL DEFAULT '',
         shop_name       TEXT DEFAULT '',
         item_url        TEXT DEFAULT '',
         thumbnail_url   TEXT DEFAULT '',
         price           INTEGER DEFAULT 0,
         currency        TEXT DEFAULT 'JPY',
         purchased_at    TEXT DEFAULT '',
         created_at      TEXT DEFAULT (datetime('now')),
         is_manual       INTEGER DEFAULT 0
       )")
    (sqlite:execute-non-query *db*
      "CREATE TABLE IF NOT EXISTS download_links (
         id         INTEGER PRIMARY KEY AUTOINCREMENT,
         order_id   INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
         label      TEXT DEFAULT '',
         url        TEXT NOT NULL,
         created_at TEXT DEFAULT (datetime('now'))
       )")
    (sqlite:execute-non-query *db*
      "CREATE TABLE IF NOT EXISTS sync_state (
         key   TEXT PRIMARY KEY,
         value TEXT NOT NULL
       )")
    (sqlite:execute-non-query *db*
      "CREATE INDEX IF NOT EXISTS idx_download_links_order_id
       ON download_links(order_id)")))

;;; ---------------------------------------------------------------------------
;;; Auth / Cookies
;;; ---------------------------------------------------------------------------

(defun save-cookies (cookies-json)
  "Cookie JSONをDBに保存する"
  (with-db
    (sqlite:execute-non-query *db*
      "INSERT OR REPLACE INTO sync_state (key, value) VALUES ('cookies', ?)"
      cookies-json)))

(defun get-cookies ()
  "保存済みCookie JSONを返す。未設定の場合はnil"
  (with-db
    (sqlite:execute-single *db*
      "SELECT value FROM sync_state WHERE key = 'cookies'")))

(defun clear-cookies ()
  (with-db
    (sqlite:execute-non-query *db*
      "DELETE FROM sync_state WHERE key = 'cookies'")))

(defun is-logged-in ()
  "Cookie が保存されているかどうか"
  (not (null (get-cookies))))

;;; ---------------------------------------------------------------------------
;;; Sync state
;;; ---------------------------------------------------------------------------

(defun get-last-synced-at ()
  "最終同期時刻をUnixタイムスタンプ(整数)で返す。未記録なら0"
  (let ((val (with-db
               (sqlite:execute-single *db*
                 "SELECT value FROM sync_state WHERE key = 'last_synced_at'"))))
    (if val (parse-integer val :junk-allowed t) 0)))

(defun set-last-synced-at (unix-timestamp)
  (with-db
    (sqlite:execute-non-query *db*
      "INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_synced_at', ?)"
      (format nil "~A" unix-timestamp))))

;;; ---------------------------------------------------------------------------
;;; Orders CRUD
;;; ---------------------------------------------------------------------------

(defun upsert-order (booth-order-id item-id item-name shop-name
                     item-url thumbnail-url price currency purchased-at)
  "注文をINSERT OR IGNORE し、そのIDを返す"
  (with-db
    (sqlite:execute-non-query *db*
      "INSERT OR IGNORE INTO orders
         (booth_order_id, item_id, item_name, shop_name, item_url,
          thumbnail_url, price, currency, purchased_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
      booth-order-id item-id item-name shop-name item-url
      thumbnail-url price currency purchased-at)
    (sqlite:execute-single *db*
      "SELECT id FROM orders WHERE booth_order_id = ?"
      booth-order-id)))

(defun insert-download-links (order-id links)
  "ダウンロードリンクを追加する。linksはplistのリスト (:label ... :url ...)"
  (with-db
    (dolist (link links)
      (sqlite:execute-non-query *db*
        "INSERT OR IGNORE INTO download_links (order_id, label, url) VALUES (?, ?, ?)"
        order-id
        (or (getf link :label) "")
        (getf link :url)))))

(defun get-all-orders ()
  "全注文を購入日降順で返す。各行は plist"
  (with-db
    (mapcar
     (lambda (row)
       (list :id           (nth 0 row)
             :booth-order-id (nth 1 row)
             :item-id      (nth 2 row)
             :item-name    (nth 3 row)
             :shop-name    (nth 4 row)
             :item-url     (nth 5 row)
             :thumbnail-url (nth 6 row)
             :price        (nth 7 row)
             :currency     (nth 8 row)
             :purchased-at (nth 9 row)
             :is-manual    (= 1 (or (nth 10 row) 0))
             :download-count (nth 11 row)))
     (sqlite:execute-to-list *db*
       "SELECT o.id, o.booth_order_id, o.item_id, o.item_name, o.shop_name,
               o.item_url, o.thumbnail_url, o.price, o.currency,
               o.purchased_at, o.is_manual,
               COUNT(d.id) AS download_count
        FROM orders o
        LEFT JOIN download_links d ON d.order_id = o.id
        GROUP BY o.id
        ORDER BY o.purchased_at DESC, o.id DESC"))))

(defun get-order-downloads (order-id)
  "指定注文のダウンロードリンク一覧を返す"
  (with-db
    (mapcar
     (lambda (row)
       (list :id    (nth 0 row)
             :label (nth 1 row)
             :url   (nth 2 row)))
     (sqlite:execute-to-list *db*
       "SELECT id, label, url FROM download_links WHERE order_id = ? ORDER BY id"
       order-id))))

(defun add-manual-order (item-name shop-name item-url thumbnail-url
                         price currency download-links)
  "手動登録。download-linksはplistのリスト (:label ... :url ...)"
  (let* ((pseudo-id (format nil "manual-~A" (get-universal-time)))
         (order-id (upsert-order pseudo-id nil item-name shop-name
                                 item-url thumbnail-url price currency
                                 (current-date-string))))
    (with-db
      (sqlite:execute-non-query *db*
        "UPDATE orders SET is_manual = 1 WHERE id = ?" order-id))
    (insert-download-links order-id download-links)
    order-id))

(defun delete-order (order-id)
  (with-db
    (sqlite:execute-non-query *db*
      "DELETE FROM orders WHERE id = ?" order-id)))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun current-date-string ()
  (multiple-value-bind (sec min hr day mon yr)
      (decode-universal-time (get-universal-time))
    (declare (ignore sec min hr))
    (format nil "~4,'0D-~2,'0D-~2,'0D" yr mon day)))
