(defpackage :cl-booth-order-manager.db
  (:use :cl)
  (:export #:init-db
           #:close-db
           #:is-logged-in
           #:save-cookies
           #:get-cookies
           #:clear-cookies
           #:get-last-synced-at
           #:set-last-synced-at
           #:upsert-order
           #:insert-download-links
           #:get-all-orders
           #:get-order-downloads
           #:add-manual-order
           #:delete-order))

(defpackage :cl-booth-order-manager.scraper
  (:use :cl)
  (:export #:fetch-orders
           #:fetch-item-info))

(defpackage :cl-booth-order-manager.scheduler
  (:use :cl)
  (:export #:start
           #:stop
           #:trigger-sync
           #:get-status))

(defpackage :cl-booth-order-manager.api
  (:use :cl)
  (:export #:start-server
           #:stop-server
           #:*port*))

(defpackage :cl-booth-order-manager
  (:use :cl)
  (:export #:main))
