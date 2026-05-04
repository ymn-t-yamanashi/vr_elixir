defmodule Mix.Tasks.Check.Docs do
  use Mix.Task

  @shortdoc "公開関数の @doc 付与を検証する"

  @moduledoc """
  アプリケーション内の公開関数について `@doc` の有無を検証する。
  """

  @impl true
  @doc """
  公開関数の `@doc` 付与チェックを実行する。
  """
  def run(_args) do
    Mix.Task.run("compile", ["--warnings-as-errors"])

    app = Mix.Project.config()[:app]
    modules = Application.spec(app, :modules) || []

    violations =
      modules
      |> Enum.flat_map(&missing_docs_in_module/1)

    if violations == [] do
      Mix.shell().info("check.docs: 公開関数の @doc 付与を確認しました。")
    else
      lines =
        violations
        |> Enum.map_join("\n", fn {module, name, arity} ->
          "  - #{inspect(module)}.#{name}/#{arity}"
        end)

      Mix.raise("公開関数に @doc がありません:\n" <> lines)
    end
  end

  defp missing_docs_in_module(module) do
    public_defs = public_definitions(module)

    docs_map = function_docs_map(module)

    public_defs
    |> Enum.filter(fn {name, arity} ->
      doc = Map.get(docs_map, {name, arity}, :none)
      doc in [:none, :hidden]
    end)
    |> Enum.map(fn {name, arity} -> {module, name, arity} end)
  end

  defp public_definitions(module) do
    source = module.module_info(:compile)[:source]

    with source when is_list(source) <- source,
         {:ok, content} <- File.read(source),
         {:ok, ast} <- Code.string_to_quoted(content) do
      {_ast, defs} =
        Macro.prewalk(ast, MapSet.new(), fn
          {:def, _meta, [{:when, _, [{name, _ctx, args_ast} | _guards]} | _]} = node, acc
          when is_atom(name) ->
            arity = arity_of(args_ast)
            {node, MapSet.put(acc, {name, arity})}

          {:def, _meta, [{name, _ctx, args_ast} | _]} = node, acc when is_atom(name) ->
            arity = arity_of(args_ast)
            {node, MapSet.put(acc, {name, arity})}

          node, acc ->
            {node, acc}
        end)

      MapSet.to_list(defs)
    else
      _ -> []
    end
  end

  defp function_docs_map(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        docs
        |> Enum.filter(fn
          {{kind, _name, _arity}, _, _, _, _} when kind in [:function, :macro] -> true
          _ -> false
        end)
        |> Map.new(fn {{_kind, name, arity}, _anno, _sig, doc, _meta} ->
          {{name, arity}, doc}
        end)

      _ ->
        %{}
    end
  end

  defp arity_of(args_ast) when is_list(args_ast), do: length(args_ast)
  defp arity_of(_args_ast), do: 0
end
