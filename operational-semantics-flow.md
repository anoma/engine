# Operational Semantics Flow

In the diagram,

- 🔵 Blue: Message flow components
- 🟣 Purple: Engine components (mailbox & processing)
- 🟢 Green: System infrastructure components
- 🟠 Orange: Effect execution components

- **Formal Model Compliance**:
  The diagram directly maps to the formal operational semantics:
  - s-EngineSpawn: Engine creation process
  - m-Send/m-Enqueue/m-Dequeue: Message handling operations
  - s-Process: Core processing rule with state transitions
  - Mailbox operations: ⊕ (enqueue) and ⊖ (dequeue) operations

```mermaid
graph TB
    %% External Message Source
    External[External Message Source] --> |"send_message(address, payload)"| API[EngineSystem.API]
    
    %% API Layer
    API --> |"lookup_instance(address)"| Registry[System.Registry]
    Registry --> |"returns mailbox_pid"| API
    API --> |"enqueue_message(message)"| Mailbox
    
    %% Engine Spawning Flow (s-EngineSpawn)
    subgraph "Engine Spawning (s-EngineSpawn)"
        Spawner[System.Spawner] --> |"1. get_engine_spec()"| SpecLookup[Engine Spec Lookup]
        SpecLookup --> |"2. start_mailbox_engine()"| MailboxSup[Mailbox.DynamicSupervisor]
        MailboxSup --> |"3. start_processing_engine()"| EngineSup[Engine.DynamicSupervisor]
        EngineSup --> |"4. register_instance()"| Registry
    end
    
    %% Mailbox Engine (First-class Actor)
    subgraph "Mailbox Engine (GenStage Producer)"
        Mailbox[DefaultMailboxEngine] --> |"validate_message_interface()"| InterfaceCheck{Interface Valid?}
        InterfaceCheck --> |"Yes"| Queue[Message Queue ⊕ msg]
        InterfaceCheck --> |"No"| Drop[Drop Message]
        Queue --> |"apply_message_filter()"| FilterCheck{Filter Passes?}
        FilterCheck --> |"Yes"| Demand{Demand > 0?}
        FilterCheck --> |"No"| Queue
        Demand --> |"Yes (m-Dequeue)"| DeliverMsg[Deliver Message]
        Demand --> |"No"| Queue
    end
    
    %% Processing Engine (Business Logic)
    subgraph "Processing Engine (GenStage Consumer)"
        ProcessingEngine[Engine.Instance] --> |"subscribe_to mailbox"| Mailbox
        DeliverMsg --> |"handle_events([message])"| ProcessingEngine
        ProcessingEngine --> |"1. transition to busy"| BusyState[Status: Busy]
        BusyState --> |"2. evaluate_behaviour()"| BehaviourEval[Behaviour.evaluate]
        BehaviourEval --> |"3. execute_effects()"| EffectExec[Effect.execute]
        EffectExec --> |"4. transition to ready"| ReadyState[Status: Ready]
        ReadyState --> |"request next message"| ProcessingEngine
    end
    
    %% Effect System
    subgraph "Effect Execution"
        EffectExec --> SendEffect[Send Message Effect]
        EffectExec --> StateEffect[Update State Effect]
        EffectExec --> SystemEffect[System Effect]
        SendEffect --> |"send_message()"| API
        StateEffect --> |"update environment"| ProcessingEngine
        SystemEffect --> |"system operations"| Registry
    end
    
    %% System Registry
    subgraph "System Registry (Central State)"
        Registry --> SpecStore[Engine Specifications]
        Registry --> InstanceStore[Running Instances]
        Registry --> NameMapping[Name → Address Mapping]
        Registry --> IDGen[Fresh ID Generation]
    end
    
    %% Supervision Tree
    subgraph "OTP Supervision Tree"
        App[EngineSystem.Application] --> MainSup[EngineSystem.Supervisor]
        MainSup --> Registry
        MainSup --> EngineSup
        MainSup --> MailboxSup
    end
    
    %% Message Flow Annotations
    classDef messageFlow fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef engineComponent fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef systemComponent fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef effectComponent fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class External,API,DeliverMsg messageFlow
    class Mailbox,ProcessingEngine,BehaviourEval engineComponent
    class Registry,Spawner,App,MainSup,EngineSup,MailboxSup systemComponent
    class EffectExec,SendEffect,StateEffect,SystemEffect effectComponent
```