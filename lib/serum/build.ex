defmodule Serum.Build do
  import Serum.Util
  alias Serum.Result
  alias Serum.Build.Pass1
  alias Serum.Build.Pass2
  alias Serum.Build.Pass3
  alias Serum.TemplateLoader

  @spec build(map()) :: Result.t(binary())
  def build(proj) do
    with :ok <- check_tz(),
         :ok <- check_dest_perm(proj.dest),
         :ok <- clean_dest(proj.dest),
         :ok <- prepare_templates(proj.src),
         :ok <- do_build(proj) do
      copy_assets(proj.src, proj.dest)
      {:ok, proj.dest}
    else
      {:error, _} = error -> error
    end
  end

  @spec do_build(map()) :: Result.t()
  defp do_build(proj) do
    proj
    |> Pass1.run()
    |> Pass2.run(proj)
    |> Pass3.run()
  end

  # Checks if the system timezone is set and valid.
  @spec check_tz() :: Result.t()
  defp check_tz do
    try do
      Timex.local()
      :ok
    rescue
      _ -> {:error, "system timezone is not set"}
    end
  end

  # Checks if the effective user have a write
  # permission on the destination directory.
  @spec check_dest_perm(binary) :: Result.t()
  defp check_dest_perm(dest) do
    parent = dest |> Path.join("") |> Path.dirname()

    result =
      case File.stat(parent) do
        {:error, reason} -> reason
        {:ok, %File.Stat{access: :none}} -> :eacces
        {:ok, %File.Stat{access: :read}} -> :eacces
        {:ok, _} -> :ok
      end

    case result do
      :ok -> :ok
      err -> {:error, {err, dest, 0}}
    end
  end

  # Removes all files and directories in the destination directory,
  # excluding dotfiles so that git repository is not blown away.
  @spec clean_dest(binary) :: :ok
  defp clean_dest(dest) do
    File.mkdir_p!(dest)
    msg_mkdir(dest)

    dest
    |> File.ls!()
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.map(&Path.join(dest, &1))
    |> Enum.each(&File.rm_rf!(&1))
  end

  @spec prepare_templates(binary()) :: Result.t()
  defp prepare_templates(src) do
    with :ok <- TemplateLoader.load_includes(src),
         :ok <- TemplateLoader.load_templates(src) do
      :ok
    else
      {:error, _} = error -> error
    end
  end

  @spec copy_assets(binary(), binary()) :: :ok
  defp copy_assets(src, dest) do
    IO.puts("Copying assets and media...")
    try_copy(Path.join(src, "assets"), Path.join(dest, "assets"))
    try_copy(Path.join(src, "media"), Path.join(dest, "media"))
  end

  @spec try_copy(binary, binary) :: :ok
  defp try_copy(src, dest) do
    case File.cp_r(src, dest) do
      {:error, reason, _} ->
        warn("Cannot copy #{src}: #{:file.format_error(reason)}. Skipping.")

      {:ok, _} ->
        :ok
    end
  end
end
