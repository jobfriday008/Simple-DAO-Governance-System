(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-stake (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-proposal-expired (err u104))
(define-constant err-proposal-not-active (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-no-stake (err u107))
(define-constant err-proposal-not-passed (err u108))
(define-constant err-proposal-already-executed (err u109))
(define-constant err-invalid-voting-period (err u110))

(define-constant err-invalid-delegate (err u300))
(define-constant err-self-delegation (err u301))
(define-constant err-delegation-not-found (err u302))
(define-constant err-delegate-unauthorized (err u303))

(define-map user-delegates principal principal)
(define-map delegate-power principal uint)
(define-map delegator-list principal (list 50 principal))

(define-constant err-invalid-comment-length (err u200))
(define-constant err-comment-not-found (err u201))

(define-data-var comment-counter uint u0)

(define-data-var proposal-counter uint u0)
(define-data-var min-stake-required uint u1000)
(define-data-var voting-period uint u1008)
(define-data-var execution-delay uint u144)
(define-data-var quorum-percentage uint u30)

(define-map user-stakes principal uint)
(define-map proposals 
  uint 
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    target: (optional principal),
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool,
    executable-at: uint
  }
)

(define-map user-votes {proposal-id: uint, voter: principal} {vote: bool, amount: uint})
(define-map proposal-voters uint (list 200 principal))

(define-read-only (get-proposal-info (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-user-stake (user principal))
  (default-to u0 (map-get? user-stakes user))
)

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? user-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

(define-read-only (get-min-stake)
  (var-get min-stake-required)
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (get-quorum-percentage)
  (var-get quorum-percentage)
)

(define-read-only (calculate-total-staked)
  (fold + (map get-user-stake-value (list tx-sender)) u0)
)

(define-private (get-user-stake-value (user principal))
  (get-user-stake user)
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (get-proposal-info proposal-id)
    proposal-data
    (let ((current-block stacks-block-height)
          (end-block (get end-block proposal-data)))
      (and (< current-block end-block) (not (get executed proposal-data))))
    false
  )
)

(define-read-only (is-proposal-passed (proposal-id uint))
  (match (get-proposal-info proposal-id)
    proposal-data
    (let ((votes-for (get votes-for proposal-data))
          (votes-against (get votes-against proposal-data))
          (total-votes (+ votes-for votes-against))
          (required-quorum (/ (* (calculate-total-voting-power) (var-get quorum-percentage)) u100)))
      (and 
        (>= total-votes required-quorum)
        (> votes-for votes-against)
        (>= stacks-block-height (get end-block proposal-data))
      ))
    false
  )
)

(define-read-only (calculate-total-voting-power)
  u10000
)

(define-read-only (can-execute-proposal (proposal-id uint))
  (match (get-proposal-info proposal-id)
    proposal-data
    (and 
      (is-proposal-passed proposal-id)
      (not (get executed proposal-data))
      (>= stacks-block-height (get executable-at proposal-data))
    )
    false
  )
)

(define-public (stake-tokens (amount uint))
  (let ((current-stake (get-user-stake tx-sender)))
    (begin
      (map-set user-stakes tx-sender (+ current-stake amount))
      (ok true)
    )
  )
)

(define-public (unstake-tokens (amount uint))
  (let ((current-stake (get-user-stake tx-sender)))
    (asserts! (>= current-stake amount) err-insufficient-stake)
    (begin
      (map-set user-stakes tx-sender (- current-stake amount))
      (ok true)
    )
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target (optional principal))
  (amount uint)
)
  (let (
    (user-stake (get-user-stake tx-sender))
    (proposal-id (+ (var-get proposal-counter) u1))
    (current-block stacks-block-height)
    (end-block (+ current-block (var-get voting-period)))
    (executable-at (+ end-block (var-get execution-delay)))
  )
    (asserts! (>= user-stake (var-get min-stake-required)) err-insufficient-stake)
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      target: target,
      amount: amount,
      votes-for: u0,
      votes-against: u0,
      start-block: current-block,
      end-block: end-block,
      executed: false,
      executable-at: executable-at
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (user-stake (get-user-stake tx-sender))
    (proposal-data (unwrap! (get-proposal-info proposal-id) err-proposal-not-found))
  )
    (asserts! (> user-stake u0) err-no-stake)
    (asserts! (is-proposal-active proposal-id) err-proposal-not-active)
    (asserts! (is-none (get-user-vote proposal-id tx-sender)) err-already-voted)
    
    (map-set user-votes 
      {proposal-id: proposal-id, voter: tx-sender} 
      {vote: vote-for, amount: user-stake}
    )
    
    (if vote-for
      (map-set proposals proposal-id 
        (merge proposal-data {votes-for: (+ (get votes-for proposal-data) user-stake)})
      )
      (map-set proposals proposal-id 
        (merge proposal-data {votes-against: (+ (get votes-against proposal-data) user-stake)})
      )
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (get-proposal-info proposal-id) err-proposal-not-found)))
    (asserts! (can-execute-proposal proposal-id) err-proposal-not-passed)
    (asserts! (not (get executed proposal-data)) err-proposal-already-executed)
    
    (map-set proposals proposal-id (merge proposal-data {executed: true}))
    
    (match (get target proposal-data)
      target-principal
      (begin
        (try! (as-contract (stx-transfer? (get amount proposal-data) tx-sender target-principal)))
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (set-min-stake (new-stake uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-stake-required new-stake)
    (ok true)
  )
)

(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-period u0) err-invalid-voting-period)
    (var-set voting-period new-period)
    (ok true)
  )
)

(define-public (set-execution-delay (new-delay uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set execution-delay new-delay)
    (ok true)
  )
)

(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-quorum u100) err-invalid-voting-period)
    (var-set quorum-percentage new-quorum)
    (ok true)
  )
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (get-proposal-info proposal-id)
    proposal-data
    (let ((current-block stacks-block-height)
          (end-block (get end-block proposal-data))
          (executed (get executed proposal-data)))
      (if executed
        "executed"
        (if (< current-block end-block)
          "active"
          (if (is-proposal-passed proposal-id)
            "passed"
            "rejected"
          )
        )
      )
    )
    "not-found"
  )
)

(define-read-only (get-governance-stats)
  {
    total-proposals: (var-get proposal-counter),
    min-stake: (var-get min-stake-required),
    voting-period-blocks: (var-get voting-period),
    execution-delay-blocks: (var-get execution-delay),
    quorum-percentage: (var-get quorum-percentage)
  }
)


(define-map proposal-comments
  {proposal-id: uint, comment-id: uint}
  {
    commenter: principal,
    content: (string-ascii 280),
    block-height: uint,
    timestamp: uint
  }
)

(define-map proposal-comment-count uint uint)

(define-public (add-comment (proposal-id uint) (content (string-ascii 280)))
  (let (
    (user-stake (get-user-stake tx-sender))
    (comment-id (+ (var-get comment-counter) u1))
    (current-block stacks-block-height)
  )
    (asserts! (is-some (get-proposal-info proposal-id)) err-proposal-not-found)
    (asserts! (> user-stake u0) err-no-stake)
    (asserts! (and (> (len content) u0) (<= (len content) u280)) err-invalid-comment-length)
    
    (map-set proposal-comments
      {proposal-id: proposal-id, comment-id: comment-id}
      {
        commenter: tx-sender,
        content: content,
        block-height: current-block,
        timestamp: stacks-block-height
      }
    )
    
    (let ((current-count (default-to u0 (map-get? proposal-comment-count proposal-id))))
      (map-set proposal-comment-count proposal-id (+ current-count u1))
    )
    
    (var-set comment-counter comment-id)
    (ok comment-id)
  )
)

(define-read-only (get-comment (proposal-id uint) (comment-id uint))
  (map-get? proposal-comments {proposal-id: proposal-id, comment-id: comment-id})
)

(define-read-only (get-proposal-comment-count (proposal-id uint))
  (default-to u0 (map-get? proposal-comment-count proposal-id))
)

(define-read-only (get-total-comments)
  (var-get comment-counter)
)

(define-read-only (get-recent-comments (proposal-id uint) (limit uint))
  (let ((total-comments (get-proposal-comment-count proposal-id)))
    (if (> total-comments u0)
      (let ((start-id (if (> total-comments limit) (- total-comments limit) u1)))
        (map get-comment-wrapper 
          (generate-comment-ids proposal-id start-id total-comments)
        )
      )
      (list)
    )
  )
)

(define-private (get-comment-wrapper (comment-data {proposal-id: uint, comment-id: uint}))
  (get-comment (get proposal-id comment-data) (get comment-id comment-data))
)

(define-private (generate-comment-ids (proposal-id uint) (start uint) (end uint))
  (map make-comment-id-tuple (list u1 u2 u3 u4 u5))
)

(define-private (make-comment-id-tuple (index uint))
  {proposal-id: u1, comment-id: index}
)


(define-read-only (get-delegate (delegator principal))
  (map-get? user-delegates delegator)
)

(define-read-only (get-voting-power (user principal))
  (+ (get-user-stake user) (default-to u0 (map-get? delegate-power user)))
)

(define-read-only (get-delegators (delegate principal))
  (default-to (list) (map-get? delegator-list delegate))
)

(define-public (delegate-to (delegate principal))
  (let ((current-delegate (get-delegate tx-sender))
        (delegator-stake (get-user-stake tx-sender)))
    (asserts! (not (is-eq tx-sender delegate)) err-self-delegation)
    (asserts! (> delegator-stake u0) err-no-stake)
    
    (match current-delegate
      old-delegate (begin
        (map-set delegate-power old-delegate 
          (- (get-voting-power old-delegate) delegator-stake))
        (map-set delegator-list old-delegate 
          (filter-delegator (get-delegators old-delegate) tx-sender))
      )
      true
    )
    
    (map-set user-delegates tx-sender delegate)
    (map-set delegate-power delegate (+ (get-voting-power delegate) delegator-stake))
    (map-set delegator-list delegate 
      (unwrap! (as-max-len? (append (get-delegators delegate) tx-sender) u50) 
        err-invalid-delegate))
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let ((current-delegate (unwrap! (get-delegate tx-sender) err-delegation-not-found))
        (delegator-stake (get-user-stake tx-sender)))
    (map-delete user-delegates tx-sender)
    (map-set delegate-power current-delegate 
      (- (get-voting-power current-delegate) delegator-stake))
    (map-set delegator-list current-delegate 
      (filter-delegator (get-delegators current-delegate) tx-sender))
    (ok true)
  )
)

(define-public (delegate-vote (proposal-id uint) (vote-for bool))
  (let ((voting-power (get-voting-power tx-sender))
        (proposal-data (unwrap! (get-proposal-info proposal-id) err-proposal-not-found)))
    (asserts! (> voting-power u0) err-no-stake)
    (asserts! (is-proposal-active proposal-id) err-proposal-not-active)
    (asserts! (is-none (get-user-vote proposal-id tx-sender)) err-already-voted)
    
    (map-set user-votes 
      {proposal-id: proposal-id, voter: tx-sender} 
      {vote: vote-for, amount: voting-power})
    
    (if vote-for
      (map-set proposals proposal-id 
        (merge proposal-data {votes-for: (+ (get votes-for proposal-data) voting-power)}))
      (map-set proposals proposal-id 
        (merge proposal-data {votes-against: (+ (get votes-against proposal-data) voting-power)})))
    (ok true)
  )
)

(define-private (filter-delegator (delegators (list 50 principal)) (to-remove principal))
  (filter is-not-target delegators)
)

(define-private (is-not-target (delegator principal))
  (not (is-eq delegator tx-sender))
)