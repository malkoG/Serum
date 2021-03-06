defmodule Serum.Build.Pass1.PostBuilder do
  import Serum.Util
  alias Serum.Result
  alias Serum.Post

  @spec run(map()) :: Result.t([Post.t()])
  def run(proj) do
    proj.src
    |> load_file_list()
    |> Task.async_stream(Post, :load, [proj])
    |> Enum.map(&elem(&1, 1))
    |> Result.aggregate_values(:post_builder)
  end

  @spec load_file_list(binary()) :: [binary()]
  defp load_file_list(src) do
    IO.puts("Collecting posts information...")
    post_dir = (src == "." && "posts") || Path.join(src, "posts")

    if File.exists?(post_dir) do
      [post_dir, "*.md"]
      |> Path.join()
      |> Path.wildcard()
      |> Enum.sort()
    else
      warn("Cannot access `posts/'. No post will be generated.")
      []
    end
  end
end
