defmodule EngineSystem.Engine.DSL.BehaviorBuilder do
  @moduledoc """
  I handle the behavior DSL for engine definitions.

  I manage:
  - Behavior rule definitions
  - Message handler definitions
  - Behavior validation
  """

  @doc """
  I define the behavior rules for the engine.

  ## Parameters

  - `block` - Block containing behavior rule definitions

  ## Returns

  Quoted AST for behavior definition
  """
  defmacro behaviour(do: block) do
    quote do
      Module.put_attribute(__MODULE__, :current_behaviour_rules, [])
      unquote(block)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)

      behaviour_rules =
        Module.get_attribute(__MODULE__, :current_behaviour_rules) |> Enum.reverse()

      updated_spec = %{spec_data | behaviour_rules: behaviour_rules}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_behaviour_rules)
    end
  end

  @doc """
  I define a message handler in the behavior.

  ## Parameters

  - `tag` - Message tag to handle
  - `block` - Handler implementation block

  ## Returns

  Quoted AST for message handler definition
  """
  defmacro on_message(tag, do: block) do
    quote do
      rule = {unquote(tag), unquote(Macro.escape(block))}
      current_rules = Module.get_attribute(__MODULE__, :current_behaviour_rules)
      Module.put_attribute(__MODULE__, :current_behaviour_rules, [rule | current_rules])
    end
  end

  @doc """
  I validate behavior rules.

  ## Parameters

  - `behaviour_rules` - List of behavior rules to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_behaviour_rules(list()) :: :ok | {:error, any()}
  def validate_behaviour_rules(rules) when is_list(rules) do
    validate_rules(rules)
  end

  def validate_behaviour_rules(_), do: {:error, :invalid_behaviour_rules}

  defp validate_rules([]), do: :ok

  defp validate_rules([{tag, _handler} | rest]) when is_atom(tag) do
    validate_rules(rest)
  end

  defp validate_rules(_), do: {:error, :invalid_rule_definition}

  @doc """
  I check if a message tag has a handler defined.

  ## Parameters

  - `tag` - Message tag to check
  - `behaviour_rules` - List of behavior rules

  ## Returns

  `true` if handler exists, `false` otherwise
  """
  @spec has_handler?(atom(), list()) :: boolean()
  def has_handler?(tag, behaviour_rules) do
    Enum.any?(behaviour_rules, fn {rule_tag, _handler} -> rule_tag == tag end)
  end

  @doc """
  I get the handler for a specific message tag.

  ## Parameters

  - `tag` - Message tag to find handler for
  - `behaviour_rules` - List of behavior rules

  ## Returns

  - `{:ok, handler}` if found
  - `{:error, :not_found}` if not found
  """
  @spec get_handler(atom(), list()) :: {:ok, any()} | {:error, :not_found}
  def get_handler(tag, behaviour_rules) do
    case Enum.find(behaviour_rules, fn {rule_tag, _handler} -> rule_tag == tag end) do
      {^tag, handler} -> {:ok, handler}
      nil -> {:error, :not_found}
    end
  end
end
