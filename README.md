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

## For developers

To run the tests, you can run:

```sh
mix test
```

## Tested with

- Elixir 1.18.1
- Erlang 27.0
