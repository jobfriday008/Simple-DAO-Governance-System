(define-constant err-proposal-not-found (err u103))
(define-constant err-proposal-still-active (err u500))
(define-constant err-proposal-already-cleaned (err u501))
(define-constant err-insufficient-age (err u502))
(define-constant err-proposal-executed (err u503))

(define-constant cleanup-reward u100)
(define-constant min-expiry-blocks u2016)

(define-map cleaned-proposals uint bool)
(define-map cleanup-actions principal uint)
(define-map total-cleanups principal uint)

(define-data-var total-cleaned uint u0)
(define-data-var cleanup-counter uint u0)

(define-read-only (get-cleanup-stats (user principal))
  {
    total-actions: (default-to u0 (map-get? total-cleanups user)),
    rewards-earned: (* (default-to u0 (map-get? total-cleanups user)) cleanup-reward)
  }
)

(define-read-only (is-proposal-cleaned (proposal-id uint))
  (default-to false (map-get? cleaned-proposals proposal-id))
)

(define-read-only (get-total-cleaned)
  (var-get total-cleaned)
)

(define-read-only (can-cleanup-proposal (proposal-id uint))
  (let (
    (proposal-info (unwrap! 
      (contract-call? .Simple-DAO-Governance-System get-proposal-info proposal-id) 
      false
    ))
  )
    (and
      (not (get executed proposal-info))
      (>= stacks-block-height (+ (get end-block proposal-info) min-expiry-blocks))
      (not (is-proposal-cleaned proposal-id))
      (not (contract-call? .Simple-DAO-Governance-System is-proposal-passed proposal-id))
    )
  )
)

(define-public (cleanup-proposal (proposal-id uint))
  (let (
    (proposal-info (unwrap! 
      (contract-call? .Simple-DAO-Governance-System get-proposal-info proposal-id) 
      err-proposal-not-found
    ))
    (user-cleanups (default-to u0 (map-get? total-cleanups tx-sender)))
  )
    (asserts! (not (get executed proposal-info)) err-proposal-executed)
    (asserts! (not (is-proposal-cleaned proposal-id)) err-proposal-already-cleaned)
    (asserts! 
      (>= stacks-block-height (+ (get end-block proposal-info) min-expiry-blocks)) 
      err-insufficient-age
    )
    (asserts! 
      (not (contract-call? .Simple-DAO-Governance-System is-proposal-passed proposal-id)) 
      err-proposal-still-active
    )
    
    (map-set cleaned-proposals proposal-id true)
    (map-set total-cleanups tx-sender (+ user-cleanups u1))
    (var-set total-cleaned (+ (var-get total-cleaned) u1))
    (var-set cleanup-counter (+ (var-get cleanup-counter) u1))
    
    (ok cleanup-reward)
  )
)
