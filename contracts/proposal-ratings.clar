(define-constant err-rating-unauthorized (err u400))
(define-constant err-invalid-rating (err u401))
(define-constant err-already-rated (err u402))
(define-constant err-proposal-not-executed (err u403))
(define-constant err-cannot-rate-own-proposal (err u404))
(define-constant err-proposal-not-found (err u103))

(define-map proposal-ratings 
  {proposal-id: uint, rater: principal} 
  {rating: uint, comment: (string-ascii 140)}
)

(define-map proposal-rating-stats 
  uint 
  {
    total-ratings: uint,
    sum-ratings: uint,
    average-rating: uint
  }
)

(define-map proposer-reputation 
  principal 
  {
    total-proposals: uint,
    rated-proposals: uint,
    reputation-score: uint,
    last-updated: uint
  }
)

(define-read-only (get-proposal-rating-stats (proposal-id uint))
  (default-to 
    {total-ratings: u0, sum-ratings: u0, average-rating: u0}
    (map-get? proposal-rating-stats proposal-id)
  )
)

(define-read-only (get-user-rating (proposal-id uint) (rater principal))
  (map-get? proposal-ratings {proposal-id: proposal-id, rater: rater})
)

(define-read-only (get-proposer-reputation (proposer principal))
  (default-to
    {total-proposals: u0, rated-proposals: u0, reputation-score: u0, last-updated: u0}
    (map-get? proposer-reputation proposer)
  )
)

(define-read-only (calculate-reputation-score (proposer principal))
  (let ((rep-data (get-proposer-reputation proposer)))
    (if (> (get rated-proposals rep-data) u0)
      (/ (get reputation-score rep-data) (get rated-proposals rep-data))
      u0
    )
  )
)

(define-public (rate-proposal 
  (proposal-id uint) 
  (rating uint) 
  (comment (string-ascii 140))
)
  (let (
    (proposal-info (unwrap! 
      (contract-call? .Simple-DAO-Governance-System get-proposal-info proposal-id) 
      err-proposal-not-found
    ))
    (proposer (get proposer proposal-info))
    (user-stake (contract-call? .Simple-DAO-Governance-System get-user-stake tx-sender))
  )
    (asserts! (> user-stake u0) err-rating-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (get executed proposal-info) err-proposal-not-executed)
    (asserts! (not (is-eq tx-sender proposer)) err-cannot-rate-own-proposal)
    (asserts! (is-none (get-user-rating proposal-id tx-sender)) err-already-rated)
    
    (map-set proposal-ratings 
      {proposal-id: proposal-id, rater: tx-sender}
      {rating: rating, comment: comment}
    )
    
    (let ((current-stats (get-proposal-rating-stats proposal-id)))
      (let (
        (new-total (+ (get total-ratings current-stats) u1))
        (new-sum (+ (get sum-ratings current-stats) rating))
      )
        (map-set proposal-rating-stats proposal-id {
          total-ratings: new-total,
          sum-ratings: new-sum,
          average-rating: (/ (* new-sum u100) new-total)
        })
      )
    )
    
    (let ((current-rep (get-proposer-reputation proposer)))
      (map-set proposer-reputation proposer {
        total-proposals: (get total-proposals current-rep),
        rated-proposals: (+ (get rated-proposals current-rep) u1),
        reputation-score: (+ (get reputation-score current-rep) rating),
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)
