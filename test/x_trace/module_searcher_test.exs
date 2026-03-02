defmodule XTrace.ModuleSearcherTest do
  use ExUnit.Case, async: true

  alias XTrace.ModuleSearcher

  @sample_modules [
    "Phoenix.LiveView",
    "Phoenix.LiveView.Socket",
    "Phoenix.Controller",
    "Phoenix.Router",
    "GenServer",
    "GenStage",
    "Ecto.Query",
    "Ecto.Repo",
    "Ecto.Schema",
    "Plug.Conn",
    "Logger",
    "Enum",
    "Map",
    "String",
    "MyApp.Accounts.User",
    "MyApp.Accounts.UserToken",
    "MyApp.Repo",
    ":erlang",
    ":ets",
    ":lists"
  ]

  describe "search/2 with empty query" do
    test "returns first 50 items" do
      result = ModuleSearcher.search(@sample_modules, "")
      assert length(result) <= 50
      assert result == Enum.take(@sample_modules, 50)
    end
  end

  describe "search/2 exact match" do
    test "exact match ranks highest" do
      result = ModuleSearcher.search(@sample_modules, "GenServer")
      assert hd(result) == "GenServer"
    end

    test "case-insensitive exact match" do
      result = ModuleSearcher.search(@sample_modules, "genserver")
      assert hd(result) == "GenServer"
    end
  end

  describe "search/2 last segment prefix match" do
    test "matches last segment prefix" do
      result = ModuleSearcher.search(@sample_modules, "Sock")
      assert "Phoenix.LiveView.Socket" in result
    end

    test "Gen matches GenServer and GenStage" do
      result = ModuleSearcher.search(@sample_modules, "Gen")
      assert "GenServer" in result
      assert "GenStage" in result
    end
  end

  describe "search/2 segment exact match" do
    test "matches exact segment" do
      result = ModuleSearcher.search(@sample_modules, "Socket")
      assert "Phoenix.LiveView.Socket" in result
    end

    test "matches middle segment" do
      result = ModuleSearcher.search(@sample_modules, "Accounts")
      assert "MyApp.Accounts.User" in result
      assert "MyApp.Accounts.UserToken" in result
    end
  end

  describe "search/2 segment prefix match" do
    test "matches segment prefix" do
      result = ModuleSearcher.search(@sample_modules, "Live")
      assert "Phoenix.LiveView" in result
      assert "Phoenix.LiveView.Socket" in result
    end
  end

  describe "search/2 abbreviation match" do
    test "PLV matches Phoenix.LiveView" do
      result = ModuleSearcher.search(@sample_modules, "PLV")
      assert "Phoenix.LiveView" in result
    end

    test "PLVS matches Phoenix.LiveView.Socket" do
      result = ModuleSearcher.search(@sample_modules, "PLVS")
      assert "Phoenix.LiveView.Socket" in result
    end

    test "single letter does not trigger abbreviation" do
      result = ModuleSearcher.search(@sample_modules, "P")
      # Should match via prefix, not abbreviation
      assert Enum.all?(result, &String.contains?(String.downcase(&1), "p"))
    end
  end

  describe "search/2 camelCase match" do
    test "LiVi matches LiveView" do
      result = ModuleSearcher.search(@sample_modules, "LiVi")
      assert "Phoenix.LiveView" in result
      assert "Phoenix.LiveView.Socket" in result
    end

    test "UsTok matches UserToken" do
      result = ModuleSearcher.search(@sample_modules, "UsTok")
      assert "MyApp.Accounts.UserToken" in result
    end
  end

  describe "search/2 contains match" do
    test "case-insensitive contains" do
      result = ModuleSearcher.search(@sample_modules, "ect")
      assert Enum.any?(result, &String.starts_with?(&1, "Ecto"))
    end

    test "matches erlang modules" do
      result = ModuleSearcher.search(@sample_modules, "ets")
      assert ":ets" in result
    end
  end

  describe "search/2 result ordering" do
    test "exact match ranks above prefix match" do
      result = ModuleSearcher.search(@sample_modules, "Logger")
      assert hd(result) == "Logger"
    end

    test "last segment prefix ranks above contains" do
      result = ModuleSearcher.search(@sample_modules, "Repo")
      top_results = Enum.take(result, 3)
      assert "Ecto.Repo" in top_results
      assert "MyApp.Repo" in top_results
    end
  end

  describe "search/2 result limit" do
    test "returns at most 50 results" do
      large_list = for i <- 1..200, do: "Module#{i}"
      result = ModuleSearcher.search(large_list, "Module")
      assert length(result) == 50
    end
  end

  describe "search/2 no match" do
    test "returns empty for non-matching query" do
      result = ModuleSearcher.search(@sample_modules, "ZZZNotExist")
      assert result == []
    end
  end
end
