defmodule XTrace.SpecParser do
  @moduledoc """
  Parses user-provided Elixir tspec strings into internal `{module, fun, args}` tuples.

  Supported formats:

      # List of tuples
      [{Enum, :map, :return_trace}, {Enum, :reduce, :return_trace}]

      # Single tuple
      {Enum, :map, :return_trace}
      {Enum, :map, 2}

      # Capture syntax (auto-generates match spec with return_trace)
      &Enum.map/2
  """

  @type tspec :: {module(), atom(), atom() | non_neg_integer() | list()}
  @banned_mods ~w(recon_trace io lists)

  @doc """
  Parses a raw string into a list of tspec tuples.

  Returns `{:ok, [tspec]}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, [tspec()]} | {:error, String.t()}
  def parse(raw) when is_binary(raw) do
    raw = String.trim(raw)

    case Code.string_to_quoted(raw) do
      {:ok, ast} ->
        convert(ast)

      {:error, {_meta, msg, token}} ->
        {:error, "Parse error: #{msg}#{token}"}
    end
  rescue
    e -> {:error, "Parse error: #{Exception.message(e)}"}
  end

  @doc """
  Checks a list of parsed tspecs for banned modules.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec check_banned_mods([tspec()]) :: :ok | {:error, String.t()}
  def check_banned_mods(specs) when is_list(specs) do
    banned =
      specs
      |> Enum.map(fn {mod, _, _} -> mod end)
      |> Enum.filter(&banned_mod?/1)
      |> Enum.uniq()

    case banned do
      [] -> :ok
      mods -> {:error, "Banned module(s): #{Enum.map_join(mods, ", ", &inspect/1)}"}
    end
  end

  defp banned_mod?(mod) when is_atom(mod) do
    mod_str = mod |> Atom.to_string() |> String.downcase()
    # Strip "Elixir." prefix for Elixir modules
    mod_str = String.replace_prefix(mod_str, "elixir.", "")
    Enum.member?(@banned_mods, mod_str)
  end

  # --- AST Conversion ---

  # List of specs: [{Mod, :fun, args}, ...]
  defp convert(list) when is_list(list) do
    results = Enum.map(list, &convert_one/1)
    errors = for {:error, e} <- results, do: e

    case errors do
      [] -> {:ok, for({:ok, spec} <- results, do: spec)}
      _ -> {:error, Enum.join(errors, "; ")}
    end
  end

  # Single tuple or capture
  defp convert(ast) do
    case convert_one(ast) do
      {:ok, spec} -> {:ok, [spec]}
      {:error, _} = err -> err
    end
  end

  # --- Single spec converters ---

  # Capture syntax: &Mod.fun/arity
  defp convert_one({:&, _, [{:/, _, [{{:., _, [mod_ast, fun]}, _, []}, arity]}]})
       when is_atom(fun) and is_integer(arity) and arity >= 0 do
    case resolve_module(mod_ast) do
      {:ok, mod} ->
        match_spec = [{List.duplicate(:_, arity), [], [{:return_trace}]}]
        {:ok, {mod, fun, match_spec}}

      {:error, _} = err ->
        err
    end
  end

  # 3-element tuple: {Mod, :fun, args}
  defp convert_one({:{}, _, [mod_ast, fun, args]}) when is_atom(fun) do
    with {:ok, mod} <- resolve_module(mod_ast),
         {:ok, args} <- resolve_args(args) do
      {:ok, {mod, fun, args}}
    end
  end

  # 2-element tuples are represented differently in AST (not {:{}, ...})
  # but tspecs are always 3-element, so we don't need to handle this

  defp convert_one(other) do
    {:error, "Unrecognized spec format: #{inspect(other)}"}
  end

  # --- Module resolution ---

  # Elixir module alias: {:__aliases__, _, [:Enum]} or {:__aliases__, _, [:MyApp, :Repo]}
  defp resolve_module({:__aliases__, _, parts}) when is_list(parts) do
    {:ok, Module.concat(parts)}
  end

  # Erlang module (bare atom): :gen_server, :ets, etc.
  defp resolve_module(mod) when is_atom(mod) do
    {:ok, mod}
  end

  defp resolve_module(other) do
    {:error, "Invalid module: #{inspect(other)}"}
  end

  # --- Args resolution ---

  # Atom args: :return_trace, :_, etc.
  defp resolve_args(args) when is_atom(args), do: {:ok, args}

  # Integer arity
  defp resolve_args(args) when is_integer(args) and args >= 0, do: {:ok, args}

  # Match spec list (pass through as-is after converting from AST)
  defp resolve_args(args) when is_list(args) do
    {:ok, resolve_match_spec(args)}
  end

  defp resolve_args(other) do
    {:error, "Invalid args: #{inspect(other)}"}
  end

  # --- Match spec deep conversion ---

  # Convert AST tuples in match spec to actual tuples
  defp resolve_match_spec(list) when is_list(list) do
    Enum.map(list, &resolve_match_spec/1)
  end

  defp resolve_match_spec({:{}, _, elements}) do
    elements
    |> Enum.map(&resolve_match_spec/1)
    |> List.to_tuple()
  end

  defp resolve_match_spec(atom) when is_atom(atom), do: atom
  defp resolve_match_spec(int) when is_integer(int), do: int
  defp resolve_match_spec(bin) when is_binary(bin), do: bin

  defp resolve_match_spec({:__aliases__, _, parts}) do
    Module.concat(parts)
  end

  defp resolve_match_spec(other), do: other
end
