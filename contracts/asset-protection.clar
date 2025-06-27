;; Asset Protection Contract
;; Protects brand assets through blockchain registration

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_ALREADY_EXISTS (err u201))
(define-constant ERR_NOT_FOUND (err u202))
(define-constant ERR_INVALID_OWNER (err u203))

;; Data Variables
(define-data-var next-asset-id uint u1)

;; Data Maps
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    asset-type: (string-ascii 50),
    created-at: uint,
    protected: bool,
    hash: (buff 32)
  }
)

(define-map asset-names
  { name: (string-ascii 100) }
  { asset-id: uint }
)

(define-map owner-assets
  { owner: principal, asset-id: uint }
  { registered: bool }
)

;; Public Functions
(define-public (register-asset (name (string-ascii 100)) (description (string-ascii 500)) (asset-type (string-ascii 50)) (hash (buff 32)))
  (let
    (
      (asset-id (var-get next-asset-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? asset-names { name: name })) ERR_ALREADY_EXISTS)
    (map-set assets
      { asset-id: asset-id }
      {
        owner: caller,
        name: name,
        description: description,
        asset-type: asset-type,
        created-at: block-height,
        protected: true,
        hash: hash
      }
    )
    (map-set asset-names { name: name } { asset-id: asset-id })
    (map-set owner-assets { owner: caller, asset-id: asset-id } { registered: true })
    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

(define-public (transfer-asset (asset-id uint) (new-owner principal))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) ERR_NOT_FOUND))
      (current-owner (get owner asset))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (map-set assets
      { asset-id: asset-id }
      (merge asset { owner: new-owner })
    )
    (map-delete owner-assets { owner: current-owner, asset-id: asset-id })
    (map-set owner-assets { owner: new-owner, asset-id: asset-id } { registered: true })
    (ok true)
  )
)

(define-public (update-protection-status (asset-id uint) (protected bool))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner asset)) ERR_UNAUTHORIZED)
    (map-set assets
      { asset-id: asset-id }
      (merge asset { protected: protected })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (get-asset-by-name (name (string-ascii 100)))
  (match (map-get? asset-names { name: name })
    asset-data (map-get? assets { asset-id: (get asset-id asset-data) })
    none
  )
)

(define-read-only (is-asset-owner (asset-id uint) (address principal))
  (match (map-get? assets { asset-id: asset-id })
    asset (is-eq (get owner asset) address)
    false
  )
)

(define-read-only (is-asset-protected (asset-id uint))
  (match (map-get? assets { asset-id: asset-id })
    asset (get protected asset)
    false
  )
)

(define-read-only (get-next-asset-id)
  (var-get next-asset-id)
)
