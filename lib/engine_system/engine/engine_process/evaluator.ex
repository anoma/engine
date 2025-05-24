defmodule EngineSystem.Engine.EngineProcess.Evaluator do
  @moduledoc """
  I handle code evaluation and binding creation for engine processes.

  I'm responsible for:
  - Building bindings from payload data
  - Evaluating guard expressions
  - Executing action code with proper context
  """

  require Logger

  alias EngineSystem.Engine.Compilation.Types.GuardedActionSpec
  alias EngineSystem.Engine.EngineProcess.Types

  @doc """
  I evaluate a guard expression for a guarded action.
  """
  @spec evaluate_guard(GuardedActionSpec.t(), any(), Types.config(), Types.environment()) ::
          boolean()
  def evaluate_guard(action, payload, config, environment) when not is_nil(action) do
    # This would use `Code.eval_quoted` to evaluate the guard expression
    # For safety and scope reasons, a more sophisticated approach would be needed in production

    # Create bindings for payload params
    payload_bindings = build_bindings_from_payload(action.payload_bindings_ast, payload)

    # Create bindings for context
    context_bindings = %{
      config: config,
      env: environment,
      # Will be filled in when executing the action
      sender: nil,
      # This is needed because the guard might use 'e' directly
      e: environment
    }

    # Combine all bindings
    all_bindings = Map.merge(payload_bindings, context_bindings)

    # Convert to Kernel format
    eval_bindings = Enum.map(all_bindings, fn {k, v} -> {k, v} end)

    # Evaluate the guard expression
    try do
      {result, _} = Code.eval_quoted(action.guard_ast, eval_bindings)
      # Ensure boolean result
      !!result
    rescue
      error ->
        Logger.warning("Guard evaluation failed: #{inspect(error)}")
        false
    end
  end

  @doc """
  I execute a guarded action and return the result.
  """
  @spec execute_action(
          GuardedActionSpec.t(),
          any(),
          Types.engine_address(),
          Types.config(),
          Types.environment(),
          atom()
        ) :: Types.action_result()
  def execute_action(action, payload, sender_address, config, environment, engine_type_name) do
    # Create bindings for payload params
    payload_bindings = build_bindings_from_payload(action.payload_bindings_ast, payload)

    # Create bindings for context
    context_bindings = %{
      config: config,
      env: environment,
      sender: sender_address,
      # Add direct bindings for variables used in the action
      # This is needed because the action uses 'e' directly
      e: environment
    }

    # Combine all bindings
    all_bindings = Map.merge(payload_bindings, context_bindings)

    # Convert to Kernel format
    eval_bindings = Enum.map(all_bindings, fn {k, v} -> {k, v} end)

    # Evaluate the action expression with the engine's module as context
    try do
      {result, _} = Code.eval_quoted(action.action_ast, eval_bindings, module: engine_type_name)
      result
    rescue
      error ->
        Logger.error("Action execution failed: #{inspect(error)}")
        nil
    end
  end

  @doc """
  I build variable bindings from payload data and binding AST.
  """
  @spec build_bindings_from_payload(any(), any()) :: %{atom() => any()}
  def build_bindings_from_payload(bindings_ast, payload) do
    # This is a simplification. In a real implementation, more sophisticated
    # pattern matching would be needed to extract bindings from the payload.
    # For now, we assume a simple list of parameter names.

    case {bindings_ast, payload} do
      {list, payload_tuple} when is_list(list) and is_tuple(payload_tuple) ->
        # Convert tuple to list for easier processing
        payload_list = Tuple.to_list(payload_tuple)

        # Make sure we have enough elements in the payload
        if length(list) <= length(payload_list) do
          # Create bindings map using only the number of parameters we have
          Enum.zip(list, Enum.take(payload_list, length(list)))
          |> Enum.into(%{})
        else
          # Not enough payload elements, create bindings with nil values
          (Enum.zip(list, payload_list) ++
             Enum.map(Enum.drop(list, length(payload_list)), fn name -> {name, nil} end))
          |> Enum.into(%{})
        end

      {list, nil} when is_list(list) ->
        # Handle nil payload by binding all parameters to nil
        Enum.map(list, fn name -> {name, nil} end)
        |> Enum.into(%{})

      {list, payload} when is_list(list) ->
        # Handle non-tuple payload by binding the first parameter to the payload
        if length(list) > 0 do
          first_param = List.first(list)
          rest_params = Enum.drop(list, 1)

          ([{first_param, payload}] ++ Enum.map(rest_params, fn name -> {name, nil} end))
          |> Enum.into(%{})
        else
          %{}
        end

      _ ->
        # Fallback for unknown binding formats
        %{}
    end
  end
end
