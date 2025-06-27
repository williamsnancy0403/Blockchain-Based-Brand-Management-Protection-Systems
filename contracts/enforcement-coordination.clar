;; Enforcement Coordination Contract
;; Coordinates brand enforcement actions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_INVALID_ACTION (err u502))

;; Data Variables
(define-data-var next-action-id uint u1)

;; Data Maps
(define-map enforcement-actions
  { action-id: uint }
  {
    report-id: uint,
    action-type: (string-ascii 50),
    assigned-to: principal,
    status: (string-ascii 20),
    priority: (string-ascii 10),
    created-at: uint,
    completed-at: (optional uint),
    notes: (string-ascii 500)
  }
)

(define-map action-outcomes
  { action-id: uint }
  {
    successful: bool,
    resolution: (string-ascii 200),
    follow-up-required: bool
  }
)

(define-map assignee-actions
  { assignee: principal }
  { active-count: uint, completed-count: uint }
)

;; Public Functions
(define-public (create-enforcement-action (report-id uint) (action-type (string-ascii 50)) (assigned-to principal) (priority (string-ascii 10)) (notes (string-ascii 500)))
  (let
    (
      (action-id (var-get next-action-id))
      (assignee-data (default-to { active-count: u0, completed-count: u0 } (map-get? assignee-actions { assignee: assigned-to })))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set enforcement-actions
      { action-id: action-id }
      {
        report-id: report-id,
        action-type: action-type,
        assigned-to: assigned-to,
        status: "assigned",
        priority: priority,
        created-at: block-height,
        completed-at: none,
        notes: notes
      }
    )
    (map-set assignee-actions
      { assignee: assigned-to }
      (merge assignee-data { active-count: (+ (get active-count assignee-data) u1) })
    )
    (var-set next-action-id (+ action-id u1))
    (ok action-id)
  )
)

(define-public (update-action-status (action-id uint) (new-status (string-ascii 20)))
  (let
    (
      (action (unwrap! (map-get? enforcement-actions { action-id: action-id }) ERR_NOT_FOUND))
      (assignee (get assigned-to action))
      (assignee-data (default-to { active-count: u0, completed-count: u0 } (map-get? assignee-actions { assignee: assignee })))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender assignee)) ERR_UNAUTHORIZED)
    (if (is-eq new-status "completed")
      (begin
        (map-set enforcement-actions
          { action-id: action-id }
          (merge action { status: new-status, completed-at: (some block-height) })
        )
        (map-set assignee-actions
          { assignee: assignee }
          {
            active-count: (if (> (get active-count assignee-data) u0) (- (get active-count assignee-data) u1) u0),
            completed-count: (+ (get completed-count assignee-data) u1)
          }
        )
      )
      (map-set enforcement-actions
        { action-id: action-id }
        (merge action { status: new-status })
      )
    )
    (ok true)
  )
)

(define-public (record-action-outcome (action-id uint) (successful bool) (resolution (string-ascii 200)) (follow-up-required bool))
  (let
    (
      (action (unwrap! (map-get? enforcement-actions { action-id: action-id }) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get assigned-to action))) ERR_UNAUTHORIZED)
    (map-set action-outcomes
      { action-id: action-id }
      {
        successful: successful,
        resolution: resolution,
        follow-up-required: follow-up-required
      }
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-enforcement-action (action-id uint))
  (map-get? enforcement-actions { action-id: action-id })
)

(define-read-only (get-action-outcome (action-id uint))
  (map-get? action-outcomes { action-id: action-id })
)

(define-read-only (get-assignee-stats (assignee principal))
  (map-get? assignee-actions { assignee: assignee })
)

(define-read-only (get-action-status (action-id uint))
  (match (map-get? enforcement-actions { action-id: action-id })
    action (get status action)
    "not-found"
  )
)

(define-read-only (get-next-action-id)
  (var-get next-action-id)
)
