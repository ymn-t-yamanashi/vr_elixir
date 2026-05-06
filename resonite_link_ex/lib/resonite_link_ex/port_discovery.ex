defmodule ResoniteLinkEx.PortDiscovery do
  @moduledoc """
  ResoniteLink の待受ポートをホストの `ss -ltnp` 出力から検出する。
  """

  @invalid_request {:error, :invalid_request}

  @type cmd_fun :: (String.t(), [String.t()] -> {String.t(), non_neg_integer()})

  @doc """
  `ss -ltnp` を実行して ResoniteLink のポートを1つ返す。
  """
  @spec find_resonite_link_port() ::
          {:ok, pos_integer()}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port do
    find_resonite_link_port(&System.cmd/2, fn -> not is_nil(System.find_executable("ss")) end)
  end

  @doc """
  テストや拡張用途向けに、コマンド実行関数を差し替えてポート検出する。
  """
  @spec find_resonite_link_port(cmd_fun()) ::
          {:ok, pos_integer()}
          | {:error, :invalid_request}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port(cmd_fun) when is_function(cmd_fun, 2) do
    find_resonite_link_port(cmd_fun, fn -> not is_nil(System.find_executable("ss")) end)
  end

  def find_resonite_link_port(_cmd_fun), do: @invalid_request

  @doc """
  テストや拡張用途向けに、`ss` の存在判定も差し替えてポート検出する。
  """
  @spec find_resonite_link_port(cmd_fun(), (-> boolean())) ::
          {:ok, pos_integer()}
          | {:error, :invalid_request}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port(cmd_fun, ss_exists_fun)
      when is_function(cmd_fun, 2) and is_function(ss_exists_fun, 0) do
    with :ok <- ensure_ss_available(ss_exists_fun),
         {output, 0} <- cmd_fun.("ss", ["-ltnp"]),
         ports when is_list(ports) <- parse_ports(output),
         true <- ports != [] do
      {:ok, hd(ports)}
    else
      false -> {:error, :port_not_found}
      {:error, :ss_not_found} -> {:error, :ss_not_found}
      {_output, _status} -> {:error, :command_failed}
    end
  end

  def find_resonite_link_port(_cmd_fun, _ss_exists_fun), do: @invalid_request

  defp parse_ports(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.filter(fn line ->
      String.contains?(line, "dotnet") and
        String.contains?(line, "127.0.0.1:") and
        String.match?(line, ~r/\bLISTEN\b/) and
        String.match?(line, ~r/\s500\s+/)
    end)
    |> Enum.map(&extract_port/1)
    |> Enum.reject(&is_nil/1)
  end

  defp ensure_ss_available(ss_exists_fun) do
    if ss_exists_fun.(),
      do: :ok,
      else: {:error, :ss_not_found}
  end

  defp extract_port(line) do
    case Regex.run(~r/127\.0\.0\.1:(\d+)/, line) do
      [_, port_text] ->
        case Integer.parse(port_text) do
          {port, ""} when port > 0 and port <= 65_535 -> port
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
