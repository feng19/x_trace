defmodule XTrace.SpecParserTest do
  use ExUnit.Case, async: true

  alias XTrace.SpecParser

  describe "single tuple" do
    test "parses {Mod, :fun, :return_trace}" do
      assert {:ok, [{Enum, :map, :return_trace}]} =
               SpecParser.parse("{Enum, :map, :return_trace}")
    end

    test "parses {Mod, :fun, arity}" do
      assert {:ok, [{Enum, :map, 2}]} =
               SpecParser.parse("{Enum, :map, 2}")
    end

    test "parses {:_, :_, :_}" do
      assert {:ok, [{:_, :_, :_}]} =
               SpecParser.parse("{:_, :_, :_}")
    end

    test "parses erlang module tuple" do
      assert {:ok, [{:ets, :lookup, 2}]} =
               SpecParser.parse("{:ets, :lookup, 2}")
    end

    test "parses multi-segment module" do
      assert {:ok, [{MyApp.Repo, :get, :return_trace}]} =
               SpecParser.parse("{MyApp.Repo, :get, :return_trace}")
    end
  end

  describe "list of tuples" do
    test "parses list of tuples" do
      input = "[{Enum, :map, :return_trace}, {Enum, :reduce, :return_trace}]"

      assert {:ok, specs} = SpecParser.parse(input)
      assert length(specs) == 2
      assert {Enum, :map, :return_trace} in specs
      assert {Enum, :reduce, :return_trace} in specs
    end

    test "parses list with mixed args types" do
      input = "[{Enum, :map, 2}, {Enum, :reduce, :return_trace}]"

      assert {:ok, specs} = SpecParser.parse(input)
      assert {Enum, :map, 2} in specs
      assert {Enum, :reduce, :return_trace} in specs
    end
  end

  describe "capture syntax" do
    test "parses &Mod.fun/arity" do
      assert {:ok, [{Enum, :map, match_spec}]} = SpecParser.parse("&Enum.map/2")
      assert [{[:_, :_], [], [{:return_trace}]}] = match_spec
    end

    test "parses &Mod.fun/0" do
      assert {:ok, [{Enum, :count, match_spec}]} = SpecParser.parse("&Enum.count/0")
      assert [{[], [], [{:return_trace}]}] = match_spec
    end

    test "parses erlang capture &:mod.fun/arity" do
      assert {:ok, [{:ets, :lookup, match_spec}]} = SpecParser.parse("&:ets.lookup/2")
      assert [{[:_, :_], [], [{:return_trace}]}] = match_spec
    end
  end

  describe "match spec passthrough" do
    test "parses tuple with explicit match spec" do
      input = ~s/{Enum, :map, [{[:_, :_], [], [{:return_trace}]}]}/

      assert {:ok, [{Enum, :map, match_spec}]} = SpecParser.parse(input)
      assert [{[:_, :_], [], [{:return_trace}]}] = match_spec
    end
  end

  describe "error handling" do
    test "returns error for invalid syntax" do
      assert {:error, _reason} = SpecParser.parse("not valid elixir {{{")
    end

    test "returns error for empty string" do
      assert {:error, _reason} = SpecParser.parse("")
    end

    test "returns error for unrecognized format" do
      assert {:error, _reason} = SpecParser.parse("42")
    end
  end
end
