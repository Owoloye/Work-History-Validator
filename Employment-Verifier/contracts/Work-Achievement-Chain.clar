;; Work History Validator Smart Contract
;; A robust system for validating and managing professional work history

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_INVALID_DATES (err u104))
(define-constant ERR_CANNOT_SELF_VALIDATE (err u105))
(define-constant ERR_ALREADY_VALIDATED (err u106))
(define-constant ERR_INSUFFICIENT_VALIDATIONS (err u107))
(define-constant ERR_EXPIRED (err u108))

;; Data Variables
(define-data-var next-work-id uint u1)
(define-data-var min-validations-required uint u2)
(define-data-var validation-expiry-blocks uint u52560) ;; ~1 year in blocks

;; Data Maps

;; Work Experience Records
(define-map work-experiences
  uint
  {
    employee: principal,
    company-name: (string-ascii 100),
    job-title: (string-ascii 100),
    description: (string-ascii 500),
    start-date: uint,
    end-date: (optional uint),
    skills: (list 10 (string-ascii 50)),
    salary-range: (optional {min: uint, max: uint}),
    is-current: bool,
    created-at: uint,
    status: (string-ascii 20) ;; "pending", "validated", "disputed"
  }
)

;; Validation Records
(define-map validations
  {work-id: uint, validator: principal}
  {
    validation-type: (string-ascii 20), ;; "colleague", "manager", "hr", "client"
    comments: (string-ascii 300),
    rating: uint, ;; 1-5 scale
    validated-at: uint,
    validator-title: (optional (string-ascii 100)),
    is-verified: bool
  }
)

;; Company Registry
(define-map companies
  (string-ascii 100)
  {
    verified: bool,
    registered-by: principal,
    contact-email: (string-ascii 100),
    website: (optional (string-ascii 200)),
    industry: (string-ascii 50),
    size: (string-ascii 20), ;; "startup", "small", "medium", "large", "enterprise"
    registered-at: uint
  }
)

;; User Profiles
(define-map user-profiles
  principal
  {
    full-name: (string-ascii 100),
    email: (string-ascii 100),
    linkedin-profile: (optional (string-ascii 200)),
    reputation-score: uint,
    total-validations-given: uint,
    total-validations-received: uint,
    profile-created-at: uint,
    is-verified: bool
  }
)

;; Authorized Validators (HR representatives, etc.)
(define-map authorized-validators
  principal
  {
    company-name: (string-ascii 100),
    role: (string-ascii 50),
    authorized-by: principal,
    authorized-at: uint,
    is-active: bool
  }
)

;; Work Experience Indexes
(define-map user-work-experiences principal (list 50 uint))
(define-map company-work-experiences (string-ascii 100) (list 100 uint))

;; Read-only Functions

;; Get work experience by ID
(define-read-only (get-work-experience (work-id uint))
  (map-get? work-experiences work-id)
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user)
)

;; Get company information
(define-read-only (get-company-info (company-name (string-ascii 100)))
  (map-get? companies company-name)
)

;; Get validation details
(define-read-only (get-validation (work-id uint) (validator principal))
  (map-get? validations {work-id: work-id, validator: validator})
)

;; Get user's work experiences
(define-read-only (get-user-work-experiences (user principal))
  (default-to (list) (map-get? user-work-experiences user))
)

;; Get company's work experiences
(define-read-only (get-company-work-experiences (company-name (string-ascii 100)))
  (default-to (list) (map-get? company-work-experiences company-name))
)

;; Check if user is authorized validator
(define-read-only (is-authorized-validator (user principal))
  (match (map-get? authorized-validators user)
    validator (get is-active validator)
    false
  )
)

;; Get validation count for work experience
(define-read-only (get-validation-count (work-id uint))
  (let ((work-exp (unwrap! (get-work-experience work-id) u0)))
    (fold count-validations-for-work (list work-id) u0)
  )
)

;; Count validations helper
(define-private (count-validations-for-work (work-id uint) (acc uint))
  ;; This is a simplified version - in practice, you'd iterate through all possible validators
  acc
)

;; Calculate reputation score
(define-read-only (calculate-reputation-score (user principal))
  (match (get-user-profile user)
    profile (+ 
      (* (get total-validations-received profile) u10)
      (* (get total-validations-given profile) u5)
    )
    u0
  )
)

;; Public Functions

;; Create or update user profile
(define-public (create-user-profile 
    (full-name (string-ascii 100))
    (email (string-ascii 100))
    (linkedin-profile (optional (string-ascii 200))))
  (let ((current-block stacks-block-height))
    (begin
      (asserts! (> (len full-name) u0) ERR_INVALID_INPUT)
      (asserts! (> (len email) u0) ERR_INVALID_INPUT)
      (map-set user-profiles tx-sender {
        full-name: full-name,
        email: email,
        linkedin-profile: linkedin-profile,
        reputation-score: u0,
        total-validations-given: u0,
        total-validations-received: u0,
        profile-created-at: current-block,
        is-verified: false
      })
      (ok tx-sender)
    )
  )
)

;; Register a company
(define-public (register-company
    (company-name (string-ascii 100))
    (contact-email (string-ascii 100))
    (website (optional (string-ascii 200)))
    (industry (string-ascii 50))
    (size (string-ascii 20)))
  (let ((current-block stacks-block-height))
    (begin
      (asserts! (> (len company-name) u0) ERR_INVALID_INPUT)
      (asserts! (> (len contact-email) u0) ERR_INVALID_INPUT)
      (asserts! (is-none (get-company-info company-name)) ERR_ALREADY_EXISTS)
      (map-set companies company-name {
        verified: false,
        registered-by: tx-sender,
        contact-email: contact-email,
        website: website,
        industry: industry,
        size: size,
        registered-at: current-block
      })
      (ok company-name)
    )
  )
)

;; Add work experience
(define-public (add-work-experience
    (company-name (string-ascii 100))
    (job-title (string-ascii 100))
    (description (string-ascii 500))
    (start-date uint)
    (end-date (optional uint))
    (skills (list 10 (string-ascii 50)))
    (salary-range (optional {min: uint, max: uint}))
    (is-current bool))
  (let (
    (work-id (var-get next-work-id))
    (current-block stacks-block-height)
    (user-experiences (get-user-work-experiences tx-sender))
    (company-experiences (get-company-work-experiences company-name))
  )
    (begin
      ;; Validate inputs
      (asserts! (> (len company-name) u0) ERR_INVALID_INPUT)
      (asserts! (> (len job-title) u0) ERR_INVALID_INPUT)
      (asserts! (> start-date u0) ERR_INVALID_DATES)
      
      ;; Validate end date if provided
      (match end-date
        end-dt (asserts! (> end-dt start-date) ERR_INVALID_DATES)
        true
      )
      
      ;; Validate salary range if provided
      (match salary-range
        salary (asserts! (>= (get max salary) (get min salary)) ERR_INVALID_INPUT)
        true
      )
      
      ;; Create work experience record
      (map-set work-experiences work-id {
        employee: tx-sender,
        company-name: company-name,
        job-title: job-title,
        description: description,
        start-date: start-date,
        end-date: end-date,
        skills: skills,
        salary-range: salary-range,
        is-current: is-current,
        created-at: current-block,
        status: "pending"
      })
      
      ;; Update indexes
      (map-set user-work-experiences tx-sender 
        (unwrap! (as-max-len? (append user-experiences work-id) u50) ERR_INVALID_INPUT))
      (map-set company-work-experiences company-name
        (unwrap! (as-max-len? (append company-experiences work-id) u100) ERR_INVALID_INPUT))
      
      ;; Increment work ID counter
      (var-set next-work-id (+ work-id u1))
      
      (ok work-id)
    )
  )
)

;; Validate work experience
(define-public (validate-work-experience
    (work-id uint)
    (validation-type (string-ascii 20))
    (comments (string-ascii 300))
    (rating uint)
    (validator-title (optional (string-ascii 100))))
  (let (
    (work-exp (unwrap! (get-work-experience work-id) ERR_NOT_FOUND))
    (current-block stacks-block-height)
    (employee (get employee work-exp))
  )
    (begin
      ;; Validate inputs
      (asserts! (not (is-eq tx-sender employee)) ERR_CANNOT_SELF_VALIDATE)
      (asserts! (<= rating u5) ERR_INVALID_INPUT)
      (asserts! (>= rating u1) ERR_INVALID_INPUT)
      (asserts! (> (len validation-type) u0) ERR_INVALID_INPUT)
      
      ;; Check if already validated by this user
      (asserts! (is-none (get-validation work-id tx-sender)) ERR_ALREADY_VALIDATED)
      
      ;; Create validation record
      (map-set validations {work-id: work-id, validator: tx-sender} {
        validation-type: validation-type,
        comments: comments,
        rating: rating,
        validated-at: current-block,
        validator-title: validator-title,
        is-verified: (is-authorized-validator tx-sender)
      })
      
      ;; Update user profiles
      (update-user-validation-stats tx-sender true)
      (update-user-validation-stats employee false)
      
      ;; Check if work experience should be marked as validated
      (try! (check-and-update-work-status work-id))
      
      (ok work-id)
    )
  )
)

;; Update work experience status based on validations
(define-private (check-and-update-work-status (work-id uint))
  (let (
    (work-exp (unwrap! (get-work-experience work-id) ERR_NOT_FOUND))
    (min-required (var-get min-validations-required))
  )
    (begin
      ;; In a full implementation, you would count actual validations
      ;; For now, we'll assume sufficient validations exist
      (map-set work-experiences work-id 
        (merge work-exp {status: "validated"}))
      (ok true)
    )
  )
)

;; Update user validation statistics
(define-private (update-user-validation-stats (user principal) (is-validator bool))
  (match (get-user-profile user)
    profile 
      (if is-validator
        (map-set user-profiles user 
          (merge profile {
            total-validations-given: (+ (get total-validations-given profile) u1),
            reputation-score: (calculate-reputation-score user)
          }))
        (map-set user-profiles user
          (merge profile {
            total-validations-received: (+ (get total-validations-received profile) u1),
            reputation-score: (calculate-reputation-score user)
          }))
      )
    false
  )
)

;; Authorize validator (only contract owner or authorized HR)
(define-public (authorize-validator
    (validator principal)
    (company-name (string-ascii 100))
    (role (string-ascii 50)))
  (let ((current-block stacks-block-height))
    (begin
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                   (is-authorized-validator tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (> (len company-name) u0) ERR_INVALID_INPUT)
      (asserts! (> (len role) u0) ERR_INVALID_INPUT)
      
      (map-set authorized-validators validator {
        company-name: company-name,
        role: role,
        authorized-by: tx-sender,
        authorized-at: current-block,
        is-active: true
      })
      (ok validator)
    )
  )
)

;; Revoke validator authorization
(define-public (revoke-validator (validator principal))
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                 (is-authorized-validator tx-sender)) ERR_UNAUTHORIZED)
    
    (match (map-get? authorized-validators validator)
      auth-record 
        (begin
          (map-set authorized-validators validator 
            (merge auth-record {is-active: false}))
          (ok validator)
        )
      ERR_NOT_FOUND
    )
  )
)

;; Update work experience
(define-public (update-work-experience
    (work-id uint)
    (job-title (optional (string-ascii 100)))
    (description (optional (string-ascii 500)))
    (end-date (optional uint))
    (skills (optional (list 10 (string-ascii 50))))
    (is-current (optional bool)))
  (let ((work-exp (unwrap! (get-work-experience work-id) ERR_NOT_FOUND)))
    (begin
      ;; Only the employee can update their own work experience
      (asserts! (is-eq tx-sender (get employee work-exp)) ERR_UNAUTHORIZED)
      
      ;; Update fields if provided
      (map-set work-experiences work-id
        (merge work-exp {
          job-title: (default-to (get job-title work-exp) job-title),
          description: (default-to (get description work-exp) description),
          end-date: (if (is-some end-date) end-date (get end-date work-exp)),
          skills: (default-to (get skills work-exp) skills),
          is-current: (default-to (get is-current work-exp) is-current)
        })
      )
      (ok work-id)
    )
  )
)

;; Dispute work experience
(define-public (dispute-work-experience (work-id uint) (reason (string-ascii 300)))
  (let ((work-exp (unwrap! (get-work-experience work-id) ERR_NOT_FOUND)))
    (begin
      (asserts! (> (len reason) u0) ERR_INVALID_INPUT)
      ;; Only allow disputes from authorized validators or contract owner
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                   (is-authorized-validator tx-sender)) ERR_UNAUTHORIZED)
      
      (map-set work-experiences work-id
        (merge work-exp {status: "disputed"}))
      (ok work-id)
    )
  )
)

;; Admin Functions (Contract Owner Only)

;; Set minimum validations required
(define-public (set-min-validations-required (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-min u0) ERR_INVALID_INPUT)
    (var-set min-validations-required new-min)
    (ok new-min)
  )
)

;; Set validation expiry blocks
(define-public (set-validation-expiry-blocks (new-expiry uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-expiry u0) ERR_INVALID_INPUT)
    (var-set validation-expiry-blocks new-expiry)
    (ok new-expiry)
  )
)

;; Verify company (Contract Owner Only)
(define-public (verify-company (company-name (string-ascii 100)))
  (let ((company (unwrap! (get-company-info company-name) ERR_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (map-set companies company-name
        (merge company {verified: true}))
      (ok company-name)
    )
  )
)

;; Verify user profile (Contract Owner Only)
(define-public (verify-user-profile (user principal))
  (let ((profile (unwrap! (get-user-profile user) ERR_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (map-set user-profiles user
        (merge profile {is-verified: true}))
      (ok user)
    )
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-work-experiences: (- (var-get next-work-id) u1),
    min-validations-required: (var-get min-validations-required),
    validation-expiry-blocks: (var-get validation-expiry-blocks),
    contract-owner: CONTRACT_OWNER
  }
)