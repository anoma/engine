# Message Flow

This document details how messages flow through the EngineSystem from initial sending to final processing, covering validation, queuing, and delivery mechanisms.

## Overview

The EngineSystem implements a sophisticated message flow that ensures type safety, validation, and reliable delivery. Messages pass through multiple stages before reaching their target engines, with each stage providing specific guarantees and transformations.

## Message Flow Stages

### 1. Message Sending

```elixir
# External message sending
:ok = EngineSystem.send_message(target_address, {:increment, %{}})
```

**Process:**
1. API validates message format
2. System registry resolves target address
3. Message is routed to appropriate mailbox
4. Asynchronous delivery begins

**Validations:**
- Address format validation
- Basic message structure checks
- Target engine existence verification

### 2. Mailbox Reception (m-Enqueue)

```elixir
# In DefaultMailboxEngine
on_message :enqueue_message, %{message: message}, _config, env, _sender do
  case validate_message_for_pe(message, env.pe_spec) do
    :ok ->
      new_queue = :queue.in(message, env.message_queue)
      # ... continue processing
    {:error, reason} ->
      # Message rejected
  end
end
```

**Process:**
1. Mailbox receives message
2. Message validated against processing engine interface
3. If valid, message added to queue
4. If invalid, message is dropped/logged

**Validations:**
- Interface contract checking
- Message type validation
- Parameter structure verification

### 3. Message Filtering

```elixir
# Extract messages based on filter
{messages, remaining_queue} = extract_messages(queue, demand, pe_filter)
```

**Process:**
1. Apply processing engine's message filter
2. Select messages that pass filter criteria
3. Respect demand limits from processing engine
4. Maintain queue ordering (FIFO by default)

**Filter Examples:**
```elixir
# Accept all messages
filter = fn _msg, _config, _env -> true end

# Accept only when engine is ready
filter = fn _msg, _config, env -> env.status == :ready end

# Accept based on message priority
filter = fn {:priority, level}, _config, _env -> level >= :high end
```

### 4. Demand-Driven Delivery (m-Dequeue)

```elixir
# Processing engine requests messages
on_message :request_batch, %{demand: demand}, _config, env, _sender do
  {messages, remaining_queue} = extract_messages(env.message_queue, demand, env.pe_filter)
  # Deliver messages if available
end
```

**Process:**
1. Processing engine signals demand (GenStage)
2. Mailbox attempts to satisfy demand
3. Messages extracted based on filter and availability
4. Batch delivered to processing engine

**Backpressure Handling:**
- Engines control message flow via demand
- Mailboxes buffer messages when demand is low
- System prevents message overflow

### 5. Message Processing (s-Process)

```elixir
# In Engine.Instance
def handle_events(messages, _from, state) do
  results = Enum.map(messages, &process_message(&1, state))
  # Apply effects and update state
end
```

**Process:**
1. Engine receives batch of messages
2. Each message processed sequentially
3. Behavior rules applied to generate effects
4. State updated based on effects
5. New demand signaled if ready for more messages

## Message Format

### Standard Message Format

```elixir
{message_tag, payload}
```

Where:
- `message_tag` is an atom identifying the message type
- `payload` contains the message data

**Examples:**
```elixir
{:increment, %{}}                    # Simple message with empty payload
{:add, %{a: 1, b: 2}}               # Message with structured payload
{:get, %{key: :user_id}}            # Message with parameters
{:result, %{value: 42}}             # Response message
```

### Interface Validation

Messages are validated against interface specifications:

```elixir
interface do
  message :add, a: :number, b: :number
  message :result, value: :number
end
```

**Validation Rules:**
- Message tag must be declared in interface
- Required parameters must be present
- Parameter types must match declarations
- Extra parameters are rejected

## Message Queuing Policies

### FIFO (First In, First Out)

Default queuing policy ensures message ordering:

```elixir
config do
  %{
    delivery_policy: :fifo,
    max_buffer_size: 1000
  }
end
```

### Priority Queuing (Future Extension)

```elixir
config do
  %{
    delivery_policy: :priority,
    priority_levels: [:low, :normal, :high, :urgent]
  }
end
```

### Custom Queuing Policies

Mailbox engines can implement custom queuing:

```elixir
defmodule CustomMailbox do
  # Custom message ordering logic
  def enqueue_message(message, queue, config) do
    # Custom implementation
  end
end
```

## Error Handling

### Message Validation Errors

```elixir
# Invalid message type
{:unknown_message, %{}} -> dropped

# Missing required parameters  
{:add, %{a: 1}} -> dropped (missing b)

# Type mismatch
{:add, %{a: "not_number", b: 2}} -> dropped
```

### Processing Errors

```elixir
# Engine behavior returns error
{:error, reason} -> message may be retried or dead-lettered

# Engine crash -> supervisor restarts engine, messages preserved in mailbox
```

### Delivery Guarantees

- **At-least-once**: Messages are not lost due to transient failures
- **Ordering**: FIFO ordering maintained within each mailbox
- **Validation**: Invalid messages are rejected early
- **Backpressure**: System prevents overwhelming slow consumers

## Monitoring and Observability

### Message Statistics

```elixir
# Mailbox statistics
%{
  total_received: 1000,
  total_delivered: 950,
  queue_length: 50,
  drop_count: 5
}
```

### Flow Tracing

```elixir
# Enable message tracing
:ok = EngineSystem.enable_message_tracing()

# Trace specific message
{:ok, trace_id} = EngineSystem.send_message_traced(address, message)
```

## Performance Characteristics

### Throughput

- **High-throughput**: GenStage pipeline optimized for message processing
- **Batching**: Messages processed in configurable batches
- **Parallelism**: Multiple engines can process messages concurrently

### Latency

- **Low-latency**: Direct message passing with minimal overhead
- **Predictable**: Bounded queue sizes prevent unpredictable delays
- **Tunable**: Batch sizes and demand configuration affect latency

### Memory Usage

- **Bounded**: Maximum queue sizes prevent memory leaks
- **Efficient**: Queue implementation optimized for append/prepend
- **Configurable**: Buffer sizes adjustable per engine

## Advanced Features

### Message Correlation

```elixir
# Send with correlation ID
:ok = send_message(address, {:query, %{id: correlation_id, data: data}})

# Response includes correlation
{:result, %{id: correlation_id, result: value}}
```

### Message Timeouts

```elixir
# Future: message expiration
{:timed_message, %{expires_at: timestamp, message: actual_message}}
```

### Dead Letter Handling

```elixir
# Future: dead letter queue for failed messages
config do
  %{
    dead_letter_queue: true,
    max_retries: 3
  }
end
```

This message flow design ensures reliable, type-safe, and performant message delivery while maintaining the formal model's semantics and providing excellent observability and debugging capabilities. 