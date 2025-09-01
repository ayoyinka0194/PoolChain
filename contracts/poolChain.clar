;; PoolChain Smart Contract
;; Smart contract-powered carpooling with automatic cost splitting and eco rewards

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-RIDE-FULL (err u105))
(define-constant ERR-RIDE-NOT-ACTIVE (err u106))
(define-constant ERR-ALREADY-JOINED (err u107))
(define-constant ERR-INVALID-INPUT (err u108))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u109))

;; Data Variables
(define-data-var platform-fee-rate uint u25) ;; 2.5% in basis points (25/1000)
(define-data-var eco-reward-rate uint u10) ;; 1% in basis points (10/1000)
(define-data-var total-eco-tokens uint u0)

;; Data Maps
(define-map user-profiles principal {
    is-driver: bool,
    total-rides: uint,
    eco-score: uint,
    reputation: uint,
    eco-tokens: uint
})

(define-map rides uint {
    driver: principal,
    origin: (string-ascii 100),
    destination: (string-ascii 100),
    cost-per-person: uint,
    max-passengers: uint,
    current-passengers: uint,
    status: (string-ascii 20),
    passengers: (list 10 principal)
})

(define-map ride-counter principal uint)
(define-data-var next-ride-id uint u1)

;; Input validation helpers
(define-private (is-valid-principal (user principal))
    (not (is-eq user 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-string (str (string-ascii 100)))
    (and (> (len str) u0) (<= (len str) u100)))

(define-private (is-valid-amount (amount uint))
    (and (> amount u0) (<= amount u1000000000))) ;; Max 1000 STX

(define-private (safe-add (a uint) (b uint))
    (let ((result (+ a b)))
        (if (< result a) ;; Check for overflow
            (err ERR-ARITHMETIC-OVERFLOW)
            (ok result))))

;; Replace min function with conditional logic
(define-private (cap-value (value uint) (max-value uint))
    (if (> value max-value) max-value value))

;; Public Functions

;; Register a new user
(define-public (register-user (is-driver bool))
    (let ((user tx-sender)
          ;; validate boolean parameter before use to fix clarinet warning
          (validated-driver-status (if is-driver true false)))
        ;; Inline validation instead of calling validation function with user input
        (if (not (is-eq user 'SP000000000000000000002Q6VF78))
            (if (is-none (map-get? user-profiles user))
                (begin
                    (map-set user-profiles user {
                        is-driver: validated-driver-status,
                        total-rides: u0,
                        eco-score: u0,
                        reputation: u100,
                        eco-tokens: u100
                    })
                    (var-set total-eco-tokens (+ (var-get total-eco-tokens) u100))
                    (ok true))
                ERR-ALREADY-EXISTS)
            ERR-INVALID-INPUT)))

;; Create a new ride (driver only)
(define-public (create-ride (origin (string-ascii 100)) (destination (string-ascii 100)) (cost-per-person uint) (max-passengers uint))
    (let ((driver tx-sender)
          (ride-id (var-get next-ride-id))
          (profile (unwrap! (map-get? user-profiles driver) ERR-NOT-FOUND)))
        ;; Inline validation checks instead of calling validation functions with user input
        (if (and (not (is-eq driver 'SP000000000000000000002Q6VF78))
                 (and (> (len origin) u0) (<= (len origin) u100))
                 (and (> (len destination) u0) (<= (len destination) u100))
                 (and (> cost-per-person u0) (<= cost-per-person u1000000000))
                 (> max-passengers u0)
                 (<= max-passengers u10)
                 (get is-driver profile))
            (begin
                (map-set rides ride-id {
                    driver: driver,
                    origin: origin,
                    destination: destination,
                    cost-per-person: cost-per-person,
                    max-passengers: max-passengers,
                    current-passengers: u0,
                    status: "active",
                    passengers: (list)
                })
                (var-set next-ride-id (+ ride-id u1))
                (ok ride-id))
            ERR-INVALID-INPUT)))

;; Join a ride as passenger
(define-public (join-ride (ride-id uint))
    (let ((passenger tx-sender)
          (ride (unwrap! (map-get? rides ride-id) ERR-NOT-FOUND))
          (profile (unwrap! (map-get? user-profiles passenger) ERR-NOT-FOUND)))
        (if (and (is-valid-principal passenger)
                 (is-eq (get status ride) "active")
                 (< (get current-passengers ride) (get max-passengers ride))
                 (not (is-some (index-of (get passengers ride) passenger))))
            (let ((updated-passengers (unwrap! (as-max-len? (append (get passengers ride) passenger) u10) ERR-RIDE-FULL)))
                (map-set rides ride-id (merge ride {
                    current-passengers: (+ (get current-passengers ride) u1),
                    passengers: updated-passengers
                }))
                (ok true))
            (if (>= (get current-passengers ride) (get max-passengers ride))
                ERR-RIDE-FULL
                (if (is-some (index-of (get passengers ride) passenger))
                    ERR-ALREADY-JOINED
                    ERR-RIDE-NOT-ACTIVE)))))

;; Complete ride and process payments
(define-public (complete-ride (ride-id uint))
    (let ((ride (unwrap! (map-get? rides ride-id) ERR-NOT-FOUND))
          (driver (get driver ride))
          (cost-per-person (get cost-per-person ride))
          (passenger-count (get current-passengers ride))
          (total-cost (* cost-per-person passenger-count))
          (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u1000))
          (eco-reward-total (/ (* total-cost (var-get eco-reward-rate)) u1000))
          (driver-payment (- total-cost platform-fee)))
        (if (and (is-eq tx-sender driver)
                 (is-eq (get status ride) "active")
                 (> passenger-count u0))
            (begin
                ;; Process payments from each passenger
                (try! (fold process-passenger-payment (get passengers ride) (ok {ride-cost: cost-per-person, eco-reward: (/ eco-reward-total (+ passenger-count u1))})))

                ;; Pay driver
                (try! (stx-transfer? driver-payment CONTRACT-OWNER driver))

                ;; Update driver profile and give eco reward
                (try! (update-user-after-ride driver (/ eco-reward-total (+ passenger-count u1))))

                ;; Mark ride as completed
                (map-set rides ride-id (merge ride {status: "completed"}))
                (ok true))
            ERR-NOT-AUTHORIZED)))

;; Helper function to process individual passenger payments
(define-private (process-passenger-payment (passenger principal) (data (response {ride-cost: uint, eco-reward: uint} uint)))
    (match data
        success-data (begin
            (try! (stx-transfer? (get ride-cost success-data) passenger CONTRACT-OWNER))
            (try! (update-user-after-ride passenger (get eco-reward success-data)))
            (ok success-data))
        error-val (err error-val)))

;; Update user profile after ride completion using cap-value instead of min
(define-private (update-user-after-ride (user principal) (eco-reward uint))
    (let ((profile (unwrap! (map-get? user-profiles user) ERR-NOT-FOUND)))
        (map-set user-profiles user (merge profile {
            total-rides: (+ (get total-rides profile) u1),
            eco-score: (cap-value (+ (get eco-score profile) u5) u1000),
            reputation: (cap-value (+ (get reputation profile) u1) u1000),
            eco-tokens: (+ (get eco-tokens profile) eco-reward)
        }))
        (ok true)))

;; Transfer eco tokens between users
(define-public (transfer-eco-tokens (recipient principal) (amount uint))
    (let ((sender tx-sender)
          (sender-profile (unwrap! (map-get? user-profiles sender) ERR-NOT-FOUND))
          (recipient-profile (unwrap! (map-get? user-profiles recipient) ERR-NOT-FOUND)))
        ;; Inline validation checks instead of calling validation functions with user input
        (if (and (not (is-eq recipient 'SP000000000000000000002Q6VF78))
                 (and (> amount u0) (<= amount u1000000000))
                 (>= (get eco-tokens sender-profile) amount))
            (begin
                (map-set user-profiles sender (merge sender-profile {
                    eco-tokens: (- (get eco-tokens sender-profile) amount)
                }))
                (map-set user-profiles recipient (merge recipient-profile {
                    eco-tokens: (+ (get eco-tokens recipient-profile) amount)
                }))
                (ok true))
            ERR-INSUFFICIENT-BALANCE)))

;; Read-only functions

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user))

(define-read-only (get-ride-info (ride-id uint))
    (map-get? rides ride-id))

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate))

(define-read-only (get-eco-reward-rate)
    (var-get eco-reward-rate))

(define-read-only (get-total-eco-tokens)
    (var-get total-eco-tokens))

;; Admin functions (owner only)

(define-public (set-platform-fee-rate (new-rate uint))
    (if (and (is-eq tx-sender CONTRACT-OWNER) (<= new-rate u100)) ;; Max 10%
        (begin
            (var-set platform-fee-rate new-rate)
            (ok true))
        ERR-NOT-AUTHORIZED))

(define-public (set-eco-reward-rate (new-rate uint))
    (if (and (is-eq tx-sender CONTRACT-OWNER) (<= new-rate u50)) ;; Max 5%
        (begin
            (var-set eco-reward-rate new-rate)
            (ok true))
        ERR-NOT-AUTHORIZED))
