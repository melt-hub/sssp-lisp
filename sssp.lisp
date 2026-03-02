; sssp.lisp 

;;; |===============| BEGIN DYNAMIC VARIABLES |===============|

; graph variables
(defparameter *vertices* (make-hash-table :test #'equal))
(defparameter *arcs* (make-hash-table :test #'equal))
(defparameter *graphs* (make-hash-table :test #'equal))
(defparameter *visited* (make-hash-table :test #'equal))
(defparameter *distances* (make-hash-table :test #'equal))
(defparameter *previous* (make-hash-table :test #'equal))
; end graph variables

; minheap variables
(defparameter *heaps* (make-hash-table :test #'equal))
; end minheap variables

;;; |===============| END DYNAMIC VARIABLES |===============|

;;; |===============| BEGIN MACROS |===============| 

; allow setf to take sssp-visited in input
(defun (setf sssp-visited) (new-value graph-id vertex-id)
  (setf (gethash (list graph-id vertex-id) *visited*) new-value))
; end allow setf to take sssp-visited in input

;;; |===============| END MACROS |===============| 


;;; |====================| BEGIN GRAPH IMPLEMENTATION |====================|

;; is-graph
(defun is-graph (graph-id)
  (gethash graph-id *graphs*))
;; end of is-graph

;; new-graph
(defun new-graph (graph-id)
    (or (gethash graph-id *graphs*)
    (setf (gethash graph-id *graphs*) graph-id)))
;; end of new-graph

; (helper) get vertex id
(defun get-vertex-id (v) (third v))
; end (helper) get vertex id

;; new-vertex
(defun new-vertex (graph-id vertex-id)
    (when (is-graph graph-id)
    (setf (gethash (list 'vertex graph-id vertex-id) *vertices*)
          (list 'vertex graph-id vertex-id))))
;; end of new-vertex

;; graph-vertices
(defun graph-vertices (graph-id)
  (let ((result nil))
    (maphash (lambda (key value)
    (when (equal (second key) graph-id) (push value result))) *vertices*)
  result))   
;; end of graph-vertices

;; new-arc
(defun new-arc (graph-id u v &optional (weight 1))
    (when (and 
            (is-graph graph-id)
            (gethash (list 'vertex graph-id u) *vertices*)
            (gethash (list 'vertex graph-id v) *vertices*))
    (setf (gethash (list 'arc graph-id u v) *arcs*)
          (list 'arc graph-id u v weight))))
;; end of new-arc

; (helper) weighter
(defun weighter (arc) (fifth arc))
; end (helper) weighter

;; graph-arcs
(defun graph-arcs (graph-id)
  (let ((result nil))
    (maphash (lambda (key value)
    (when (equal (second key) graph-id) (push value result))) *arcs*)
  result))                                     
;; end of graph-arcs

; delete-graph
 (defun delete-graph (graph-id)
    (let ((vertices (graph-vertices graph-id)) 
          (arcs (graph-arcs graph-id)))
     (mapc (lambda (vertex) 
       (let ((vertex-id (get-vertex-id vertex)))
         (remhash (list 'vertex graph-id vertex-id) *vertices*)
         (remhash (list graph-id vertex-id) *distances*)
         (remhash (list graph-id vertex-id) *visited*)
         (remhash (list graph-id vertex-id) *previous*)))
     vertices)
     (mapc (lambda (arc) 
       (remhash (list 'arc graph-id (third arc) (fourth arc)) *arcs*))
     arcs))
     (remhash graph-id *graphs*)
 nil)
;; end of delete-graph

;; graph-vertex-neighbors
(defun graph-vertex-neighbors (graph-id vertex-id)
  (let ((neighbors nil))
    (maphash (lambda (key value)
    (when (and (equal (second key) graph-id)
               (equal (third key) vertex-id))
               (push value neighbors))) *arcs*)
  neighbors))
;; end of graph-vertex-neighbors

;; graph-print
(defun graph-print (graph-id)
  (format t "GRAPH: ~S~%VERTICES: ~S~%ARCS: ~S~%"
          graph-id
          (graph-vertices graph-id)
          (graph-arcs graph-id)))
;; end of graph-print

;;; |====================| END GRAPH IMPLEMENTATION |====================|

;;; |====================| BEGIN MINHEAP IMPLEMENTATION |====================|

; new-heap
(defun new-heap (heap-id &optional (initial-capacity 42)) 
   (or (gethash heap-id *heaps*) 
       (setf (gethash heap-id *heaps*) 
             (list 'heap 
                   heap-id 
                   0 
                   (make-array initial-capacity) 
                   (make-hash-table :test #'equal)))))
; end of new-heap

; heap-id
(defun heap-id (heap-rep) (second heap-rep))
; end of heap-id

; heap-size
(defun heap-size (heap-rep) (third heap-rep))
; end of heap-size

; (helper) modify size
(defun modify-size (heap-rep delta) 
  (if (minusp (+ (heap-size heap-rep) delta))
      (error "ERR: Heap underflow.")
      (incf (third heap-rep) delta)))
; end (helper) modify size

; heap-actual-heap
(defun heap-actual-heap (heap-rep) (fourth heap-rep))
; end of heap-actual-heap

; (helper) heap capacity
(defun heap-capacity (heap-rep) (length (heap-actual-heap heap-rep)))
; end (helper) heap capacity

; (helper) quick access
(defun quick-access (heap-rep) (fifth heap-rep))
; end (helper) quick access

; heap-delete 
(defun heap-delete (heap-id) (remhash heap-id *heaps*) t)
; end of heap-delete

; heap-empty
(defun heap-empty (heap-id) 
  (eq (heap-size (gethash heap-id *heaps*)) 0))
; end of heap-empty

; heap-not-empty
(defun heap-not-empty (heap-id) (not (heap-empty heap-id)))
; end of heap-not-empty

; (helper) heap full
(defun heap-full (heap-rep)
    (eq (heap-size heap-rep) (heap-capacity heap-rep)))
; end (helper) heap full

; (helper) heap expand
;
; Used (fourth heap-rep) instead of (heap-actual-heap heap-rep) because
; setf takes only native functions in input, and heap-actual-heap is not.
; 
; Used :initial-element nil to avoid initializing the new vector with 
; unpredictable garbage.
;
; [LISPWORKS.COM] Chose to use let* instead of let to "establish sequential
; variable binding in order to allow later bindings to refer to earlier
; ones" and avoid using five nested let(s).
(defun heap-expand (heap-rep)
  (let* ((old-vector (heap-actual-heap heap-rep)) 
         (old-capacity (heap-capacity heap-rep))
         (new-capacity (* old-capacity 2))
         (new-vector 
           (adjust-array old-vector new-capacity :initial-element nil)))
    (setf (fourth heap-rep) new-vector) t))
; end (helper) heap expand

; heap head
;
; Chose to use zerop instead of heap-empty because the use of heap-empty
; implied a second, redundant, access to the hash map.
(defun heap-head (heap-id)
  (let ((h (gethash heap-id *heaps*)))
    (cond ((null h) (error "ERR: Heap not found.")) 
          ((zerop (heap-size h)) nil)
          (t (aref (heap-actual-heap h) 0)))))
; end heap head

; (helper) parent
(defun parent (p) (floor (/ (- p 1) 2)))
; end (helper) parent

; (helper) left
(defun left (p) (+ (* p 2) 1))
; end (helper) left

; (helper) right
(defun right (p) (+ (* p 2) 2))
; end (helper) right

; (helper) actual node
(defun actual-node (actual-heap p) (aref actual-heap p))
; end (helper) actual node

; (helper) key
(defun key (actual-heap p) (first (aref actual-heap p)))
; end (helper) kef

; (helper) value
(defun value (actual-heap p) (second (aref actual-heap p)))
; end (helper) value

; (helper) swap
(defun swap (actual-heap pa pb qacc)
  (let ((node-a (aref actual-heap pa))
        (node-b (aref actual-heap pb)))
    (setf (gethash node-a qacc) pb)
    (setf (gethash node-b qacc) pa)
    (rotatef (aref actual-heap pa)
             (aref actual-heap pb))))
; end (helper) swap

; (helper) heapify up
(defun heapify-up (actual-heap p qacc)
  (if (eq p 0)
    t
    (let ((parentp (parent p)))
      (when (> (key actual-heap parentp) (key actual-heap p))
        (swap actual-heap p parentp qacc)
        (heapify-up actual-heap parentp qacc)))))
; end (helper) heapify up

; heap insert
(defun heap-insert (heap-id K V)
  (let ((h (gethash heap-id *heaps*)))
    (when (null h) (error "ERR: Heap not found."))
    (when (heap-full h) (heap-expand h))
    (let ((vec (heap-actual-heap h))
          (size (heap-size h))
          (new-node (list K V))
          (qacc (quick-access h))) 
      (setf (aref vec size) new-node)
      (setf (gethash new-node qacc) size)
      (modify-size h 1)
      (heapify-up vec size qacc) t)))
; end heap insert

; (helper) minor child
(defun minor-child (actual-heap p s)
  (let ((left-child (left p))
        (right-child (right p)))
    (cond ((>= left-child s) p)
          ((>= right-child s) 
           (if (< (key actual-heap p) (key actual-heap left-child))
             p
             left-child))
          (t (let* ((left-key (key actual-heap left-child))
                   (right-key (key actual-heap right-child))
                   (parent-key (key actual-heap p))
                   (lowest (min left-key right-key parent-key)))
               (cond ((= left-key lowest) left-child)
                     ((= right-key lowest) right-child)
                     (t p)))))))
; end (helper) minor child

; (helper) heapify-down
 (defun heapify-down (actual-heap p s qacc)
   (when (eq p s) t)
   (let ((il-bastardo (minor-child actual-heap p s)))
     (when (not (eq il-bastardo p)) (swap actual-heap il-bastardo p qacc)
     (heapify-down actual-heap il-bastardo s qacc))))
; end (helper) heapify-down

; heap-extract
(defun heap-extract (heap-id) 
  (let ((h (gethash heap-id *heaps*)))
    (cond ((null h) (error "ERR: Heap not found."))
          ((heap-empty heap-id) (error "ERR: Heap empty."))
          (t 
            (let* ((vec (heap-actual-heap h))
                   (size (heap-size h))
                   (qacc (quick-access h))
                   (exted (heap-head heap-id))
                   (lstel (aref vec (1- size))))
              (remhash exted qacc)
              (when (not (equal lstel exted)) 
                 (setf (gethash lstel qacc) 0))
               (setf (aref vec 0) lstel)
               (setf (aref vec (1- size)) nil)
               (modify-size h -1)
               (heapify-down vec 0 (1- size) qacc) exted)))))
; end heap-extract

; (helper) find node
(defun find-node (heap-rep old-key value)
  (let ((qacc (quick-access heap-rep))
        (node-tof (list old-key value)))
    (gethash node-tof qacc)))
; end (helper) find node

; heap modify key
(defun heap-modify-key (heap-id new-key old-key V)
  (when (heap-not-empty heap-id)
    (let* ((h (gethash heap-id *heaps*))
          (quello-la (find-node h old-key V))
          (actual-heap (heap-actual-heap h))
          (size (heap-size h))
          (qacc (quick-access h)))
      (remhash (list old-key V) qacc)
      (setf (first (actual-node actual-heap quello-la)) new-key)
      (setf (gethash (list new-key V) qacc) quello-la)
      (cond ((<= new-key old-key) (heapify-up actual-heap quello-la qacc))
            (t (heapify-down actual-heap quello-la size qacc))))))
; end heap modify key

; (helper) print rec
(defun print-rec (vec size i)
  (when (< i size)
    (format t "[~A] -> ~A~%" i (aref vec i))
    (print-rec vec size (1+ i))))
; end (helper) print rec

; heap print
(defun heap-print (heap-id)
  (let ((h (gethash heap-id *heaps*)))
    (if (null h)
        (error "ERR: Empty heap!")
        (let ((size (heap-size h))
              (vec (heap-actual-heap h)))
          (format t "id: ~A, size: ~A~%" heap-id size)
          (print-rec vec size 0) t))))
; end heap-print 

;;; |====================| END MINHEAP IMPLEMENTATION |====================|

;;; |====================| BEGIN SSSP IMPLEMENTATION |====================|

; sssp-dist
(defun sssp-dist (graph-id vertex-id) 
  (gethash (list graph-id vertex-id) *distances*))
; end of sssp-dist

; sssp-visited
(defun sssp-visited (graph-id vertex-id)
  (gethash (list graph-id vertex-id) *visited*))
; end of sssp-visited

; sssp-previous
(defun sssp-previous (graph-id V)
  (gethash (list graph-id V) *previous*))
; end of sssp-previous

; sssp-change-dist
(defun sssp-change-dist (graph-id V new-dist)
  (setf (gethash (list graph-id (get-vertex-id V)) *distances*) new-dist) nil)
; end of sssp-change-dist

; sssp-change-previous
(defun sssp-change-previous (graph-id V U)
  (setf (gethash (list graph-id (get-vertex-id V)) *previous*) U) nil)
; sssp-change-previous

; (helper) initialize single source
(defun initialize-single-source (graph-id source-id)
  (let ((vertices (graph-vertices graph-id)))
    (mapc (lambda (vertex) 
            (let ((v-id (get-vertex-id vertex)))
              (setf (gethash (list graph-id v-id) *distances*) 
                    most-positive-fixnum)
              (setf (gethash (list graph-id v-id) *previous*) 
                    nil)))
          vertices)
    (setf (gethash (list graph-id source-id) *distances*) 0)))
; end (helper) initialize single source

; (helper) relax
(defun relax (graph-id u-id v-id)
  (let* ((arc (gethash (list 'arc graph-id u-id v-id) *arcs*))
         (wgt (weighter arc))
         (v-d (sssp-dist graph-id v-id))
         (u-d (sssp-dist graph-id u-id))
         (u-vert (gethash (list 'vertex graph-id u-id) *vertices*)))
    (when (and (< u-d most-positive-fixnum)
               (> v-d (+ u-d wgt)))
      (let ((v-vert (gethash (list 'vertex graph-id v-id) *vertices*)))
        (sssp-change-dist graph-id v-vert (+ u-d wgt))
        (sssp-change-previous graph-id v-vert u-vert) t))))
; end (helper) relax

; (helper) get-neighbors
(defun get-neighbors (graph-id v)
  (mapcar 'fourth (graph-vertex-neighbors graph-id v)))
; end of get-neighbors

; to suppress a useless style warning caused by mutual
; recursion between compute-shortest-path and relax-neighbors
(declaim (ftype function compute-shortest-path-tree))

; (helper) relax neighbors
(defun relax-neighbors (graph-id u-id neighbors prio-queue)
  (cond ((null neighbors) (compute-shortest-path-tree graph-id prio-queue))
        (t (let* ((v-id (first neighbors))
                  (v-vert (gethash (list 'vertex graph-id v-id) *vertices*))
                  (old-d (sssp-dist graph-id v-id)))
             (when (relax graph-id u-id v-id)
               (let ((new-d (sssp-dist graph-id v-id)))
                 (heap-modify-key prio-queue new-d old-d v-vert)))
             (relax-neighbors graph-id u-id (rest neighbors) prio-queue)))))
; end (helper) relax neighbors

; (helper) fill priority queue
(defun fill-prio-queue (heap-id vertices source)
  (cond ((null vertices) t)
        ((if (equal (first vertices) source)
           (heap-insert heap-id 0 (first vertices))
           (heap-insert heap-id most-positive-fixnum (first vertices)))
         (fill-prio-queue heap-id (rest vertices) source)))) 
; end (helper) fill priority queue

; (helper) compute-shortest-path-tree
(defun compute-shortest-path-tree (graph-id prio-queue)
  (when (heap-not-empty prio-queue)
    (let* ((couple (heap-extract prio-queue))
           (u (second couple))
           (u-id (get-vertex-id u)))
      (setf (sssp-visited graph-id u-id) t)
      (relax-neighbors graph-id 
                       u-id 
                       (get-neighbors graph-id u-id) prio-queue))))
; end (helper) compute-shortest-path-tree

; sssp dijkstra
(defun sssp-dijkstra (graph-id source-id)
  (if (is-graph graph-id)
    (dijkstra graph-id source-id)
    (error "ERR: No such graph")))
; end sssp dijkstra

; dijkstra
(defun dijkstra (graph-id source-id)
  (when (is-graph graph-id) 
    (heap-delete 'Giulio)
    (new-heap 'Giulio)
    (initialize-single-source graph-id source-id)
    (fill-prio-queue 'Giulio 
                     (graph-vertices graph-id) 
                     (gethash (list 'vertex graph-id source-id) *vertices*))
    (compute-shortest-path-tree graph-id 'Giulio)) nil)
; end dijkstra

; (helper) build-path
(defun build-path (graph-id source-id current-id)
  (if (eq source-id current-id)
    nil
    (let* 
      ((prev-vert (sssp-previous graph-id current-id))
       (prev-id (get-vertex-id prev-vert)))
      (cons 
        (gethash (list 'arc graph-id prev-id current-id) *arcs*)
        (build-path graph-id source-id prev-id)))))
; end (helper) build-path

; sssp-shortest-path
(defun sssp-shortest-path (G Source V)
  (if (is-graph g) 
    (reverse (build-path G Source V))
    (error "ERR: No such graph")))
; end sssp-shortest-path

;;; |====================| END SSSP IMPLEMENTATION |====================|

; end of sssp.lisp
