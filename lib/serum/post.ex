defmodule Serum.Post do
  @moduledoc """
  Defines a struct representing a blog post page.

  ## Fields

  * `file`: Source path
  * `title`: Post title
  * `date`: Post date (formatted)
  * `raw_date`: Post date (erlang tuple style)
  * `tags`: A list of tags
  * `url`: Absolute URL of the blog post in the website
  * `data`: Post contents
  * `output`: Destination path
  """

  alias Serum.Result
  alias Serum.Fragment
  alias Serum.HeaderParser
  alias Serum.Renderer
  alias Serum.Tag
  alias Serum.Template

  @type t :: %__MODULE__{
          file: binary(),
          title: binary(),
          date: binary(),
          raw_date: {:calendar.date(), :calendar.time()},
          tags: [Tag.t()],
          url: binary(),
          data: binary(),
          output: binary()
        }

  defstruct [
    :file,
    :title,
    :date,
    :raw_date,
    :tags,
    :url,
    :data,
    :output
  ]

  @metadata_keys [:title, :date, :raw_date, :tags, :url]

  @spec load(binary(), map()) :: Result.t(t())
  def load(path, proj) do
    with {:ok, file} <- File.open(path, [:read, :utf8]),
         {:ok, {header, data}} <- get_contents(file, path) do
      File.close(file)
      {:ok, create_struct(path, header, data, proj)}
    else
      {:error, reason} when is_atom(reason) -> {:error, {reason, path, 0}}
      {:error, _} = error -> error
    end
  end

  @spec get_contents(pid(), binary()) :: Result.t(map())
  defp get_contents(file, path) do
    opts = [
      title: :string,
      tags: {:list, :string},
      date: :datetime
    ]

    required = [:title]

    with {:ok, header} <- HeaderParser.parse_header(file, path, opts, required),
         data when is_binary(data) <- IO.read(file, :all) do
      header = %{
        header
        | date: header[:date] || Timex.to_datetime(Timex.zero(), :local)
      }

      {:ok, {header, data}}
    else
      {:error, reason} when is_atom(reason) -> {:error, {reason, path, 0}}
      {:error, _} = error -> error
    end
  end

  @spec create_struct(binary(), map(), binary(), map()) :: t()
  defp create_struct(path, header, data, proj) do
    tags = Tag.batch_create(header[:tags], proj)
    datetime = header[:date]
    date_str = Timex.format!(datetime, proj.date_format)
    raw_date = datetime |> Timex.to_erl()

    filename =
      path
      |> String.replace_suffix("md", "html")
      |> Path.relative_to(proj.src)

    %__MODULE__{
      file: path,
      title: header.title,
      tags: tags,
      data: data,
      raw_date: raw_date,
      date: date_str,
      url: Path.join(proj.base_url, filename),
      output: Path.join(proj.dest, filename)
    }
  end

  @spec to_fragment(t(), map()) :: Result.t(Fragment.t())
  def to_fragment(post, proj) do
    metadata =
      post
      |> Map.take(@metadata_keys)
      |> Map.put(:type, :post)

    case to_html(post, metadata, proj) do
      {:ok, html} ->
        {:ok, Fragment.new(post.file, post.output, metadata, html)}

      {:error, _} = error ->
        error
    end
  end

  @spec to_html(t(), map(), map()) :: Result.t(binary())
  def to_html(%__MODULE__{} = post, metadata, proj) do
    bindings = [page: metadata, contents: Earmark.as_html!(post.data)]
    template = Template.get("post")

    case Renderer.render_fragment(template, bindings) do
      {:ok, rendered} ->
        {:ok, Renderer.process_links(rendered, proj.base_url)}

      {:error, _} = error ->
        error
    end
  end
end

defimpl Inspect, for: Serum.Post do
  def inspect(post, _opts), do: ~s(#Serum.Post<"#{post.title}">)
end
