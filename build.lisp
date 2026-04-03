(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))

(push (truename ".") ql:*local-project-directories*)

(ql:register-local-projects)

(ql:quickload :cl-booth-order-manager :silent t)

(let ((out-dir (merge-pathnames "dist-cl/" *default-pathname-defaults*)))
  (ensure-directories-exist out-dir)
  (sb-ext:save-lisp-and-die
   (merge-pathnames "booth-backend.exe" out-dir)
   :toplevel #'cl-booth-order-manager:main
   :executable t
   :compression t))
