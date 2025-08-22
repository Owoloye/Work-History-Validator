;; Skills Assessment & Certification Contract
;; Comprehensive system for skill testing, certification, and endorsement management

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-NOT-FOUND u101)
(define-constant ERR-ALREADY-EXISTS u102)
(define-constant ERR-INVALID-INPUT u103)
(define-constant ERR-INSUFFICIENT-SCORE u104)
(define-constant ERR-ALREADY-TAKEN u105)
(define-constant ERR-TEST-EXPIRED u106)
(define-constant ERR-ALREADY-ENDORSED u107)
(define-constant ERR-SELF-ENDORSEMENT u108)
(define-constant ERR-CERTIFICATION-EXPIRED u109)
(define-constant ERR-INSUFFICIENT-EXPERIENCE u110)
(define-constant ERR-INVALID-COMPETENCY-LEVEL u111)

;; Contract Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_QUESTIONS_PER_TEST u50)
(define-constant MIN_PASSING_SCORE u70) ;; 70% minimum
(define-constant CERTIFICATION_VALIDITY_PERIOD u525600) ;; ~10 years in blocks
(define-constant TEST_TIME_LIMIT u144) ;; ~1 day in blocks

;; Competency Levels
(define-constant COMPETENCY-BEGINNER u1)
(define-constant COMPETENCY-INTERMEDIATE u2)
(define-constant COMPETENCY-ADVANCED u3)
(define-constant COMPETENCY-EXPERT u4)

;; Skill Categories
(define-constant CATEGORY-PROGRAMMING "programming")
(define-constant CATEGORY-DATA-SCIENCE "data_science")
(define-constant CATEGORY-DESIGN "design")
(define-constant CATEGORY-MARKETING "marketing")
(define-constant CATEGORY-MANAGEMENT "management")
(define-constant CATEGORY-FINANCE "finance")

;; Data Variables
(define-data-var next-skill-id uint u1)
(define-data-var next-test-id uint u1)
(define-data-var next-certification-id uint u1)
(define-data-var next-assessment-id uint u1)
(define-data-var platform-fee uint u1000) ;; Fee for taking assessments (in microSTX)

;; Skills Registry
(define-map skills
  uint ;; skill-id
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    category: (string-ascii 50),
    created-by: principal,
    created-at: uint,
    is-active: bool,
    total-assessments: uint,
    average-score: uint
  }
)

;; Skill Tests/Assessments
(define-map skill-tests
  uint ;; test-id
  {
    skill-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 300),
    difficulty-level: uint, ;; 1-4 (beginner to expert)
    total-questions: uint,
    time-limit-blocks: uint,
    passing-score: uint,
    created-by: principal,
    created-at: uint,
    is-active: bool,
    total-attempts: uint,
    average-score: uint
  }
)

;; Test Questions (simplified structure)
(define-map test-questions
  {test-id: uint, question-number: uint}
  {
    question-text: (string-ascii 500),
    question-type: (string-ascii 20), ;; "multiple_choice", "true_false", "coding"
    correct-answer-hash: (buff 32), ;; Hash of correct answer for verification
    points: uint,
    difficulty: uint
  }
)

;; User Test Attempts
(define-map test-attempts
  uint ;; assessment-id
  {
    user: principal,
    test-id: uint,
    started-at: uint,
    completed-at: (optional uint),
    score: (optional uint),
    passed: bool,
    answers-hash: (buff 32), ;; Hash of submitted answers
    time-taken: (optional uint)
  }
)

;; User Skills Profile
(define-map user-skills
  {user: principal, skill-id: uint}
  {
    competency-level: uint,
    verified-score: uint,
    last-assessed: uint,
    total-assessments: uint,
    endorsement-count: uint,
    experience-years: uint,
    certifications: (list 10 uint)
  }
)

;; Skill Endorsements
(define-map skill-endorsements
  {user: principal, skill-id: uint, endorser: principal}
  {
    endorsement-level: uint, ;; 1-5 scale
    relationship: (string-ascii 50), ;; "colleague", "manager", "client", etc.
    comment: (string-ascii 200),
    endorser-competency: uint, ;; Endorser's competency in this skill
    endorsed-at: uint,
    is-verified: bool
  }
)

;; Professional Certifications
(define-map certifications
  uint ;; certification-id
  {
    name: (string-ascii 100),
    issuing-organization: (string-ascii 100),
    skill-id: uint,
    requirements: (string-ascii 300),
    validity-period-blocks: uint,
    created-by: principal,
    created-at: uint,
    is-active: bool
  }
)

;; User Certifications
(define-map user-certifications
  {user: principal, certification-id: uint}
  {
    issued-at: uint,
    expires-at: uint,
    verification-hash: (buff 32),
    issuer: principal,
    score-achieved: uint,
    is-valid: bool
  }
)

;; Authorized Test Creators
(define-map authorized-creators
  principal
  {
    organization: (string-ascii 100),
    expertise-areas: (list 10 (string-ascii 50)),
    authorized-by: principal,
    authorized-at: uint,
    is-active: bool
  }
)

;; User Indexes
(define-map user-skill-list principal (list 50 uint))
(define-map user-certification-list principal (list 20 uint))
(define-map skill-test-list uint (list 20 uint))

;; Helper Functions

;; Validate competency level
(define-private (is-valid-competency-level (level uint))
  (and (>= level COMPETENCY-BEGINNER) (<= level COMPETENCY-EXPERT))
)

;; Validate skill category
(define-private (is-valid-category (category (string-ascii 50)))
  (or 
    (is-eq category CATEGORY-PROGRAMMING)
    (is-eq category CATEGORY-DATA-SCIENCE)
    (is-eq category CATEGORY-DESIGN)
    (is-eq category CATEGORY-MARKETING)
    (is-eq category CATEGORY-MANAGEMENT)
    (is-eq category CATEGORY-FINANCE)
  )
)

;; Calculate weighted endorsement score
(define-private (calculate-endorsement-weight (endorser-competency uint) (endorsement-level uint))
  (/ (* endorser-competency endorsement-level) u4) ;; Max weight when expert endorses at level 5
)

;; Hash answer for verification
(define-private (hash-answer (answer (string-ascii 200)))
  (sha256 (unwrap-panic (to-consensus-buff? answer)))
)

;; Check if certification is expired
(define-private (is-certification-expired (expires-at uint))
  (> stacks-block-height expires-at)
)

;; Read-only Functions

;; Get skill information
(define-read-only (get-skill (skill-id uint))
  (map-get? skills skill-id)
)

;; Get test information
(define-read-only (get-skill-test (test-id uint))
  (map-get? skill-tests test-id)
)

;; Get user skill profile
(define-read-only (get-user-skill (user principal) (skill-id uint))
  (map-get? user-skills {user: user, skill-id: skill-id})
)

;; Get user's skills list
(define-read-only (get-user-skills-list (user principal))
  (default-to (list) (map-get? user-skill-list user))
)

;; Get endorsement details
(define-read-only (get-endorsement (user principal) (skill-id uint) (endorser principal))
  (map-get? skill-endorsements {user: user, skill-id: skill-id, endorser: endorser})
)

;; Get certification details
(define-read-only (get-certification (certification-id uint))
  (map-get? certifications certification-id)
)

;; Get user certification
(define-read-only (get-user-certification (user principal) (certification-id uint))
  (map-get? user-certifications {user: user, certification-id: certification-id})
)

;; Get test attempt details
(define-read-only (get-test-attempt (assessment-id uint))
  (map-get? test-attempts assessment-id)
)

;; Check if user is authorized creator
(define-read-only (is-authorized-creator (user principal))
  (match (map-get? authorized-creators user)
    creator (get is-active creator)
    false
  )
)

;; Helper function to get minimum of two values
(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b)
)

;; Calculate overall skill competency score
(define-read-only (calculate-skill-competency (user principal) (skill-id uint))
  (match (get-user-skill user skill-id)
    skill-profile 
      (let (
        (base-score (get verified-score skill-profile))
        (endorsement-boost (min-uint (* (get endorsement-count skill-profile) u5) u25))
        (experience-boost (min-uint (* (get experience-years skill-profile) u2) u20))
      )
        (+ base-score endorsement-boost experience-boost)
      )
    u0
  )
)

;; Public Functions

;; Create a new skill
(define-public (create-skill 
    (name (string-ascii 100))
    (description (string-ascii 300))
    (category (string-ascii 50)))
  (let (
    (skill-id (var-get next-skill-id))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validate inputs
      (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
      (asserts! (> (len description) u0) (err ERR-INVALID-INPUT))
      (asserts! (is-valid-category category) (err ERR-INVALID-INPUT))
      
      ;; Only authorized creators or contract owner can create skills
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                   (is-authorized-creator tx-sender)) (err ERR-NOT-AUTHORIZED))
      
      ;; Create skill
      (map-set skills skill-id {
        name: name,
        description: description,
        category: category,
        created-by: tx-sender,
        created-at: current-block,
        is-active: true,
        total-assessments: u0,
        average-score: u0
      })
      
      ;; Update counter
      (var-set next-skill-id (+ skill-id u1))
      
      (ok skill-id)
    )
  )
)

;; Create a skill test/assessment
(define-public (create-skill-test
    (skill-id uint)
    (name (string-ascii 100))
    (description (string-ascii 300))
    (difficulty-level uint)
    (total-questions uint)
    (time-limit-blocks uint)
    (passing-score uint))
  (let (
    (test-id (var-get next-test-id))
    (current-block stacks-block-height)
    (skill (unwrap! (get-skill skill-id) (err ERR-NOT-FOUND)))
    (existing-tests (default-to (list) (map-get? skill-test-list skill-id)))
  )
    (begin
      ;; Validate inputs
      (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
      (asserts! (is-valid-competency-level difficulty-level) (err ERR-INVALID-INPUT))
      (asserts! (and (> total-questions u0) (<= total-questions MAX_QUESTIONS_PER_TEST)) (err ERR-INVALID-INPUT))
      (asserts! (and (>= passing-score MIN_PASSING_SCORE) (<= passing-score u100)) (err ERR-INVALID-INPUT))
      (asserts! (> time-limit-blocks u0) (err ERR-INVALID-INPUT))
      
      ;; Only authorized creators can create tests
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                   (is-authorized-creator tx-sender)) (err ERR-NOT-AUTHORIZED))
      
      ;; Create test
      (map-set skill-tests test-id {
        skill-id: skill-id,
        name: name,
        description: description,
        difficulty-level: difficulty-level,
        total-questions: total-questions,
        time-limit-blocks: time-limit-blocks,
        passing-score: passing-score,
        created-by: tx-sender,
        created-at: current-block,
        is-active: true,
        total-attempts: u0,
        average-score: u0
      })
      
      ;; Update skill test list
      (map-set skill-test-list skill-id 
        (unwrap! (as-max-len? (append existing-tests test-id) u20) (err ERR-INVALID-INPUT)))
      
      ;; Update counters
      (var-set next-test-id (+ test-id u1))
      
      (ok test-id)
    )
  )
)

;; Start a skill assessment
(define-public (start-assessment (test-id uint))
  (let (
    (assessment-id (var-get next-assessment-id))
    (test (unwrap! (get-skill-test test-id) (err ERR-NOT-FOUND)))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validate test is active
      (asserts! (get is-active test) (err ERR-NOT-FOUND))
      
      ;; Pay platform fee
      (try! (stx-transfer? (var-get platform-fee) tx-sender (as-contract tx-sender)))
      
      ;; Create assessment attempt
      (map-set test-attempts assessment-id {
        user: tx-sender,
        test-id: test-id,
        started-at: current-block,
        completed-at: none,
        score: none,
        passed: false,
        answers-hash: 0x00,
        time-taken: none
      })
      
      ;; Update counter
      (var-set next-assessment-id (+ assessment-id u1))
      
      (ok assessment-id)
    )
  )
)

;; Submit assessment answers
(define-public (submit-assessment 
    (assessment-id uint)
    (answers-hash (buff 32))
    (score uint))
  (let (
    (attempt (unwrap! (get-test-attempt assessment-id) (err ERR-NOT-FOUND)))
    (test (unwrap! (get-skill-test (get test-id attempt)) (err ERR-NOT-FOUND)))
    (current-block stacks-block-height)
    (time-taken (- current-block (get started-at attempt)))
    (passed (>= score (get passing-score test)))
  )
    (begin
      ;; Validate user owns this attempt
      (asserts! (is-eq tx-sender (get user attempt)) (err ERR-NOT-AUTHORIZED))
      
      ;; Check if already completed
      (asserts! (is-none (get completed-at attempt)) (err ERR-ALREADY-TAKEN))
      
      ;; Check time limit
      (asserts! (<= time-taken (get time-limit-blocks test)) (err ERR-TEST-EXPIRED))
      
      ;; Validate score
      (asserts! (<= score u100) (err ERR-INVALID-INPUT))
      
      ;; Update attempt
      (map-set test-attempts assessment-id 
        (merge attempt {
          completed-at: (some current-block),
          score: (some score),
          passed: passed,
          answers-hash: answers-hash,
          time-taken: (some time-taken)
        }))
      
      ;; Update user skill profile if passed
      (if passed
        (try! (update-user-skill-profile tx-sender (get skill-id test) score))
        true
      )
      
      ;; Update test statistics
      (update-test-statistics (get test-id attempt) score)
      
      (ok passed)
    )
  )
)

;; Endorse a user's skill
(define-public (endorse-skill
    (user principal)
    (skill-id uint)
    (endorsement-level uint)
    (relationship (string-ascii 50))
    (comment (string-ascii 200)))
  (let (
    (current-block stacks-block-height)
    (endorser-skill (get-user-skill tx-sender skill-id))
    (user-skill (default-to 
      {competency-level: u0, verified-score: u0, last-assessed: u0, 
       total-assessments: u0, endorsement-count: u0, experience-years: u0, 
       certifications: (list)}
      (get-user-skill user skill-id)))
  )
    (begin
      ;; Validate inputs
      (asserts! (not (is-eq tx-sender user)) (err ERR-SELF-ENDORSEMENT))
      (asserts! (and (>= endorsement-level u1) (<= endorsement-level u5)) (err ERR-INVALID-INPUT))
      (asserts! (> (len relationship) u0) (err ERR-INVALID-INPUT))
      
      ;; Check if already endorsed
      (asserts! (is-none (get-endorsement user skill-id tx-sender)) (err ERR-ALREADY-ENDORSED))
      
      ;; Endorser should have some competency in the skill
      (let ((endorser-competency (if (is-some endorser-skill)
                                   (get competency-level (unwrap-panic endorser-skill))
                                   u1)))
        
        ;; Create endorsement
        (map-set skill-endorsements {user: user, skill-id: skill-id, endorser: tx-sender} {
          endorsement-level: endorsement-level,
          relationship: relationship,
          comment: comment,
          endorser-competency: endorser-competency,
          endorsed-at: current-block,
          is-verified: false
        })
        
        ;; Update user skill endorsement count
        (map-set user-skills {user: user, skill-id: skill-id}
          (merge user-skill {
            endorsement-count: (+ (get endorsement-count user-skill) u1)
          }))
        
        (ok true)
      )
    )
  )
)

;; Create professional certification
(define-public (create-certification
    (name (string-ascii 100))
    (issuing-organization (string-ascii 100))
    (skill-id uint)
    (requirements (string-ascii 300))
    (validity-period-blocks uint))
  (let (
    (certification-id (var-get next-certification-id))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validate inputs
      (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
      (asserts! (> (len issuing-organization) u0) (err ERR-INVALID-INPUT))
      (asserts! (is-some (get-skill skill-id)) (err ERR-NOT-FOUND))
      (asserts! (> validity-period-blocks u0) (err ERR-INVALID-INPUT))
      
      ;; Only authorized creators can create certifications
      (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                   (is-authorized-creator tx-sender)) (err ERR-NOT-AUTHORIZED))
      
      ;; Create certification
      (map-set certifications certification-id {
        name: name,
        issuing-organization: issuing-organization,
        skill-id: skill-id,
        requirements: requirements,
        validity-period-blocks: validity-period-blocks,
        created-by: tx-sender,
        created-at: current-block,
        is-active: true
      })
      
      ;; Update counter
      (var-set next-certification-id (+ certification-id u1))
      
      (ok certification-id)
    )
  )
)

;; Issue certification to user
(define-public (issue-certification
    (user principal)
    (certification-id uint)
    (score-achieved uint)
    (verification-hash (buff 32)))
  (let (
    (certification (unwrap! (get-certification certification-id) (err ERR-NOT-FOUND)))
    (current-block stacks-block-height)
    (expires-at (+ current-block (get validity-period-blocks certification)))
    (user-certs (default-to (list) (map-get? user-certification-list user)))
    (user-skill (get-user-skill user (get skill-id certification)))
  )
    (begin
      ;; Only certification creator can issue
      (asserts! (is-eq tx-sender (get created-by certification)) (err ERR-NOT-AUTHORIZED))
      
      ;; Validate inputs
      (asserts! (<= score-achieved u100) (err ERR-INVALID-INPUT))
      
      ;; User must have minimum competency in the skill
      (unwrap! (match user-skill
        skill-profile (if (>= (get verified-score skill-profile) u70)
                        (ok true)
                        (err ERR-INSUFFICIENT-SCORE))
        (err ERR-NOT-FOUND)
      ) (err ERR-NOT-FOUND))
      
      ;; Issue certification
      (map-set user-certifications {user: user, certification-id: certification-id} {
        issued-at: current-block,
        expires-at: expires-at,
        verification-hash: verification-hash,
        issuer: tx-sender,
        score-achieved: score-achieved,
        is-valid: true
      })
      
      ;; Update user certification list
      (let ((updated-certs (as-max-len? (append user-certs certification-id) u20)))
        (asserts! (is-some updated-certs) (err ERR-INVALID-INPUT))
        (map-set user-certification-list user (unwrap-panic updated-certs))
      )
      
      ;; Update user skill with certification
      (match user-skill
        skill-profile 
          (let ((current-certs (get certifications skill-profile))
                (updated-skill-certs (as-max-len? (append current-certs certification-id) u10)))
            (begin
              (asserts! (is-some updated-skill-certs) (err ERR-INVALID-INPUT))
              (map-set user-skills {user: user, skill-id: (get skill-id certification)}
                (merge skill-profile {
                  certifications: (unwrap-panic updated-skill-certs)
                }))
            )
          )
        ;; If no skill profile exists, skip updating skills
        true
      )
      
      (ok certification-id)
    )
  )
)

;; Helper function to update user skill profile
(define-private (update-user-skill-profile (user principal) (skill-id uint) (score uint))
  (let (
    (existing-skill (get-user-skill user skill-id))
    (current-block stacks-block-height)
    (new-competency (determine-competency-level score))
    (user-skills-list (default-to (list) (map-get? user-skill-list user)))
  )
    (match existing-skill
      skill-profile 
        (map-set user-skills {user: user, skill-id: skill-id}
          (merge skill-profile {
            competency-level: new-competency,
            verified-score: (if (> score (get verified-score skill-profile)) score (get verified-score skill-profile)),
            last-assessed: current-block,
            total-assessments: (+ (get total-assessments skill-profile) u1)
          }))
      ;; Create new skill profile
      (begin
        (map-set user-skills {user: user, skill-id: skill-id} {
          competency-level: new-competency,
          verified-score: score,
          last-assessed: current-block,
          total-assessments: u1,
          endorsement-count: u0,
          experience-years: u0,
          certifications: (list)
        })
        
        ;; Add to user skills list
        (map-set user-skill-list user 
          (unwrap! (as-max-len? (append user-skills-list skill-id) u50) (err ERR-INVALID-INPUT)))
      )
    )
    (ok true)
  )
)

;; Determine competency level based on score
(define-private (determine-competency-level (score uint))
  (if (>= score u90) COMPETENCY-EXPERT
    (if (>= score u80) COMPETENCY-ADVANCED
      (if (>= score u70) COMPETENCY-INTERMEDIATE
        COMPETENCY-BEGINNER
      )
    )
  )
)

;; Update test statistics
(define-private (update-test-statistics (test-id uint) (score uint))
  (match (get-skill-test test-id)
    test 
      (let (
        (new-total (+ (get total-attempts test) u1))
        (new-average (/ (+ (* (get average-score test) (get total-attempts test)) score) new-total))
      )
        (map-set skill-tests test-id 
          (merge test {
            total-attempts: new-total,
            average-score: new-average
          }))
      )
    false
  )
)

;; Admin Functions

;; Authorize test creator
(define-public (authorize-creator
    (creator principal)
    (organization (string-ascii 100))
    (expertise-areas (list 10 (string-ascii 50))))
  (let ((current-block stacks-block-height))
    (begin
      ;; Only contract owner can authorize
      (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
      
      ;; Validate inputs
      (asserts! (> (len organization) u0) (err ERR-INVALID-INPUT))
      (asserts! (> (len expertise-areas) u0) (err ERR-INVALID-INPUT))
      
      (map-set authorized-creators creator {
        organization: organization,
        expertise-areas: expertise-areas,
        authorized-by: tx-sender,
        authorized-at: current-block,
        is-active: true
      })
      
      (ok creator)
    )
  )
)

;; Set platform fee
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
    (asserts! (<= new-fee u10000) (err ERR-INVALID-INPUT)) ;; Max 0.01 STX
    (var-set platform-fee new-fee)
    (ok new-fee)
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-skills: (- (var-get next-skill-id) u1),
    total-tests: (- (var-get next-test-id) u1),
    total-certifications: (- (var-get next-certification-id) u1),
    total-assessments: (- (var-get next-assessment-id) u1),
    platform-fee: (var-get platform-fee),
    min-passing-score: MIN_PASSING_SCORE
  }
)