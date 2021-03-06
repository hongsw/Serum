defmodule Serum.Build.Pass1.PageBuilder do
  alias Serum.Result
  alias Serum.Page

  @spec run(map()) :: Result.t([Page.t()])
  def run(proj) do
    IO.puts("Collecting pages information...")
    page_dir = (proj.src == "." && "pages") || Path.join(proj.src, "pages")

    if File.exists?(page_dir) do
      files =
        [page_dir, "**", "*.{md,html,html.eex}"]
        |> Path.join()
        |> Path.wildcard()

      files
      |> Task.async_stream(Page, :load, [proj])
      |> Enum.map(&elem(&1, 1))
      |> Result.aggregate_values(:page_builder)
    else
      {:error, {page_dir, :enoent, 0}}
    end
  end
end
