(defpackage :cl-booth-library-manager.db
  (:use :cl)
  (:export #:init-db
           #:close-db
           #:is-logged-in
           #:save-cookies
           #:get-cookies
           #:clear-cookies
           #:get-last-synced-at
           #:set-last-synced-at
           #:get-order-id-by-booth-id
           #:get-download-urls
           #:replace-download-links
           #:upsert-order
           #:insert-download-links
           #:get-all-orders
           #:get-order-downloads
           #:add-manual-order
           #:update-manual-order
           #:delete-order))

(defpackage :cl-booth-library-manager.scraper
  (:use :cl)
  (:export #:fetch-orders
           #:fetch-item-info
           #:cookie-expired-error
           #:app-version))

(defpackage :cl-booth-library-manager.scheduler
  (:use :cl)
  (:export #:start
           #:stop
           #:trigger-sync
           #:get-status))

(defpackage :cl-booth-library-manager.api
  (:use :cl)
  (:export #:start-server
           #:stop-server
           #:*port*))

(defpackage :cl-booth-library-manager
  (:use :cl)
  (:export #:main))
