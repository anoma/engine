# Engines for Elixir

Everything has alternatives, even the `GenServer` library.

## Installation

For the time being, you can install the library by adding the following to your
`mix.exs` file:

```elixir
def deps do
  [
    {:engine, path: "../engine"}
  ]
end
```

Wherever you put the `engine` directory.

## Testing Guide

### Interactive Shell

1. Start the interactive shell:
    ```sh
    iex -S mix
    ```

2. Check the message interface for the `Ticker` engine:
    ```elixir
    iex> Ticker.message_tags()
    ```
    Expected output:
    ```elixir
    [:get_count, :tick]
    ```

3. Modify the `ticker.ex` file.

4. Reload the shell:
    ```elixir
    iex> recompile()
    ```

5. Check the message interface again.

### Running Tests

To run the tests:
    ```sh
    mix test
    ```

## Tested with

- Elixir 1.18.1
- Erlang 27.0
