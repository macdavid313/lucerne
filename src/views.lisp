(in-package :cl-user)
(defpackage lucerne.views
  (:use :cl :trivial-types :cl-annot :anaphora)
  (:import-from :clack.request
                :make-request
                :request-method
                :script-name
                :request-uri
                :parameter
                :env)
  (:export :not-found
           :define-route
           :defview
           :route))
(in-package :lucerne.views)

(defmethod not-found ((app lucerne.app:<app>) req)
  "The basic `not-found` screen: Returns HTTP 404 and the text 'Not found'."
  (declare (ignore req))
  (lucerne.http:respond "Not found" :type "text/plain" :status 404))

(defmethod define-route ((app lucerne.app:<app>) url method fn)
  "Map `method` calls to `url` in `app` to the function `fn`."
  (myway:connect (lucerne.app:routes app)
                 url
                 (lambda (params)
                   ;; Dispatching returns a function that closes over `params`
                   (lambda (req)
                     (funcall fn params req)))
                 :method method))

(defmethod clack:call ((app lucerne.app:<app>) env)
  "Routes the request determined by `env` on the application `app`."
  (let* ((req    (make-request env))
         (method (request-method req))
         (uri    (request-uri req))
         ;; Now, we actually do the dispatching
         (route (myway:dispatch (lucerne.app:routes app)
                                uri
                                :method method)))
    (if route
        ;; We have a hit
        (funcall route req)
        ;; Not found
        (not-found app req))))

(defmacro defview (name (&rest args) &rest body)
  "Define a view. The body of the view implicitly has access to the request
  object under the name `req`."
  `(defun ,(intern (symbol-name name)) (params req)
     ;; Here, we extract arguments from the params plist into the arguments
     ;; defined in the argument list
     (let ,(mapcar #'(lambda (arg)
                       `(,arg (getf params ,(intern (symbol-name arg)
                                                    :keyword))))
                   args)
       (declare (ignore params))
       ,@body)))

(annot:defannotation route (app config body) (:arity 3)
  (let* ((view (second body)))
    (if (atom config)
        ;; The config is just a URL
        `(progn
           ,body
           (lucerne.views:route ,app
                                ,config
                                :get
                                #',view))
        ;; The config is a (<method> <url>) pair
        `(progn
           ,body
           (lucerne.views:route ,app
                                ,(second config)
                                ,(first config)
                                #',view)))))
