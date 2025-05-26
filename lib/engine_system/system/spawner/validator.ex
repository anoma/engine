defmodule EngineSystem.System.Spawner.Validator do
  @moduledoc """
  I provide comprehensive validation for engine spawning operations.

  This module implements validation logic for the s-EngineSpawn operational rule
  from the formal model, ensuring that all inputs to the spawning process are
  valid before attempting to create engine instances.

  ## Validation Categories

  - **Address Validation**: Ensures addresses follow the {node_id, engine_id} format
  - **Spec Validation**: Validates engine specifications are complete and well-formed
  - **Process Validation**: Ensures PIDs are valid and processes are alive
  - **Name Validation**: Validates optional instance names

  ## Public API

  - `validate_registration_inputs/4` - Validate all inputs for engine registration
  - `validate_address/1` - Validate an engine address format
  - `validate_spec/1` - Validate an engine specification
  - `validate_engine_pid/1` - Validate an engine process PID
  - `validate_mailbox_pid/1` - Validate a mailbox process PID
  - `describe_error/1` - Get human readable description of validation error

  ## Usage

      iex> alias EngineSystem.System.Spawner.Validator
      iex> Validator.validate_registration_inputs(address, spec, engine_pid, mailbox_pid)
      :ok

  ## Error Types

  All validation functions return either `:ok` or `{:error, reason}` where reason
  is a descriptive atom that can be used for logging and debugging.
  """

  alias EngineSystem.Engine.{Spec, State}

  @type validation_result :: :ok | {:error, atom()}

  @doc """
  I validate all inputs required for engine instance registration.

  This is the main validation entry point that orchestrates all other validations.

  ## Parameters

  - `address` - The engine's address tuple {node_id, engine_id}
  - `spec` - The engine specification struct
  - `engine_pid` - The engine process PID
  - `mailbox_pid` - The mailbox process PID (can be nil)

  ## Returns

  - `:ok` if all validations pass
  - `{:error, reason}` if any validation fails

  ## Examples

      iex> address = {1, 123}
      iex> spec = %EngineSystem.Engine.Spec{name: :test, version: "1.0.0"}
      iex> engine_pid = spawn(fn -> :ok end)
      iex> Validator.validate_registration_inputs(address, spec, engine_pid, nil)
      :ok
  """
  @spec validate_registration_inputs(State.address(), Spec.t(), pid(), pid() | nil) ::
          validation_result()
  def validate_registration_inputs(address, spec, engine_pid, mailbox_pid) do
    with :ok <- validate_address(address),
         :ok <- validate_spec(spec),
         :ok <- validate_engine_pid(engine_pid),
         :ok <- validate_mailbox_pid(mailbox_pid) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  I validate that an address follows the proper format.

  Addresses must be tuples of the form {node_id, engine_id} where both
  components are non-negative integers.

  ## Parameters

  - `address` - The address to validate

  ## Returns

  - `:ok` if the address is valid
  - `{:error, reason}` if the address is invalid

  ## Examples

      iex> Validator.validate_address({1, 123})
      :ok

      iex> Validator.validate_address(nil)
      {:error, :address_is_nil}

      iex> Validator.validate_address("invalid")
      {:error, :invalid_address_format}
  """
  @spec validate_address(State.address()) :: validation_result()
  def validate_address(address) do
    case address do
      {node_id, engine_id}
      when is_integer(node_id) and node_id >= 0 and
             is_integer(engine_id) and engine_id >= 0 ->
        :ok

      nil ->
        {:error, :address_is_nil}

      _ ->
        {:error, :invalid_address_format}
    end
  end

  @doc """
  I validate that a spec is a proper engine specification.

  Specs must be EngineSystem.Engine.Spec structs with valid name and version fields.

  ## Parameters

  - `spec` - The spec to validate

  ## Returns

  - `:ok` if the spec is valid
  - `{:error, reason}` if the spec is invalid

  ## Examples

      iex> spec = %EngineSystem.Engine.Spec{name: :test, version: "1.0.0"}
      iex> Validator.validate_spec(spec)
      :ok
  """
  @spec validate_spec(Spec.t()) :: validation_result()
  def validate_spec(spec) do
    cond do
      is_nil(spec) ->
        {:error, :spec_is_nil}

      not is_struct(spec, Spec) ->
        {:error, :invalid_spec_type}

      is_nil(spec.name) ->
        {:error, :spec_missing_name}

      is_nil(spec.version) ->
        {:error, :spec_missing_version}

      true ->
        :ok
    end
  end

  @doc """
  I validate that an engine PID is valid and the process is alive.

  ## Parameters

  - `engine_pid` - The engine process PID to validate

  ## Returns

  - `:ok` if the PID is valid and process is alive
  - `{:error, reason}` if the PID is invalid or process is dead

  ## Examples

      iex> pid = spawn(fn -> :timer.sleep(100) end)
      iex> Validator.validate_engine_pid(pid)
      :ok
  """
  @spec validate_engine_pid(pid()) :: validation_result()
  def validate_engine_pid(engine_pid) do
    cond do
      is_nil(engine_pid) ->
        {:error, :engine_pid_is_nil}

      not is_pid(engine_pid) ->
        {:error, :invalid_engine_pid_type}

      not Process.alive?(engine_pid) ->
        {:error, :engine_process_dead}

      true ->
        :ok
    end
  end

  @doc """
  I validate that a mailbox PID is valid and the process is alive (if provided).

  Mailbox PIDs are optional, so nil is considered valid.

  ## Parameters

  - `mailbox_pid` - The mailbox process PID to validate (can be nil)

  ## Returns

  - `:ok` if the PID is valid (or nil)
  - `{:error, reason}` if the PID is invalid or process is dead

  ## Examples

      iex> Validator.validate_mailbox_pid(nil)
      :ok

      iex> pid = spawn(fn -> :timer.sleep(100) end)
      iex> Validator.validate_mailbox_pid(pid)
      :ok
  """
  @spec validate_mailbox_pid(pid() | nil) :: validation_result()
  def validate_mailbox_pid(nil), do: :ok

  def validate_mailbox_pid(mailbox_pid) do
    cond do
      not is_pid(mailbox_pid) ->
        {:error, :invalid_mailbox_pid_type}

      not Process.alive?(mailbox_pid) ->
        {:error, :mailbox_process_dead}

      true ->
        :ok
    end
  end

  @doc """
  I validate that an instance name is valid (if provided).

  Names must be atoms when provided. Nil is considered valid (unnamed instance).

  ## Parameters

  - `name` - The instance name to validate (can be nil)

  ## Returns

  - `:ok` if the name is valid (or nil)
  - `{:error, reason}` if the name is invalid

  ## Examples

      iex> Validator.validate_instance_name(nil)
      :ok

      iex> Validator.validate_instance_name(:my_engine)
      :ok

      iex> Validator.validate_instance_name("string_name")
      {:error, :invalid_name_type}
  """
  @spec validate_instance_name(atom() | nil) :: validation_result()
  def validate_instance_name(nil), do: :ok

  def validate_instance_name(name) when is_atom(name), do: :ok

  def validate_instance_name(_name), do: {:error, :invalid_name_type}

  @doc """
  I provide a human-readable description of validation error reasons.

  ## Parameters

  - `reason` - The error reason atom

  ## Returns

  A string describing the error

  ## Examples

      iex> Validator.describe_error(:address_is_nil)
      "Address is nil"

      iex> Validator.describe_error(:invalid_address_format)
      "Address must be {node_id, engine_id} tuple"
  """
  @spec describe_error(atom()) :: String.t()
  def describe_error(:address_is_nil), do: "Address is nil"
  def describe_error(:invalid_address_format), do: "Address must be {node_id, engine_id} tuple"
  def describe_error(:spec_is_nil), do: "Spec is nil"
  def describe_error(:invalid_spec_type), do: "Spec must be an EngineSystem.Engine.Spec struct"
  def describe_error(:spec_missing_name), do: "Spec is missing name field"
  def describe_error(:spec_missing_version), do: "Spec is missing version field"
  def describe_error(:engine_pid_is_nil), do: "Engine PID is nil"
  def describe_error(:invalid_engine_pid_type), do: "Engine PID must be a process identifier"
  def describe_error(:engine_process_dead), do: "Engine process is not alive"
  def describe_error(:invalid_mailbox_pid_type), do: "Mailbox PID must be a process identifier"
  def describe_error(:mailbox_process_dead), do: "Mailbox process is not alive"
  def describe_error(:invalid_name_type), do: "Instance name must be an atom"
  def describe_error(:name_already_taken), do: "Instance name is already in use"
  def describe_error(:address_already_registered), do: "Address is already registered"
  def describe_error(reason), do: "#{inspect(reason)}"
end
