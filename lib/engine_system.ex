defmodule EngineSystem do
  @moduledoc """
  I provide a formal model-adherent implementation of distributed engines.

  This library implements the Engine Model as described in the formal
  specification, providing a metaprogramming-based DSL for defining engines and
  a runtime system for executing them.

  ## Engine Model

  The Engine Model consists of the following core concepts:

  - **Engines**: Computational units that operate on local state (environments)
    and communicate via messages. Two kinds of engines are supported:
    - Processing engines.
    - Mailbox engines.

  - **Addresses**: Unique identifiers for engines that enable message routing.

  - **Messages**: Typed data structures exchanged between engines.

  - **Effects**: Actions that engines can perform, such as sending messages,
    updating their local state, creating new engines, etc.

  ## Usage

  To use this library, you typically:

  1. Define one or more engine types using the DSL
  2. Start the `EngineSystem` application
  3. Create instances of your engines
  4. Send messages to these engines to trigger their behaviour
  ```
  """

  alias EngineSystem.System.Services

  @doc """
  I start the EngineSystem application.

  This starts the system services and other necessary components.

  ## Returns

  - `:ok` - If the application was started successfully
  - `{:error, reason}` - If the application could not be started
  """
  @spec start() :: :ok | {:error, any()}
  def start do
    IO.puts("Starting EngineSystem")

    case Application.ensure_all_started(:engine_system) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  I stop the EngineSystem application.

  This stops all running engine instances and system services.

  ## Returns

  - `:ok` - If the application was stopped successfully
  """
  @spec stop() :: :ok
  def stop do
    Application.stop(:engine_system)
  end

  @doc """
  I create a new engine instance.

  ## Parameters

  - `engine_type` - The type of engine to create, as `{type_name, type_version}`
  - `config` - The configuration for the engine instance

  ## Returns

  - `{:ok, address}` - If the engine instance was created successfully
  - `{:error, reason}` - If the engine instance could not be created
  """
  @spec create_engine({atom() | String.t(), String.t()}, any()) :: {:ok, any()} | {:error, any()}
  def create_engine(engine_type, config) do
    case Services.create_engine_instance(engine_type, config) do
      %{status: :ok, value: address} -> {:ok, address}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I send a message to an engine.

  ## Parameters

  - `address` - The address of the engine to send the message to
  - `message` - The message to send, as `{tag, payload}`

  ## Returns

  - `{:ok, message_id}` - If the message was sent successfully (asynchronously)
  - `{:error, reason}` - If the message could not be sent
  """
  @spec send_message(any(), {atom(), any()}) :: {:ok, any()} | {:error, any()}
  def send_message(address, message) do
    case Services.send_message(address, message) do
      %{status: :ok, value: message_id} -> {:ok, message_id}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I send a message to an engine and wait for a response.

  ## Parameters

  - `address` - The address of the engine to send the message to
  - `message` - The message to send, as `{tag, payload}`
  - `timeout` - Maximum time to wait for a response (milliseconds)

  ## Returns

  - `{:ok, result}` - If the message was processed and a response was received
  - `{:error, reason}` - If the message could not be sent or no response was received
  """
  @spec send_message_sync(any(), {atom(), any()}, pos_integer()) :: {:ok, any()} | {:error, any()}
  def send_message_sync(address, message, timeout \\ 5000) do
    task =
      Task.async(fn ->
        case send_message(address, message) do
          {:ok, _message_id} ->
            receive do
              {:result, value} -> {:ok, value}
              _ -> {:error, :unexpected_message}
            after
              timeout -> {:error, :timeout}
            end

          error ->
            error
        end
      end)

    case Task.yield(task, timeout + 100) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  @doc """
  I get information about an engine instance.

  ## Parameters

  - `address` - The address of the engine instance

  ## Returns

  - `{:ok, instance_info}` - If the engine instance was found
  - `{:error, :not_found}` - If the engine instance was not found
  """
  @spec get_engine_info(any()) :: {:ok, any()} | {:error, any()}
  def get_engine_info(address) do
    case Services.get_engine_instance(address) do
      %{status: :ok, value: instance_info} -> {:ok, instance_info}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I list all engine instances.

  ## Returns

  - `{:ok, [instance_info]}` - A list of information about all engine instances
  """
  @spec list_engines() :: {:ok, [any()]} | {:error, any()}
  def list_engines do
    case Services.list_engine_instances() do
      %{status: :ok, value: instances} -> {:ok, instances}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I list all registered engine types.

  ## Returns

  - `{:ok, [type_info]}` - A list of information about all registered engine types
  """
  @spec list_engine_types() :: {:ok, [any()]} | {:error, any()}
  def list_engine_types do
    case Services.list_engine_types() do
      %{status: :ok, value: types} -> {:ok, types}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I get information about the system.

  ## Returns

  - `{:ok, system_info}` - Information about the system
  """
  @spec get_system_info() :: {:ok, any()} | {:error, any()}
  def get_system_info do
    case Services.get_system_info() do
      %{status: :ok, value: system_info} -> {:ok, system_info}
      %{status: :error, reason: reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  I get the version of the EngineSystem library.

  ## Returns

  - `{:ok, version}` - The version of the library
  """
  @spec version() :: {:ok, String.t()} | {:error, any()}
  def version do
    case get_system_info() do
      {:ok, %{library_version: version}} -> {:ok, version}
      {:error, reason} -> {:error, reason}
    end
  end
end
