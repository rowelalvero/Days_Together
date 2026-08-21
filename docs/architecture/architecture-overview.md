# Architecture Overview

**PROPOSED.** Visual reference for the architecture defined across this specification, the ADRs, and the satellite documents. Every diagram here is a picture of a decision recorded elsewhere — this document does not introduce new decisions, only shows them.

Days Together is a **feature-oriented modular architecture with lightweight domain/business logic where complexity warrants it** — see the main specification's "Architectural Philosophy" section for the full distinction from Domain-Driven Design, which this app deliberately does not adopt wholesale.

---

## 1. High-level layered architecture

```mermaid
flowchart TD
    UI["Presentation<br/>(screens, widgets — feature-local)"]
    STATE["State<br/>(Riverpod Notifiers / CoupleSession)"]
    DATA["Data<br/>(3 Repositories + Services, per feature)"]
    CORE["core/ — errors, prefs keys, design_system, routing infra"]
    EXT["External: Supabase (Auth · Postgrest · Realtime · Storage)"]

    UI -->|reads state, calls controller methods| STATE
    STATE -->|calls| DATA
    DATA -->|calls| EXT
    UI -.->|tokens, error types, PrefsKeys| CORE
    STATE -.-> CORE
    DATA -.-> CORE

    style UI fill:#e8f0fe
    style STATE fill:#fef3e0
    style DATA fill:#e6f4ea
    style CORE fill:#f3e8fd
    style EXT fill:#fce8e6
```

**Rule this diagram encodes (architecture-rules.md Rules 1, 2, 12, 13, 15):** arrows only point downward or sideways into `core/`. Nothing in `core/` points back up into presentation, state, or data. `EXT` (Supabase) is reached only from `DATA` — never from `UI` or directly from a widget, per ADR-004.

---

## 2. Feature / module diagram

```mermaid
flowchart LR
    subgraph Base
        AUTH[authentication]
        REL[relationship]
    end
    subgraph Domain features
        TL[timeline]
        SB[scrapbook]
        CH[chat]
        BL[bucket_list]
        CAL[calendar]
        GR[gift_reminders]
        TC[topic_cards]
        MD[mood]
        CUR[currently]
        LS[love_studio]
    end
    subgraph Aggregators
        DASH[dashboard]
        WRP[wrapped]
    end
    SET[settings]

    REL --> AUTH
    TL --> REL
    SB --> REL
    SB -.->|"ScrapbookShareUseCase<br/>(public ChatController only)"| CH
    CH --> REL
    BL --> REL
    CAL --> REL
    GR --> REL
    TC --> REL
    MD --> REL
    CUR --> REL
    LS --> REL
    SET --> AUTH
    SET --> REL

    DASH -.->|read-only, public providers| REL
    DASH -.-> TL
    DASH -.-> BL
    DASH -.-> MD
    DASH -.-> CUR
    DASH -.-> SB
    DASH -.-> CH
    WRP -.->|read-only, public providers| TL
    WRP -.-> BL
    WRP -.-> MD
    WRP -.-> CUR
    WRP -.-> REL

    classDef forbidden stroke:#c0392b,stroke-width:2px,stroke-dasharray: 4 2;
```

**Solid arrows** = a normal feature dependency (depends on `relationship`/`authentication` for couple scoping). **Dotted arrows** = read-only, public-provider-only dependency (the `dashboard`/`wrapped` aggregation pattern, and the one sanctioned `scrapbook → chat` write path via `ScrapbookShareUseCase`, per ADR-009/ADR-013). No arrow ever points *into* `authentication` or `relationship` from a domain feature — that direction is what the forbidden-cycle rule (below) exists to prevent.

---

## 3. The forbidden cycle, explicitly

```mermaid
flowchart LR
    TL[timeline] -->|FORBIDDEN| SB[scrapbook]
    SB -->|FORBIDDEN| CH[chat]
    CH -->|FORBIDDEN| REL[relationship]
    REL -->|FORBIDDEN| TL

    linkStyle 0 stroke:#c0392b,stroke-width:3px
    linkStyle 1 stroke:#c0392b,stroke-width:3px
    linkStyle 2 stroke:#c0392b,stroke-width:3px
    linkStyle 3 stroke:#c0392b,stroke-width:3px
```

This exact cycle — `timeline → scrapbook → chat → relationship → timeline` — is named explicitly in `feature-boundaries.md` and enforced by the architecture test's acyclic-graph check (`testing-strategy.md`). The one real edge in this diagram that *does* exist, `scrapbook → chat`, is sanctioned **only** in the one-directional, public-provider form shown in Diagram 2 — `chat` importing anything from `scrapbook`, or `relationship` depending on any downstream feature, remains forbidden regardless.

---

## 4. Data flow (a single feature, read + write)

```mermaid
sequenceDiagram
    participant W as Widget
    participant N as Feature Notifier
    participant R as Repository / Service
    participant S as Supabase

    W->>N: ref.watch(featureProvider)
    N->>R: fetch initial rows
    R->>S: .from(table).select()
    S-->>R: rows
    R-->>N: typed models (or raw row for the 12 single-owner tables)
    N-->>W: state

    N->>R: subscribe (realtime)
    R->>S: postgres_changes stream
    S-->>N: change event (via RealtimeSubscriptionManager, see Diagram 5)
    N-->>W: updated state

    W->>N: user action (e.g. create item)
    N->>N: optimistic local update
    N->>R: write
    R->>S: .insert()/.update()
    S-->>N: realtime echo reconciles optimistic state
```

---

## 5. Supabase / realtime architecture

```mermaid
flowchart TD
    SUPA["Supabase Realtime<br/>(postgres_changes)"]
    MGR["RealtimeSubscriptionManager<br/>(the ONE authoritative owner — Rule B)"]
    N1["Feature Notifier A<br/>autoDispose / ref.onDispose (Rule C)"]
    N2["Feature Notifier B<br/>autoDispose / ref.onDispose (Rule C)"]
    UI1[Widget A]
    UI2[Widget B]

    SUPA --> MGR
    MGR -->|key: table:scope_$coupleId| N1
    MGR -->|distinct key: table:otherScope_$coupleId| N2
    N1 --> UI1
    N2 --> UI2

    UI1 -.->|FORBIDDEN: direct subscription — Rule A| SUPA
    UI2 -.->|FORBIDDEN: direct subscription — Rule A| SUPA

    linkStyle 5 stroke:#c0392b,stroke-width:2px,stroke-dasharray: 4 2
    linkStyle 6 stroke:#c0392b,stroke-width:2px,stroke-dasharray: 4 2
```

This is the diagram behind the `love_notes` fix (ADR-013): Notifier A (`chat`) and Notifier B (`scrapbook`) both ultimately read the same table, but through **two distinct keys** at the manager, each server-side filtered — never one shared, client-filtered key.

---

## 6. State management topology (Riverpod, post-migration)

```mermaid
flowchart TD
    CS["coupleSessionProvider<br/>(CoupleSession, SessionStage)"]
    LC[licenseControllerProvider]
    PC[profileControllerProvider]
    WC[workspaceControllerProvider]
    PRC[presenceControllerProvider]
    DOM["12 domain feature providers<br/>(bucket_list, calendar, timeline, vault, ...)"]

    CS --> LC
    CS --> PC
    CS --> WC
    CS --> PRC
    CS --> DOM

    UR[userRepositoryProvider]
    CR[coupleRepositoryProvider]
    LR[licenseRepositoryProvider]

    LC --> UR
    PC --> UR
    WC --> CR
```

**Note:** `LicenseController` depends on `userRepositoryProvider`, not `licenseRepositoryProvider` — despite the naming similarity, the app's 28 license fields live on the `users` table in the current live code path. `LicenseRepository`/`license_details` backs a separate, narrower certificate-metadata concern. Full explanation in `state-management.md` and `migration-roadmap.md`'s Phase 0 section — this correction was discovered by reading the actual migration history during specification verification, not assumed.

Every arrow is a `ref.watch`/`ref.read` dependency — the structural equivalent of today's `ChangeNotifierProxyProvider<RelationshipProvider, X>` fan-out, now expressed with compile-time-checked references instead of a runtime type lookup against a single god provider. See `state-management.md` for the strangler-bridge mechanics that get the app from the current Provider tree to this topology without a big-bang cutover.

---

## 7. Dependency diagram (internal feature structure)

```mermaid
flowchart TD
    APP["app/<br/>(bootstrap, app.dart)"]
    NAV["navigation<br/>(go_router, redirect on SessionStage)"]
    FEAT["features/&lt;name&gt;/"]
    PRES["presentation/"]
    DOMAIN["domain/ *optional — only where a feature's<br/>complexity warrants it (ADR-009)"]
    DATAL["data/"]
    CORE["core/"]
    SUPA[Supabase]
    STOR[Storage]

    APP --> NAV
    NAV --> FEAT
    FEAT --> PRES
    FEAT -.-> DOMAIN
    FEAT --> DATAL
    PRES --> CORE
    DOMAIN --> CORE
    DATAL --> CORE
    CORE --> SUPA
    CORE --> STOR

    style DOMAIN fill:#f5f5f5,stroke-dasharray: 4 2
```

`domain/` is dashed and marked optional deliberately — per ADR-009, exactly one feature (`scrapbook`) has one. Every other feature is `presentation/ → data/` directly, with no empty `domain/` folder created "for consistency."

### Forbidden dependency directions (explicit)

- `core/` → `features/**` — **forbidden** (Rule 12). `core/` and `shared/` never import a feature.
- `data/` → `presentation/` — **forbidden**. A repository/service never imports a screen or widget.
- `presentation/` → `Supabase` directly, bypassing `data/` — **forbidden** (Rule 1/ADR-004).
- Any `features/<A>/` → non-public path in `features/<B>/` — **forbidden** (Rule 11). Only a feature's intentionally-exported providers/types are reachable from outside it.
- Any cycle in the feature dependency graph — **forbidden** (see Diagram 3).
- `services/**` → `screens/**`/`widgets/**` — **forbidden** (Rule 15/ADR-007). A service emits a navigation intent; it does not import a screen to push it directly.

---

## 8. Migration roadmap, at a glance

```mermaid
flowchart LR
    P0[Phase 0<br/>Foundations] --> P1[Phase 1<br/>CoupleSession]
    P1 --> P2[Phase 2<br/>Host Riverpod]
    P2 --> P3[Phase 3<br/>go_router]
    P3 --> P4[Phase 4<br/>3 Repositories +<br/>immutability]
    P4 --> P5[Phase 5<br/>Split god provider]
    P5 --> P5B[Phase 5b<br/>Convert 27 UI files]
    P5B --> P6[Phase 6<br/>Port 12 providers,<br/>retire Provider]
    P6 --> P7[Phase 7<br/>Design tokens<br/>+ shell]
    P7 --> P7B[Phase 7b<br/>Relocate widgets]
    P7B --> P8[Phase 8<br/>God-screen<br/>decomposition]
```

Full detail, including per-phase risk/validation/exit criteria and the Definition-of-Done traceability, lives in `migration-roadmap.md`.
