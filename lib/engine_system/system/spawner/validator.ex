defmodule EngineSystem.System.Spawner.Validator do
  @moduledoc """
  I provide comprehensive validation for engine spawning operations.
  """

  alias EngineSystem.Engine.{Spec, State}

  @type validation_result :: :ok | {:error, atom()}

  @doc """
  I validate all inputs required for engine instance registration.
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
  """
  @spec validate_instance_name(atom() | nil) :: validation_result()
  def validate_instance_name(nil), do: :ok

  def validate_instance_name(name) when is_atom(name), do: :ok

  def validate_instance_name(_name), do: {:error, :invalid_name_type}

  @doc """
  I provide a human-readable description of validation error reasons.
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
