# Work History Validator Smart Contract

A robust blockchain-based system for validating and managing professional work history on the Stacks blockchain using Clarity smart contracts.

## Overview

The Work History Validator Smart Contract provides a decentralized platform where professionals can record their work experiences and have them validated by colleagues, managers, HR representatives, or clients. This creates a trustworthy, immutable record of professional history that can be used for job applications, career verification, and reputation building.

## Features

### Core Functionality
- **Work Experience Management**: Add, update, and track professional work experiences
- **Peer Validation System**: Allow colleagues and supervisors to validate work history
- **Company Registry**: Register and verify companies within the system
- **User Profiles**: Comprehensive professional profiles with reputation scoring
- **Authorization System**: Role-based permissions for HR representatives and validators

### Key Benefits
- **Immutable Records**: Work history stored permanently on blockchain
- **Peer Validation**: Multi-party verification system for credibility
- **Reputation Scoring**: Automated reputation calculation based on validations
- **Anti-Fraud Protection**: Prevents self-validation and duplicate validations
- **Company Verification**: Official company registration and verification system

## Smart Contract Architecture

### Data Structures

#### Work Experiences
```clarity
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
  status: (string-ascii 20) // "pending", "validated", "disputed"
}
```

#### User Profiles
```clarity
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
```

#### Validations
```clarity
{
  validation-type: (string-ascii 20), // "colleague", "manager", "hr", "client"
  comments: (string-ascii 300),
  rating: uint, // 1-5 scale
  validated-at: uint,
  validator-title: (optional (string-ascii 100)),
  is-verified: bool
}
```

#### Company Registry
```clarity
{
  verified: bool,
  registered-by: principal,
  contact-email: (string-ascii 100),
  website: (optional (string-ascii 200)),
  industry: (string-ascii 50),
  size: (string-ascii 20), // "startup", "small", "medium", "large", "enterprise"
  registered-at: uint
}
```

## Usage Guide

### 1. Creating a User Profile

First, users must create a profile:

```clarity
(contract-call? .work-history-validator create-user-profile
  "John Doe"
  "john.doe@email.com"
  (some "https://linkedin.com/in/johndoe"))
```

### 2. Registering a Company

Companies can be registered in the system:

```clarity
(contract-call? .work-history-validator register-company
  "Tech Corp Inc"
  "hr@techcorp.com"
  (some "https://techcorp.com")
  "Technology"
  "medium")
```

### 3. Adding Work Experience

Users can add their work experiences:

```clarity
(contract-call? .work-history-validator add-work-experience
  "Tech Corp Inc"
  "Senior Developer"
  "Developed web applications using modern frameworks and managed team of 3 developers"
  u20220101  ;; start date
  (some u20231201)  ;; end date
  (list "JavaScript" "React" "Node.js" "Python")
  (some {min: u80000, max: u100000})  ;; salary range
  false)  ;; not current
```

### 4. Validating Work Experience

Other users can validate work experiences:

```clarity
(contract-call? .work-history-validator validate-work-experience
  u1  ;; work-id
  "colleague"
  "John was an excellent developer and team player during our time working together"
  u5  ;; rating (1-5)
  (some "Senior Developer"))
```

### 5. Authorizing Validators

Contract owner or existing authorized validators can authorize HR representatives:

```clarity
(contract-call? .work-history-validator authorize-validator
  'SP1ABC...  ;; validator principal
  "Tech Corp Inc"
  "HR Manager")
```

## Read-Only Functions

### Profile and Experience Queries
- `get-work-experience(work-id)` - Retrieve work experience details
- `get-user-profile(user)` - Get user profile information
- `get-user-work-experiences(user)` - List all work experiences for a user
- `get-company-info(company-name)` - Get company registration details
- `get-company-work-experiences(company-name)` - List work experiences at a company

### Validation Queries
- `get-validation(work-id, validator)` - Get specific validation details
- `get-validation-count(work-id)` - Count validations for work experience
- `is-authorized-validator(user)` - Check if user is authorized validator
- `calculate-reputation-score(user)` - Calculate user's reputation score

### Contract Information
- `get-contract-stats()` - Get overall contract statistics

## Public Functions

### User Management
- `create-user-profile(full-name, email, linkedin-profile)` - Create/update user profile
- `update-work-experience(work-id, ...)` - Update existing work experience
- `add-work-experience(...)` - Add new work experience
- `validate-work-experience(...)` - Validate someone's work experience
- `dispute-work-experience(work-id, reason)` - Dispute a work experience record

### Company Management
- `register-company(...)` - Register new company in system

### Authorization Management
- `authorize-validator(validator, company-name, role)` - Grant validation privileges
- `revoke-validator(validator)` - Revoke validation privileges

### Admin Functions (Contract Owner Only)
- `set-min-validations-required(new-min)` - Set minimum validations needed
- `set-validation-expiry-blocks(new-expiry)` - Set validation expiry period
- `verify-company(company-name)` - Officially verify a company
- `verify-user-profile(user)` - Officially verify a user profile

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR_UNAUTHORIZED | User lacks required permissions |
| 101 | ERR_NOT_FOUND | Requested item does not exist |
| 102 | ERR_ALREADY_EXISTS | Item already exists |
| 103 | ERR_INVALID_INPUT | Invalid input parameters |
| 104 | ERR_INVALID_DATES | Invalid date range |
| 105 | ERR_CANNOT_SELF_VALIDATE | User cannot validate own work |
| 106 | ERR_ALREADY_VALIDATED | Already validated by this user |
| 107 | ERR_INSUFFICIENT_VALIDATIONS | Not enough validations |
| 108 | ERR_EXPIRED | Validation has expired |

## Security Features

### Anti-Fraud Measures
- **Self-Validation Prevention**: Users cannot validate their own work experiences
- **Duplicate Validation Prevention**: Each validator can only validate once per work experience
- **Authorization System**: Only authorized HR representatives have enhanced validation privileges
- **Immutable Records**: All records are permanently stored on blockchain

### Access Control
- **Owner-Only Functions**: Critical administrative functions restricted to contract owner
- **Role-Based Permissions**: Different permission levels for validators, HR, and regular users
- **Validation Requirements**: Minimum validation thresholds for work experience approval

## Configuration

### Default Settings
- **Minimum Validations Required**: 2 validations per work experience
- **Validation Expiry**: ~1 year (52,560 blocks)
- **Maximum Skills per Experience**: 10 skills
- **Maximum Work Experiences per User**: 50
- **Maximum Work Experiences per Company**: 100

### Customizable Parameters
- Minimum validation requirements (admin configurable)
- Validation expiry period (admin configurable)
- Company verification status (admin managed)
- User verification status (admin managed)

## Reputation System

The contract includes an automated reputation scoring system:

```clarity
reputation-score = (total-validations-received × 10) + (total-validations-given × 5)
```

This incentivizes both receiving validations for your work and providing validations for others.

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deploying address becomes the contract owner
3. Configure minimum validation requirements and expiry periods
4. Begin onboarding companies and users

## Use Cases

- **Job Applications**: Verified work history for recruitment
- **Career Progression**: Track professional development over time
- **Network Building**: Connect with validated colleagues and supervisors
- **Reputation Management**: Build credible professional reputation
- **Background Verification**: Automated reference checking for employers