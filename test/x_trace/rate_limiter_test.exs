defmodule XTrace.RateLimiterTest do
  use ExUnit.Case, async: true

  alias XTrace.RateLimiter

  describe "count mode" do
    test "new/1 creates count limiter" do
      rl = RateLimiter.new(3)
      assert rl.mode == :count
      assert rl.max == 3
      assert rl.count == 0
    end

    test "allows up to max messages" do
      rl = RateLimiter.new(3)

      {:ok, rl} = RateLimiter.check(rl)
      assert rl.count == 1

      {:ok, rl} = RateLimiter.check(rl)
      assert rl.count == 2

      {:ok, rl} = RateLimiter.check(rl)
      assert rl.count == 3

      assert :rate_limited = RateLimiter.check(rl)
    end

    test "single message limit" do
      rl = RateLimiter.new(1)
      {:ok, rl} = RateLimiter.check(rl)
      assert :rate_limited = RateLimiter.check(rl)
    end
  end

  describe "rate mode" do
    test "new/2 creates rate limiter" do
      rl = RateLimiter.new(5, 1000)
      assert rl.mode == :rate
      assert rl.max == 5
      assert rl.time_ms == 1000
      assert rl.count == 0
    end

    test "allows up to max messages within window" do
      rl = RateLimiter.new(2, 60_000)

      {:ok, rl} = RateLimiter.check(rl)
      {:ok, _rl} = RateLimiter.check(rl)
    end

    test "rate limits when exceeding max in window" do
      rl = RateLimiter.new(2, 60_000)

      {:ok, rl} = RateLimiter.check(rl)
      {:ok, rl} = RateLimiter.check(rl)
      assert :rate_limited = RateLimiter.check(rl)
    end
  end

  describe "from_max/1" do
    test "integer creates count mode" do
      rl = RateLimiter.from_max(10)
      assert rl.mode == :count
      assert rl.max == 10
    end

    test "tuple creates rate mode" do
      rl = RateLimiter.from_max({5, 1000})
      assert rl.mode == :rate
      assert rl.max == 5
      assert rl.time_ms == 1000
    end
  end
end
