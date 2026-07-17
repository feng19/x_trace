defmodule XTrace.Updater do
  @moduledoc """
  Self-update command.

  Checks GitHub for the latest published release and, if it is newer than the
  currently running version, downloads the matching binary for this OS/CPU and
  replaces the running Burrito wrapper binary in place.

  Invoked from the CLI:

      ./xtrace update          # check and (after confirmation) update
      ./xtrace update --yes    # skip the confirmation prompt

  Self-update only works for the packaged single-binary build; when run from a
  `mix` / dev context it prints a message and does nothing.

  Standard proxy environment variables are honoured: `HTTPS_PROXY` / `HTTP_PROXY`
  (with credentials, e.g. `http://user:pass@host:port`) and `NO_PROXY` (both
  upper-case and lower-case names are accepted).
  """

  @repo "feng19/x_trace"
  @api_url "https://api.github.com/repos/#{@repo}/releases/latest"
  @user_agent ~c"x_trace-self-updater"

  @doc """
  Returns `true` when the first CLI argument is the `update` command.
  """
  @spec command?() :: boolean()
  def command? do
    match?(["update" | _], Burrito.Util.Args.argv())
  end

  @doc """
  Runs the `update` command and returns an exit code (0 on success/no-op, 1 on
  failure). Intended to be passed straight to `System.halt/1`.
  """
  @spec run() :: 0 | 1
  def run do
    opts = parse_opts()

    try do
      with :ok <- ensure_standalone(),
           {:ok, bin_path} <- bin_path(),
           {:ok, asset_name} <- asset_name(),
           {:ok, release} <- fetch_latest_release(),
           {:ok, latest} <- release_version(release),
           :ok <- check_newer(latest),
           {:ok, url} <- asset_url(release, asset_name),
           :ok <- confirm(latest, opts),
           :ok <- download_and_replace(url, bin_path) do
        IO.puts(
          IO.ANSI.green() <>
            "✔ Updated to v#{latest}. Restart xtrace to use the new version." <>
            IO.ANSI.reset()
        )

        :ok
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
    |> case do
      :ok -> 0
      :up_to_date -> 0
      :cancelled -> 0
      {:error, reason} -> fail(reason)
    end
  end

  defp fail(reason) do
    IO.puts(:stderr, IO.ANSI.red() <> "✖ Update failed: #{reason}" <> IO.ANSI.reset())
    1
  end

  # --- steps -----------------------------------------------------------------

  defp ensure_standalone do
    if Burrito.Util.running_standalone?() do
      :ok
    else
      {:error, "self-update is only available for the packaged binary"}
    end
  end

  defp bin_path do
    case Burrito.Util.Args.get_bin_path() do
      path when is_binary(path) -> {:ok, path}
      :not_in_burrito -> {:error, "could not locate the running binary"}
    end
  end

  defp asset_name do
    case {Burrito.Util.get_current_os(), Burrito.Util.get_current_cpu()} do
      {:darwin, :x86_64} -> {:ok, "xtrace_macos"}
      {:darwin, :aarch64} -> {:ok, "xtrace_macos_aarch64"}
      {:linux, :x86_64} -> {:ok, "xtrace_linux"}
      {:linux, :aarch64} -> {:ok, "xtrace_linux_aarch64"}
      {:windows, :x86_64} -> {:ok, "xtrace_windows.exe"}
      {os, cpu} -> {:error, "no release asset available for #{os}/#{cpu}"}
    end
  end

  defp fetch_latest_release do
    ensure_http_started()
    IO.puts("Checking for the latest release …")

    headers = [
      {~c"user-agent", @user_agent},
      {~c"accept", ~c"application/vnd.github+json"}
    ]

    request = {String.to_charlist(@api_url), headers}

    case :httpc.request(:get, request, http_opts(), body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, {{_, status, _}, _headers, _body}} ->
        {:error, "GitHub API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, "could not reach GitHub: #{inspect(reason)}"}
    end
  end

  defp release_version(%{"tag_name" => "v" <> vsn}), do: {:ok, vsn}
  defp release_version(%{"tag_name" => vsn}) when is_binary(vsn), do: {:ok, vsn}
  defp release_version(_), do: {:error, "could not read the latest release version"}

  defp check_newer(latest) do
    current = current_version()

    case safe_compare(latest, current) do
      :gt ->
        IO.puts("A new version is available: v#{current} → v#{latest}")
        :ok

      _ ->
        IO.puts("You are already on the latest version (v#{current}).")
        :up_to_date
    end
  end

  defp asset_url(%{"assets" => assets}, name) when is_list(assets) do
    case Enum.find(assets, &(&1["name"] == name)) do
      %{"browser_download_url" => url} when is_binary(url) -> {:ok, url}
      _ -> {:error, "release does not include asset \"#{name}\""}
    end
  end

  defp asset_url(_release, name), do: {:error, "release does not include asset \"#{name}\""}

  defp confirm(_latest, %{yes: true}), do: :ok

  defp confirm(latest, _opts) do
    case IO.gets("Download and install v#{latest}? [Y/n] ") do
      response when is_binary(response) ->
        case response |> String.trim() |> String.downcase() do
          answer when answer in ["", "y", "yes"] -> :ok
          _ -> IO.puts("Update cancelled.") && :cancelled
        end

      # non-interactive (piped / EOF) → proceed
      _ ->
        :ok
    end
  end

  defp download_and_replace(url, bin_path) do
    tmp = bin_path <> ".download"
    File.rm(tmp)
    IO.puts("Downloading …")

    request = {String.to_charlist(url), [{~c"user-agent", @user_agent}]}

    case :httpc.request(:get, request, http_opts(), stream: String.to_charlist(tmp)) do
      {:ok, :saved_to_file} ->
        IO.puts("Installing …")
        install(tmp, bin_path)

      {:ok, {{_, status, _}, _headers, _body}} ->
        File.rm(tmp)
        {:error, "download failed with HTTP #{status}"}

      {:error, reason} ->
        File.rm(tmp)
        {:error, "download failed: #{inspect(reason)}"}
    end
  end

  defp install(tmp, bin_path) do
    File.chmod(tmp, 0o755)

    case Burrito.Util.get_current_os() do
      :windows -> install_windows(tmp, bin_path)
      _ -> install_unix(tmp, bin_path)
    end
  end

  # On unix a running executable's file can be replaced atomically while the
  # process keeps using the old inode; the new binary is picked up on restart.
  defp install_unix(tmp, bin_path) do
    case File.rename(tmp, bin_path) do
      :ok ->
        :ok

      {:error, reason} ->
        File.rm(tmp)
        {:error, replace_error(reason, bin_path)}
    end
  end

  # On Windows a running .exe cannot be overwritten, but it can be renamed away,
  # so move the old one aside and drop the new one in its place.
  defp install_windows(tmp, bin_path) do
    backup = bin_path <> ".old"
    File.rm(backup)

    with :ok <- File.rename(bin_path, backup),
         :ok <- File.rename(tmp, bin_path) do
      :ok
    else
      {:error, reason} ->
        File.rename(backup, bin_path)
        File.rm(tmp)
        {:error, replace_error(reason, bin_path)}
    end
  end

  defp replace_error(reason, bin_path) when reason in [:eacces, :eperm] do
    "permission denied writing #{bin_path}; try again with elevated privileges"
  end

  defp replace_error(reason, bin_path) do
    "could not replace #{bin_path}: #{List.to_string(:file.format_error(reason))}"
  end

  # --- helpers ---------------------------------------------------------------

  defp parse_opts do
    {parsed, _rest, _invalid} =
      Burrito.Util.Args.argv()
      |> Enum.drop(1)
      |> OptionParser.parse(aliases: [y: :yes], strict: [yes: :boolean])

    %{yes: Keyword.get(parsed, :yes, false)}
  end

  defp current_version, do: :x_trace |> Application.spec(:vsn) |> to_string()

  defp safe_compare(a, b) do
    Version.compare(a, b)
  rescue
    _ -> if a == b, do: :eq, else: :gt
  end

  defp ensure_http_started do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    # Honour standard proxy env vars; stash proxy credentials (if any) for the
    # per-request `proxy_auth` option, which `set_options/1` cannot carry.
    Process.put(:proxy_auth, configure_proxy())
    :ok
  end

  defp http_opts do
    base = [
      timeout: 120_000,
      connect_timeout: 15_000,
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    case Process.get(:proxy_auth) do
      {_user, _pass} = auth -> [{:proxy_auth, auth} | base]
      _ -> base
    end
  end

  # Reads HTTP(S)_PROXY / NO_PROXY (upper or lower case), configures :httpc, and
  # returns `{user, pass}` proxy credentials or nil. Our requests are HTTPS, so
  # the returned auth belongs to the HTTPS proxy.
  defp configure_proxy do
    no_proxy = no_proxy_list()
    https = proxy_uri(["HTTPS_PROXY", "https_proxy"])
    http = proxy_uri(["HTTP_PROXY", "http_proxy"])

    opts =
      []
      |> put_proxy(:https_proxy, https, no_proxy)
      |> put_proxy(:proxy, http, no_proxy)

    unless opts == [], do: :httpc.set_options(opts)

    proxy_auth(https)
  end

  defp put_proxy(opts, _key, nil, _no_proxy), do: opts

  defp put_proxy(opts, key, %URI{host: host, port: port}, no_proxy) when is_binary(host) do
    [{key, {{String.to_charlist(host), port || 80}, no_proxy}} | opts]
  end

  defp proxy_uri(names) do
    with value when is_binary(value) <- env_any(names),
         value = if(String.contains?(value, "://"), do: value, else: "http://" <> value),
         %URI{host: host} = uri when is_binary(host) <- URI.parse(value) do
      uri
    else
      _ -> nil
    end
  end

  defp no_proxy_list do
    case env_any(["NO_PROXY", "no_proxy"]) do
      nil ->
        []

      value ->
        value
        |> String.split(",", trim: true)
        |> Enum.map(&(&1 |> String.trim() |> String.to_charlist()))
    end
  end

  defp proxy_auth(%URI{userinfo: info}) when is_binary(info) do
    case String.split(info, ":", parts: 2) do
      [user, pass] -> {String.to_charlist(user), String.to_charlist(pass)}
      [user] -> {String.to_charlist(user), ~c""}
    end
  end

  defp proxy_auth(_), do: nil

  defp env_any(names) do
    Enum.find_value(names, fn name ->
      case System.get_env(name) do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end
    end)
  end
end
