;; Copyright (c) 2010 Haphazard House LLC

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;; THE SOFTWARE.

(in-package :hh-aws)

(export
 (list

  's3-list-buckets
  's3-create-bucket
  's3-delete-bucket
   
  's3-list-bucket-objects
  's3-put-bucket-object
  's3-get-bucket-object
  's3-delete-bucket-object
  
  )
 )

(defservice s3
  :endpoint ( 
             (string "s3.amazonaws.com") 
             )
  :version ( 
            (string "2006-03-01") 
            )
  )

(defclass list-buckets-builder (builder)
  ()
  )

(defxmlparser list-buckets-parser list-buckets-builder
  :enter (
          (call-next-method)
          )
  :text (
         (if (path-p '("Name" "Bucket"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (call-next-method)
         )
  :exit (
         (progn
           (if (current-of handler)
               (progn
                 (putend (current-of handler) (results-of handler) )
                 )
               )
           (setf (current-of handler) nil)
           )
         (call-next-method)
         )
  :finish (
           (mapcar #'car
                   (results-of handler)
                   )
           )
  )

(defrequest s3-list-buckets
  :documentation "Return list of all buckets in S3"
  :bases (s3-request)
  :service s3    
  :result (
           (with-input-from-string 
               (is (bytes-to-string (response-body some-response)))
             (list-buckets-parser is)
             )
           )
  )

(defrequest s3-create-bucket
  :documentation "Create a new bucket"
  :bases (s3-request)
  :service s3
  :method (
           :put
           )
  :args (
         bucket-name
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (add-header some-request "Content-Length" 0)
         (call-next-method)
         )
  :result (
           t
           )
  )

(defrequest s3-delete-bucket
  :documentation "Delete a bucket"
  :bases (s3-request)
  :service s3
  :method (
           :delete
           )
  :args (
         bucket-name
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (call-next-method)
         )
  :result (
           t
           )
  )

(defclass bucket-contents-builder (builder)
  (
   (all-attributes
    :initform nil
    :accessor attributes-of
    )
   (current-attribute
    :initform nil
    :accessor current-attribute-of
    )
   )
  )

(defxmlparser bucket-contents-parser bucket-contents-builder
  :enter (
          (call-next-method)
          )
  :text (
         (if (path-p '("Key" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (if (path-p '("LastModified" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (if (path-p '("ETag" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (if (path-p '("Size" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (if (path-p '("ID" "Owner" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (if (path-p '("DisplayName" "Owner" "Contents"))
             (progn
               (putend text-string (current-of handler) )
               )
             )
         (call-next-method)
         )
  :exit (
         (if (path-p '("Contents"))
             (progn
               (putend (current-of handler) (results-of handler) )
               (setf (current-of handler) nil)
               )
             )
         (call-next-method)
         )
  :finish (
           (results-of handler)
           )
  )

(defrequest s3-list-bucket-objects
  :documentation "List objects in a bucket"
  :bases (s3-request)
  :service s3
  :method (
           :get
           )
  :parameters (
               ("prefix" . prefix)
               )
  :args (
         bucket-name
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (call-next-method)
         )
  :result (
           (with-input-from-string 
               (is (bytes-to-string (response-body some-response)))
             (bucket-contents-parser is)
             )
           )
  )

(defrequest s3-put-bucket-object
  :documentation "Either create a new bucket object for the content,
                  or update an existing one.
                 "
  :bases (s3-request)
  :service s3
  :method (
           :put
           )
  :args (
         bucket-name
         object-name
         content
         )
  :send (
         (http-request (http-uri some-request)
                       :method (method-of some-request)
                       :parameters (signed-parameters-of some-request)
                       :additional-headers (additional-headers-of some-request)
                       :content-type (content-type-of some-request)
                       :content-length (content-length-of some-request)
                       :content (object-content-for some-request)
                       )
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (setf (bucket-object-for some-request) object-name)
         (setf (object-content-for some-request) content)
         
         (handler-bind 
          (
           (aws-error #'(lambda (e)
                          (cout "Response is ~a~%"
                                (bytes-to-string 
                                 (response-body (error-response e))
                                 )
                                )
                          ) 
                      )
           )
          (call-next-method)
          )
         )
  :result (
           t
           )
  )

(defrequest s3-get-bucket-object
  :documentation "Return the contents of the indicated bucket
                 "
  :bases (s3-request)
  :service s3
  :method (
           :get
           )
  :args (
         bucket-name
         object-name
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (setf (bucket-object-for some-request) object-name)
         
	 (call-next-method)
         )
  :result (
           (response-body some-response)
           )
  )

(defrequest s3-delete-bucket-object
  :documentation "Return the contents of the indicated bucket
                 "
  :bases (s3-request)
  :service s3
  :method (
           :delete
           )
  :args (
         bucket-name
         object-name
         )
  :call (
         (setf (bucket-for some-request) bucket-name)
         (setf (bucket-object-for some-request) object-name)
         
          (call-next-method)
         )
  :result (
           t
           )
  )