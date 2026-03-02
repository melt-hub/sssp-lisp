# SSSP in Common Lisp

This file provides a solution to the common **graph problem** of finding the **Single Source Shortest Path**, through the implementation of **Dijkstra's algorithm** in Common Lisp. Before diving into the actual algorithm's implementation, it is necessary to provide a basic implementation of two ADTs: a **graph**, and a **min-heap**. The graph is implemented as a **weighted, directed graph**, and the min-heap is implemented as a **priority queue** backed by a dynamically resizable array.

Unlike the Prolog implementation where the knowledge base serves as a global, mutable store of facts this implementation manages state through a set of **global hash tables**, each scoped by graph or heap identifier.

---

## Dynamic Variables

The implementation relies on the following globally defined hash tables, declared via `defparameter`:

| Variable      | Type         | Description                                                          |
| :------------ | :----------- | :------------------------------------------------------------------- |
| `*graphs*`    | `hash-table` | Maps a graph identifier to itself upon creation.                     |
| `*vertices*`  | `hash-table` | Maps `(vertex graph-id vertex-id)` keys to vertex lists.             |
| `*arcs*`      | `hash-table` | Maps `(arc graph-id u v)` keys to arc lists.                         |
| `*visited*`   | `hash-table` | Maps `(graph-id vertex-id)` keys to boolean visited flags.           |
| `*distances*` | `hash-table` | Maps `(graph-id vertex-id)` keys to current shortest-path estimates. |
| `*previous*`  | `hash-table` | Maps `(graph-id vertex-id)` keys to predecessor vertex structs.      |
| `*heaps*`     | `hash-table` | Maps a heap identifier to its internal representation list.          |

All hash tables are initialized with `:test #'equal` to allow structural list equality on composite keys.

---

## Graph Implementation

The **graph** is represented through three global hash tables: `*graphs*`, `*vertices*`, and `*arcs*`. Each vertex is stored as a list of the form `(vertex graph-id vertex-id)`, and each arc as `(arc graph-id u v weight)`. This design allows $O(1)$ average-case access to any vertex or arc given its composite key.

### Graph API

| Function | Brief Description |
| :--- | :--- |
| `is-graph(graph-id)` | Returns the graph identifier if graph `graph-id` exists, otherwise `NIL`. |
| `new-graph(graph-id)` | Creates a new graph entry in `*graphs*`, or returns the existing one. |
| `new-vertex(graph-id, vertex-id)` | Adds vertex `vertex-id` to graph `graph-id`. |
| `graph-vertices(graph-id)` | Returns the list of all vertex structs belonging to graph `graph-id`. |
| `new-arc(graph-id, u, v, weight)` | Adds a directed, weighted arc from `u` to `v` in graph `graph-id`. |
| `graph-arcs(graph-id)` | Returns the list of all arc structs belonging to graph `graph-id`. |
| `delete-graph(graph-id)` | Removes graph `graph-id` and all associated vertices, arcs, distances, visited flags, and predecessors. |
| `graph-vertex-neighbors(graph-id, vertex-id)` | Returns the list of arc structs whose source is `vertex-id` in graph `graph-id`. |
| `graph-print(graph-id)` | Prints the graph's identifier, vertices, and arcs to standard output. |

---

### Function `is-graph`

This function performs a direct hash table lookup in `*graphs*` using the provided `graph-id`. It returns the stored value (the identifier itself) if the graph exists, or `NIL` otherwise. It serves as a guard condition used throughout the implementation.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `new-graph`

This function returns the existing entry for `graph-id` in `*graphs*` if one is already present (short-circuiting via `or`), or otherwise inserts a new entry mapping `graph-id` to itself via `setf`.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `get-vertex-id`

A simple accessor that returns the third element of a vertex struct `(vertex graph-id vertex-id)`, i.e., the bare vertex identifier. It is used throughout the implementation to extract the identifier from a full vertex representation.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `new-vertex`

This function first verifies that graph `graph-id` exists via `is-graph`, and if so, inserts the vertex struct `(vertex graph-id vertex-id)` into `*vertices*` using the same struct as both key and value. No duplicate check is performed inserting an existing key simply overwrites the entry with an identical value.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `graph-vertices`

This function iterates over all entries in `*vertices*` using `maphash`, collecting into a result list all values whose key's second element matches `graph-id`. Since `*vertices*` is a flat hash table shared across all graphs, this requires a full scan.

**Complexity:** $f(n) \sim O(V_{\text{total}})$, where $V_{\text{total}}$ is the total number of vertices across all graphs in the knowledge base.

---

### Helper `weighter`

This accessor returns the fifth element of an arc struct `(arc graph-id u v weight)`, i.e., the arc's weight. In the context of Dijkstra's algorithm, it models the **weight function** $w(u, v)$ from [[Introduction To Algorithms — T. H. Cormen, C. E. Leiserson, R. L. Rivest, C. Stein]], which assigns a non-negative real-valued cost to each directed edge $(u, v) \in G.E$.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `new-arc`

This function verifies that the graph exists and that both endpoint vertices `u` and `v` are registered in `*vertices*`, then inserts the arc struct `(arc graph-id u v weight)` into `*arcs*`. The default weight is `1` if none is provided. As with `new-vertex`, no explicit duplicate check is performed.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `graph-arcs`

Analogous to `graph-vertices`, this function scans `*arcs*` via `maphash`, collecting all entries whose key's second element matches `graph-id`.

**Complexity:** $f(n) \sim O(E_{\text{total}})$, where $E_{\text{total}}$ is the total number of arcs across all graphs.

---

### Function `delete-graph`

This function collects all vertices and arcs belonging to `graph-id`, then iterates over them removing the corresponding entries from `*vertices*`, `*distances*`, `*visited*`, `*previous*`, and `*arcs*`. Finally, it removes the graph entry itself from `*graphs*`.

**Complexity:** $f(n) \sim O(V + E)$

---

### Function `graph-vertex-neighbors`

This function scans `*arcs*` via `maphash`, collecting all arc structs whose graph identifier matches `graph-id` and whose source vertex matches `vertex-id`. These arcs represent the outgoing adjacency list of `vertex-id`, i.e., $G.Adj[u]$ in Cormen's notation.

**Complexity:** $f(n) \sim O(E_{\text{total}})$

---

### Function `graph-print`

This function uses `format` to print the graph identifier, its vertex list, and its arc list to standard output. It is a pure diagnostic utility.

**Complexity:** $f(n) \sim O(V + E)$

---

## Min-Heap Implementation

The **priority queue** required by Dijkstra's algorithm is implemented as a **min-heap** backed by a dynamically resizable Common Lisp array. Each heap is identified by a key in the global `*heaps*` hash table, where the stored value is a **heap representation list** referred to throughout the implementation as `heap-rep` of the form:

```lisp
(heap heap-id size array quick-access-table)
```

The five elements of this list are accessed through dedicated helper functions: `heap-id`, `heap-size`, `heap-actual-heap`, and `quick-access`. The array stores nodes of the form `(key value)`, and the binary tree structure is navigated arithmetically: the **parent** of node at index $i$ is at $\lfloor (i-1)/2 \rfloor$, the **left child** at $2i+1$, and the **right child** at $2i+2$.

### Optimization: use of the `quick-access` hash-map

A key design choice in this implementation is the addition of a **fifth element** to `heap-rep`: a dedicated hash table `quick-access`, referred to in the code as `qacc`. This table maps each node `(key value)` directly to its current **position** (index) in the underlying array, and is kept synchronized with every structural operation on the heap insertions, extractions, and swaps all update `qacc` accordingly.

The motivation for this design is efficiency in `heap-modify-key`. Without `qacc`, locating a node by its `(old-key value)` pair would require a **linear scan** of the array, a $O(n)$ operation, making each `DECREASE-KEY` call in Dijkstra's algorithm expensive. With `qacc`, the helper `find-node` performs a single hash table lookup, reducing node lookup to $\Theta(1)$ time. This transforms `heap-modify-key` from $O(n)$ to $O(\log n)$ per call.

This optimization is precisely what the analysis in [[Introduction To Algorithms — T. H. Cormen, C. E. Leiserson, R. L. Rivest, C. Stein]] refers to when describing the **binary min-heap** implementation of the priority queue: *"a simple implementation takes advantage of the vertices being numbered 1 to $|V|$: simply store $v.d$ in the $v$th entry of an array. Each INSERT and DECREASE-KEY operation takes $O(1)$ time"*. However, since our vertices are not integers but arbitrary structures, direct indexing is unavailable , `qacc` provides an equivalent $\Theta(1)$ access mechanism. As the same analysis concludes, with $O(\log V)$ DECREASE-KEY operations via a binary min-heap, the total running time of Dijkstra's algorithm becomes $O((V + E) \log V)$, which is $O(E \log V)$ in the typical case where $|E| = \Omega(V)$.

### Min-Heap API

| Function | Brief Description |
| :--- | :--- |
| `new-heap(heap-id, initial-capacity)` | Creates a new heap with a given initial array capacity, or returns the existing one. |
| `heap-id(heap-rep)` | Returns the identifier of the heap. |
| `heap-size(heap-rep)` | Returns the current number of elements in the heap. |
| `heap-actual-heap(heap-rep)` | Returns the underlying array storing the heap nodes. |
| `heap-delete(heap-id)` | Removes the heap from `*heaps*`. |
| `heap-empty(heap-id)` | Returns `T` if the heap contains no elements. |
| `heap-not-empty(heap-id)` | Returns `T` if the heap contains at least one element. |
| `heap-head(heap-id)` | Returns the minimum-key node without removing it. |
| `heap-insert(heap-id, K, V)` | Inserts node `(K V)` into the heap, restoring the min-heap property. |
| `heap-extract(heap-id)` | Removes and returns the minimum-key node, restoring the min-heap property. |
| `heap-modify-key(heap-id, new-key, old-key, V)` | Replaces `old-key` for value `V` with `new-key`, restoring the min-heap property. |
| `heap-print(heap-id)` | Prints the internal state of the heap to standard output. |

---

### Function `new-heap`

This function returns the existing heap for `heap-id` if one is already present in `*heaps*` (short-circuiting via `or`), or otherwise creates a new heap representation list of the form `(heap heap-id 0 array qacc)`, where `array` is a freshly allocated array of `initial-capacity` elements and `qacc` is a new hash table. The default initial capacity is `42`.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helpers `heap-id`, `heap-size`, `heap-actual-heap`, `quick-access`

These are simple positional accessors on the `heap-rep` list. `heap-id` returns the second element, `heap-size` the third, `heap-actual-heap` the fourth, and `quick-access` the fifth. They encapsulate the internal structure of `heap-rep` and are used throughout the implementation.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Helper `modify-size`

This function increments the size field of `heap-rep` (the third element) by `delta` using `incf`. It first checks that the resulting size would not be negative, raising an underflow error otherwise.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `heap-capacity`

Returns the length of the underlying array via `length`, representing the total number of slots currently allocated (as opposed to the number of elements currently stored).

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `heap-delete`

Removes the heap identified by `heap-id` from `*heaps*` via `remhash` and returns `T`. This does not perform any cleanup of the `qacc` table the entire heap representation is simply garbage collected.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Functions `heap-empty` and `heap-not-empty`

`heap-empty` checks whether the heap's size is `0` using `zerop` on the result of `heap-size`. `heap-not-empty` is its logical negation via `not`. Both are used as guard conditions throughout the SSSP implementation.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Helper `heap-full`

Returns `T` when the heap's current size equals the capacity of the underlying array, indicating that no more insertions can occur without first expanding the array.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `heap-expand`

When the underlying array is full, this function doubles its capacity using `adjust-array` with `:initial-element nil` to avoid uninitialized garbage in the new slots. The new vector is written directly into the fourth slot of `heap-rep` via `setf (fourth heap-rep)`. The implementation uses `let*` rather than nested `let` forms to allow later bindings to reference earlier ones, following Common Lisp best practice for sequential variable binding.

**Complexity:** $f(n) \sim O(n)$ due to the array copy performed by `adjust-array`.

---

### Function `heap-head`

This function retrieves the heap from `*heaps*`, raises an error if not found, returns `NIL` if the heap is empty, and otherwise returns the element at index `0` of the underlying array — the root of the logical binary tree, which holds the minimum key. The emptiness check uses `zerop` directly on the size to avoid a redundant second hash table lookup.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helpers `parent`, `left`, `right`

These functions implement the arithmetic navigation of the binary tree encoded in the array:

- `parent(p)` returns $\lfloor (p-1)/2 \rfloor$
- `left(p)` returns $2p+1$
- `right(p)` returns $2p+2$

Note that, unlike the 1-based indexing used in the Prolog implementation and in Cormen's pseudocode, this implementation uses **0-based indexing**, hence the offset of $-1$ in the parent formula.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Helpers `actual-node`, `key`, `value`

These are array accessor helpers: `actual-node` returns the full `(key value)` pair at position `p`, `key` returns its first element, and `value` returns its second. They are used to abstract direct array access throughout the heap operations.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Helper `swap`

This function swaps the nodes at positions `pa` and `pb` in the array using `rotatef`, and simultaneously updates both entries in `qacc` so that each node's recorded position reflects the exchange.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `heapify-up`

This function restores the min-heap property after an insertion by bubbling the element at position `p` upward until either the root is reached or the parent's key is no longer greater than the child's key. It is structured in two clauses:

$$T(n) =
\begin{cases}
\Theta(1) & \text{if } p = 0 \quad \textbf{(Base Case: root reached)} \\
T(\lfloor (p-1)/2 \rfloor) + \Theta(1) & \text{if key}(p) < \text{key}(\text{parent}(p)) \quad \textbf{(Recursive Case: swap and recurse upward)}
\end{cases}$$

**Complexity:** $f(n) \sim O(\log n)$

---

### Function `heap-insert`

This function appends the new node `(K V)` to the next available position in the array (at index `size`), records its position in `qacc`, increments the heap size, and calls `heapify-up` to restore the min-heap property. If the array is full, `heap-expand` is called first to double its capacity.

**Complexity:** $f(n) \sim O(\log n)$ amortized (the $O(n)$ expansion cost is amortized over $O(n)$ insertions).

---

### Helper `minor-child`

This function determines the position of the smallest among a node at `p` and its children, to be used as the target of a downward swap in `heapify-down`. It is structured in three clauses:

- **Clause A** — the left child index is out of bounds (i.e., `p` is a leaf): returns `p` itself.
- **Clause B** — only the left child exists: returns the smaller of `p` and the left child.
- **Clause C** — both children exist: returns the position of the globally smallest key among `p`, left child, and right child using `min` and a `cond` dispatch.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `heapify-down`

This function restores the min-heap property after an extraction by pushing the element at position `p` downward until the heap property is satisfied. It first checks that `p` is not already the last valid index (`s`), then computes the minor child via `minor-child`. If the minor child is not `p` itself, it swaps and recurses downward.

$$T(n) =
\begin{cases}
\Theta(1) & \text{if } p = s \text{, or minor-child}(p) = p \quad \textbf{(Base Case)} \\
T(2p+1 \text{ or } 2p+2) + \Theta(1) & \text{otherwise} \quad \textbf{(Recursive Case: swap and recurse downward)}
\end{cases}$$

**Complexity:** $f(n) \sim O(\log n)$

---

### Function `heap-extract`

This function removes and returns the minimum node (at index `0`) from the heap. It first validates that the heap exists and is non-empty, then saves the root node and the last element. The last element overwrites the root, the old last slot is cleared to `nil`, the size is decremented, and `heapify-down` is called to restore the min-heap property. The `qacc` table is updated accordingly: the extracted node's entry is removed, and the last element's entry is updated to position `0`.

**Complexity:** $f(n) \sim O(\log n)$

---

### Helper `find-node`

This function performs a $\Theta(1)$ lookup in `qacc` using the composite key `(old-key value)` to retrieve the current array position of the node to be modified. This is the core operation that makes `heap-modify-key` efficient, as described in the `new-heap` section above.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Function `heap-modify-key`

This function updates the key of the node identified by `(old-key V)` in heap `heap-id` to `new-key`. It first locates the node's position via `find-node`, updates the key in-place via `setf (first ...)`, refreshes `qacc` (removing the old entry and inserting the new one), and then restores the heap property: calling `heapify-up` if `new-key <= old-key` (a decrease), or `heapify-down` if `new-key > old-key` (an increase).

**Complexity:** $f(n) \sim O(\log n)$, thanks to the $\Theta(1)$ node lookup provided by `qacc`.

---

### Helper `print-rec`

This recursive helper iterates over the array from index `i` to `size - 1`, printing each element with its index. It is the engine behind `heap-print`.

$$T(n) =
\begin{cases}
\Theta(1) & \text{if } i \geq \text{size} \quad \textbf{(Base Case)} \\
T(n-1) + \Theta(1) & \text{otherwise} \quad \textbf{(Recursive Case)}
\end{cases}$$

**Complexity:** $f(n) \sim O(n)$

---

### Function `heap-print`

This function validates the heap's existence, then prints the heap identifier and size, and delegates the element-by-element output to `print-rec`.

**Complexity:** $f(n) \sim O(n)$

---

## SSSP Implementation

The **Single Source Shortest Path** is computed via **Dijkstra's algorithm**, directly modelling the pseudocode from [[Introduction To Algorithms — T. H. Cormen, C. E. Leiserson, R. L. Rivest, C. Stein]]. The algorithm's state is maintained in three global hash tables: `*distances*`, `*previous*`, and `*visited*`, all keyed by `(graph-id vertex-id)` composite keys.

### SSSP API

| Function | Brief Description |
| :--- | :--- |
| `sssp-dist(graph-id, vertex-id)` | Returns the current shortest-path estimate for `vertex-id` in `graph-id`. |
| `sssp-visited(graph-id, vertex-id)` | Returns `T` if `vertex-id` has been visited (extracted from the queue). |
| `sssp-previous(graph-id, V)` | Returns the predecessor vertex struct of `V` on the shortest-path tree. |
| `sssp-change-dist(graph-id, V, new-dist)` | Updates the distance estimate of vertex `V` in `graph-id`. |
| `sssp-change-previous(graph-id, V, U)` | Sets the predecessor of vertex `V` to `U` in `graph-id`. |
| `sssp-dijkstra(graph-id, source-id)` | Entry point: runs Dijkstra's algorithm on graph `graph-id` from source `source-id`. |
| `sssp-shortest-path(G, Source, V)` | Returns the list of arc structs forming the shortest path from `Source` to `V`. |

---

### Functions `sssp-dist`, `sssp-visited`, `sssp-previous`

These are simple hash table accessors that retrieve the current distance estimate, visited flag, and predecessor for a given vertex in a given graph, respectively. They abstract away the composite key structure `(graph-id vertex-id)`.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Functions `sssp-change-dist` and `sssp-change-previous`

These functions update the distance estimate and predecessor of a given vertex via `setf` on the respective global hash tables. `sssp-change-dist` takes a full vertex struct `V` and extracts its identifier via `get-vertex-id` before constructing the key. Both return `NIL`.

**Complexity:** $f(n) \sim \Theta(1)$ each.

---

### Helper `initialize-single-source`

This function models the **`INITIALIZE-SINGLE-SOURCE(G, s)`** procedure from Cormen, which sets $v.d = \infty$ and $v.\pi = \text{NIL}$ for every vertex $v \in G.V$, and then sets $s.d = 0$. In this implementation, $\infty$ is represented by `most-positive-fixnum` the largest integer value available in the Common Lisp implementation and `NIL` serves as the null predecessor. The function iterates over all vertices of the graph, setting their distances and predecessors accordingly, and then overwrites the source's distance with `0`.

**Complexity:** $f(n) \sim O(V)$

---

### Helper `relax`

This function models the **`RELAX(u, v, w)`** procedure from Cormen, which checks whether the shortest known path to $v$ can be improved by routing it through $u$:

$$\text{if } v.d > u.d + w(u,v) \text{ then } v.d = u.d + w(u,v),\; v.\pi = u$$

In this implementation, `weighter` plays the role of $w(u, v)$, returning the arc's weight. The function first guards against the case where $u.d = \infty$ (represented as `most-positive-fixnum`) to avoid arithmetic overflow. If the relaxation condition is met, it calls `sssp-change-dist` and `sssp-change-previous` to update the state, and returns `T` to signal to the caller (`relax-neighbors`) that a key update in the priority queue is required.

**Complexity:** $f(n) \sim \Theta(1)$

---

### Helper `get-neighbors`

This function retrieves the outgoing arc structs of `v` via `graph-vertex-neighbors` and maps `fourth` over them to extract only the destination vertex identifiers, effectively producing $G.Adj[v]$ as a list of vertex IDs.

**Complexity:** $f(n) \sim O(E_{\text{total}})$ (dominated by `graph-vertex-neighbors`).

---

### Helper `fill-prio-queue`

This recursive function inserts all vertices of the graph into the heap, keyed by their initial distance estimates: `0` for the source vertex and `most-positive-fixnum` (i.e., $\infty$) for all others. This corresponds to lines 3–5 of Cormen's `DIJKSTRA` pseudocode.

$$T(n) =
\begin{cases}
\Theta(1) & \text{if vertices} = \text{NIL} \quad \textbf{(Base Case)} \\
T(n-1) + O(\log n) & \text{otherwise} \quad \textbf{(Recursive Case: heap-insert)}
\end{cases}$$

**Complexity:** $f(n) \sim O(V \log V)$

---

### Helper `compute-shortest-path-tree`

This function models the **outer `while Q ≠ ∅` loop** of Cormen's `DIJKSTRA` pseudocode (lines 6–12). At each step it extracts the minimum vertex `u` from the priority queue, marks it as visited (modelling $S = S \cup \{u\}$ on line 8), and delegates the inner loop to `relax-neighbors`. The mutual recursion between `compute-shortest-path-tree` and `relax-neighbors` is declared in advance via `declaim` to suppress a style warning from the compiler.

$$T(n) =
\begin{cases}
\Theta(1) & \text{if the queue is empty} \quad \textbf{(Base Case)} \\
T(n-1) + O(\deg(u) \cdot \log V) & \text{otherwise} \quad \textbf{(Recursive Case)}
\end{cases}$$

**Complexity:** $f(n) \sim O((V + E) \log V)$

---

### Helper `relax-neighbors`

This function models the **inner `for each vertex v in G.Adj[u]` loop** of Cormen's `DIJKSTRA` pseudocode (lines 9–12). It iterates recursively over the neighbor list of `u`, calling `relax` for each neighbor `v`. If `relax` returns `T` signalling that the distance to `v` was improved it calls `heap-modify-key` with the new and old distances to update `v`'s key in the priority queue, corresponding to the `DECREASE-KEY(Q, v, v.d)` call on line 12 of Cormen's pseudocode. After processing all neighbors, it tail-calls `compute-shortest-path-tree` to continue the outer loop.

$$T(n) =
\begin{cases}
\Theta(1) \text{ then recurse to outer loop} & \text{if neighbors} = \text{NIL} \quad \textbf{(Base Case)} \\
T(n-1) + O(\log V) & \text{otherwise} \quad \textbf{(Recursive Case: relax + modify-key)}
\end{cases}$$

**Complexity:** $f(n) \sim O(\deg(u) \cdot \log V)$ per invocation.

---

### Function `sssp-dijkstra`

This is the main entry point for the algorithm. It first verifies that the graph exists via `is-graph`, raising an error otherwise, and then delegates to `dijkstra`.

**Complexity:** $f(n) \sim \Theta(1)$ (excluding the cost of `dijkstra`).

---

### Function `dijkstra`

This function orchestrates the full algorithm: it resets and re-creates the heap (named `'Giulio`), initializes all distances via `initialize-single-source`, fills the priority queue via `fill-prio-queue`, and launches the main loop via `compute-shortest-path-tree`. It always returns `NIL`.

**Overall Complexity:** $f(n) \sim O((V + E) \log V)$, which is $O(E \log V)$ in the typical case where $|E| = \Omega(V)$, as established by the analysis in Cormen for the binary min-heap implementation of Dijkstra's algorithm.

---

### Helper `build-path`

This recursive function reconstructs the shortest path from `source-id` to `current-id` by following the `*previous*` chain backwards. At each step it looks up the predecessor of `current-id` via `sssp-previous`, retrieves the corresponding arc struct, and conses it onto the result of the recursive call. The path is thus accumulated in **reverse order** (from destination to source).

$$T(n) =
\begin{cases}
\Theta(1) & \text{if source-id} = \text{current-id} \quad \textbf{(Base Case)} \\
T(n-1) + \Theta(1) & \text{otherwise} \quad \textbf{(Recursive Case)}
\end{cases}$$

**Complexity:** $f(n) \sim O(V)$

---

### Function `sssp-shortest-path`

This function verifies that the graph exists, then calls `build-path` to reconstruct the reversed path and applies `reverse` to it, returning the list of arc structs in order from source to destination.

**Complexity:** $f(n) \sim O(V)$


