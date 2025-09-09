defmodule EngineSystem.System.Message do
  @moduledoc """
  I define the EngineSystem.System.Message struct.

  I include fields for header (sender PID/address, target engine name/ID) and
  payload (the actual message content). This represents a message in the system
  as defined in the formal model.
  """
  use TypedStruct

  alias EngineSystem.Engine.State

  typedstruct do
    @typedoc """
    I define the structure for a mailbox message.

    ### Fields

    - `:sender` - The sender's address (optional). Enforced: false.
    - `:target` - The target engine's address. Enforced: true.
    - `:payload` - The message payload. Enforced: true.
    """
    field(:sender, State.address() | nil, enforce: false)
    field(:target, State.address(), enforce: true)
    field(:payload, any(), enforce: true)
  end

  @doc """
  I create a new message.
  """
  @spec new(State.address() | nil, State.address(), any()) :: t()
  def new(sender, target, payload) do
    %__MODULE__{
      sender: sender,
      target: target,
      payload: payload
    }
  end

  @doc """
  I extract the message tag from the payload.
  """
  @spec get_tag(t()) :: {:ok, atom()} | :no_tag
  def get_tag(%__MODULE__{payload: {tag, _payload}}) when is_atom(tag) do
    {:ok, tag}
  end

  def get_tag(%__MODULE__{payload: tag}) when is_atom(tag) do
    {:ok, tag}
  end

  def get_tag(_message) do
    :no_tag
  end

  @doc """
  I extract the payload data from the message.
  """
  @spec get_payload_data(t()) :: any()
  def get_payload_data(%__MODULE__{payload: {_tag, data}}) do
    data
  end

  def get_payload_data(%__MODULE__{payload: payload}) do
    payload
  end

  @doc """
  I check if this message matches a given tag.
  """
  @spec matches_tag?(t(), atom()) :: boolean()
  def matches_tag?(%__MODULE__{payload: {tag, _data}}, tag) when is_atom(tag), do: true
  def matches_tag?(%__MODULE__{payload: tag}, tag) when is_atom(tag), do: true
  def matches_tag?(_message, _tag), do: false

  @doc """
  I validate that a message is well-formed.
  """
  @spec validate(t()) :: :ok | {:error, any()}
  def validate(%__MODULE__{target: target, payload: payload})
      when not is_nil(target) and not is_nil(payload) do
    :ok
  end

  def validate(%__MODULE__{target: nil}) do
    {:error, :missing_target}
  end

  def validate(%__MODULE__{payload: nil}) do
    {:error, :missing_payload}
  end

  def validate(_) do
    {:error, :invalid_message_format}
  end
end
