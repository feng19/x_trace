defmodule XTrace.ModuleSearcher do
  @moduledoc """
  Smart search for Elixir/Erlang module names.
  Supports prefix, segment, abbreviation, camelCase, and fuzzy matching with relevance scoring.
  """

  @max_results 50

  @doc """
  Search module names with smart matching and relevance scoring.

  Returns at most #{@max_results} results sorted by match quality.

  ## Match strategies (by priority):
  1. Exact match (case-insensitive) → 100
  2. Last segment prefix match → 80
  3. Segment exact match → 70
  4. Any segment prefix match → 60
  5. Abbreviation match (e.g. "PLV" → "Phoenix.LiveView") → 50
  6. CamelCase match (e.g. "LiVi" → "Phoenix.LiveView") → 40
  7. Contains match (case-insensitive) → 30
  """
  @spec search([String.t()], String.t()) :: [String.t()]
  def search(module_list, query) do
    {results, _total} = search_with_total(module_list, query)
    results
  end

  @doc """
  Like `search/2`, but also returns the total number of matches before truncation.

  Returns `{results, total_matches}`.
  """
  @spec search_with_total([String.t()], String.t()) :: {[String.t()], non_neg_integer()}
  def search_with_total(module_list, "") do
    total = length(module_list)
    {Enum.take(module_list, @max_results), total}
  end

  def search_with_total(module_list, query) do
    query_down = String.downcase(query)

    scored =
      module_list
      |> Stream.map(fn module_str ->
        score = match_score(module_str, query, query_down)
        {module_str, score}
      end)
      |> Stream.filter(fn {_, score} -> score > 0 end)
      |> Enum.sort_by(fn {_, score} -> -score end)

    total = length(scored)

    results =
      scored
      |> Enum.take(@max_results)
      |> Enum.map(fn {module_str, _} -> module_str end)

    {results, total}
  end

  defp match_score(module_str, query, query_down) do
    module_down = String.downcase(module_str)
    segments = String.split(module_str, ".")
    last_segment = List.last(segments) || module_str
    last_down = String.downcase(last_segment)

    cond do
      # Exact match (case-insensitive)
      module_down == query_down -> 100
      # Last segment prefix match
      String.starts_with?(last_down, query_down) -> 80
      # Segment exact match
      Enum.any?(segments, &(String.downcase(&1) == query_down)) -> 70
      # Any segment prefix match
      Enum.any?(segments, &String.starts_with?(String.downcase(&1), query_down)) -> 60
      # Abbreviation match (uppercase letters match segment initials)
      abbreviation_match?(segments, query) -> 50
      # CamelCase match (e.g. "LiVi" matches "LiveView")
      camel_case_match?(module_str, query) -> 40
      # Contains match (case-insensitive)
      String.contains?(module_down, query_down) -> 30
      # No match
      true -> 0
    end
  end

  # Abbreviation match: query must be all uppercase and > 1 char
  # e.g. "PLV" matches "Phoenix.LiveView" (initials P, L, V)
  defp abbreviation_match?(segments, query) do
    if query == String.upcase(query) and String.length(query) > 1 do
      initials = segments |> Enum.map(&String.first/1) |> Enum.join()
      String.contains?(String.upcase(initials), query)
    else
      false
    end
  end

  # CamelCase match: split query by uppercase letters into parts,
  # then check if they match a subsequence of camelCase words in the module name.
  # e.g. "LiVi" -> ["Li", "Vi"] matches "LiveView" -> ["Live", "View"]
  defp camel_case_match?(module_str, query) do
    query_parts = split_camel(query)

    if length(query_parts) > 1 do
      words = module_str |> String.split(".") |> Enum.flat_map(&split_camel/1)
      subsequence_prefix_match?(words, query_parts)
    else
      false
    end
  end

  # Split a camelCase string into words
  # "LiveView" -> ["Live", "View"], "GenServer" -> ["Gen", "Server"]
  defp split_camel(str) do
    str
    |> String.replace(~r/([A-Z])/, " \\1")
    |> String.split(" ", trim: true)
  end

  # Check if query_parts match a subsequence of words by prefix
  defp subsequence_prefix_match?(_words, []), do: true
  defp subsequence_prefix_match?([], _query_parts), do: false

  defp subsequence_prefix_match?([word | rest_words], [qpart | rest_qparts]) do
    if String.starts_with?(String.downcase(word), String.downcase(qpart)) do
      subsequence_prefix_match?(rest_words, rest_qparts)
    else
      subsequence_prefix_match?(rest_words, [qpart | rest_qparts])
    end
  end
end
