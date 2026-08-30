# Diagram Types Reference

## Contents
- Flowchart / Graph
- Sequence Diagram
- State Diagram
- Entity Relationship Diagram
- Class Diagram
- Gantt Chart
- Pie Chart
- Git Graph
- Mindmap
- Timeline
- User Journey
- XY Chart
- Block Diagram
- C4 Diagrams
- Quadrant Chart
- Requirement Diagram
- Architecture Diagram
- Kanban

---

## Flowchart / Graph

Best for: component relationships, data flows, decision
trees, process flows.

```mermaid
graph LR
    A["Input"] --> B{"Validate"}
    B -->|valid| C["Process"]
    B -->|invalid| D["Reject"]
    C --> E["Output"]
```

**Direction options:** `TD` (top-down), `LR` (left-right),
`BT` (bottom-up), `RL` (right-left).

**Node shapes:**
- `[text]` — rectangle
- `(text)` — rounded rectangle
- `{text}` — diamond (decision)
- `([text])` — stadium
- `[[text]]` — subroutine
- `[(text)]` — cylinder (database)
- `((text))` — circle
- `>text]` — asymmetric
- `{{text}}` — hexagon

**Edge styles:**
- `-->` solid arrow
- `-.->` dotted arrow
- `==>` thick arrow
- `-- text -->` labeled edge
- `~~~` invisible link (layout control)

**Subgraphs** for grouping:
```mermaid
graph TD
    subgraph api["API Layer"]
        router["Router"]
        controller["Controller"]
    end
    subgraph data["Data Layer"]
        repo["Repository"]
        db[("Database")]
    end
    router --> controller --> repo --> db
```

**Layout patterns:**
- Hub-and-spoke: central node with radiating connections
- Swimlane: parallel subgraphs for different actors
- Pipeline: linear flow with stages
- Feedback loop: circular flow with return edges

---

## Sequence Diagram

Best for: request/response, API calls, authentication
flows, message passing between actors.

```mermaid
sequenceDiagram
    participant C as Client
    participant S as Server
    participant DB as Database

    C->>S: POST /login
    activate S
    S->>DB: SELECT user
    DB-->>S: user record
    alt valid credentials
        S-->>C: 200 + JWT
    else invalid
        S-->>C: 401 Unauthorized
    end
    deactivate S
```

**Arrow types:**
- `->>` solid with arrowhead
- `-->>` dashed with arrowhead
- `-x` solid with cross (async)
- `--x` dashed with cross

**Blocks:** `alt/else/end`, `opt/end`, `loop/end`,
`par/and/end`, `critical/option/end`, `break/end`.

**Notes:** `Note over A,B: text` or `Note right of A: text`

**Semicolons in messages** require HTML entity: `#59;`

---

## State Diagram

Best for: lifecycle, modes, status transitions.

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review : submit
    Review --> Approved : approve
    Review --> Draft : request_changes
    Approved --> Published : publish
    Published --> [*]

    state Review {
        [*] --> Pending
        Pending --> InProgress : assign
        InProgress --> Done : complete
    }
```

Use `stateDiagram-v2` (not `stateDiagram`).
`[*]` marks start/end states. Nested states via
`state Name { }`.

---

## Entity Relationship Diagram

Best for: database schemas, data models, associations.

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "appears in"
    USER {
        uuid id PK
        string email UK
        string name
        datetime created_at
    }
    ORDER {
        uuid id PK
        uuid user_id FK
        decimal total
        string status
    }
```

**Cardinality:** `||` exactly one, `o|` zero or one,
`}|` one or more, `}o` zero or more.

---

## Class Diagram

Best for: OOP structures, module interfaces, type
hierarchies.

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() String
    }
    class Dog {
        +fetch() void
    }
    class Cat {
        +purr() void
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

**Relationships:** `<|--` inheritance, `*--` composition,
`o--` aggregation, `-->` association, `..>` dependency.

**Visibility:** `+` public, `-` private, `#` protected,
`~` package.

---

## Gantt Chart

Best for: project timelines, sprint planning, milestones.

```mermaid
gantt
    title Sprint 12
    dateFormat YYYY-MM-DD
    section Backend
        API design     :a1, 2025-01-06, 3d
        Implementation :a2, after a1, 5d
        Testing        :a3, after a2, 2d
    section Frontend
        Wireframes     :b1, 2025-01-06, 2d
        Components     :b2, after b1, 4d
    section Milestones
        Demo           :milestone, m1, after a3, 0d
```

---

## Pie Chart

Best for: proportions, distributions, breakdowns.

```mermaid
pie title Traffic Sources
    "Organic" : 45
    "Direct" : 25
    "Referral" : 20
    "Social" : 10
```

---

## Git Graph

Best for: branching strategies, release flows.

```mermaid
gitGraph
    commit
    branch feature
    checkout feature
    commit
    commit
    checkout main
    merge feature
    commit
```

---

## Mindmap

Best for: brainstorming, concept hierarchies, topic
exploration.

```mermaid
mindmap
    root((System Design))
        Frontend
            React
            State Management
        Backend
            API Gateway
            Microservices
        Infrastructure
            Kubernetes
            Monitoring
```

---

## Timeline

Best for: chronological events, project history.

```mermaid
timeline
    title Product Evolution
    2023 : MVP Launch
         : First 100 users
    2024 : Series A
         : Team grows to 20
    2025 : International expansion
```

---

## User Journey

Best for: user experience flows, satisfaction mapping.

```mermaid
journey
    title User Onboarding
    section Sign Up
        Visit landing page: 5: User
        Fill registration form: 3: User
        Verify email: 2: User
    section First Use
        Complete tutorial: 4: User
        Create first project: 5: User
```

Numbers represent satisfaction (1-5).

---

## XY Chart

Best for: metrics, trends, comparisons over axes.

```mermaid
xychart-beta
    title "Monthly Revenue"
    x-axis [Jan, Feb, Mar, Apr, May]
    y-axis "Revenue (USD)" 0 --> 50000
    bar [10000, 20000, 30000, 35000, 45000]
    line [10000, 20000, 30000, 35000, 45000]
```

---

## Block Diagram

Best for: nested containers, system architecture layers.

```mermaid
block-beta
    columns 3
    Frontend:3
    block:backend:2
        API
        Auth
    end
    DB[("Database")]
```

---

## C4 Diagrams

Best for: system context, container, and component views
following the C4 model.

```mermaid
C4Context
    title System Context
    Person(user, "User", "End user")
    System(app, "Application", "Main system")
    System_Ext(email, "Email", "Sends notifications")
    Rel(user, app, "Uses")
    Rel(app, email, "Sends via")
```

Variants: `C4Context`, `C4Container`, `C4Component`,
`C4Deployment`.

---

## Quadrant Chart

Best for: priority matrices, risk assessment, strategic
positioning.

```mermaid
quadrantChart
    title Priority Matrix
    x-axis Low Effort --> High Effort
    y-axis Low Impact --> High Impact
    quadrant-1 Do First
    quadrant-2 Plan
    quadrant-3 Delegate
    quadrant-4 Eliminate
    Feature A: [0.8, 0.9]
    Feature B: [0.2, 0.7]
    Feature C: [0.6, 0.3]
```

---

## Requirement Diagram

Best for: traceability, compliance, specification mapping.

```mermaid
requirementDiagram
    requirement authReq {
        id: REQ-001
        text: System shall authenticate users
        risk: high
        verifymethod: test
    }
    element authModule {
        type: module
        docref: auth.ex
    }
    authModule - satisfies -> authReq
```

---

## Architecture Diagram

Best for: infrastructure, deployment topology.

Note: `architecture-beta` syntax. May not be available in
all Mermaid versions.

---

## Kanban

Best for: task boards, work-in-progress tracking.

Note: `kanban` syntax. Available in Mermaid v11+.
