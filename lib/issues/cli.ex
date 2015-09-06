defmodule Issues.CLI do
  alias Issues.TableFormatter, as: TF

  @default_count 4

  def run(argv) do
    argv |> parse_args |> process
  end

  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [help: :boolean], aliases: [h: :help])
    case parse do
      {[help: true], _, _} -> :help
      {_, [user, project, count], _} -> {user, project, String.to_integer(count)}
      {_, [user, project], _} -> {user, project, @default_count}
      _ -> :help
    end
  end

  def process(:help) do
    IO.puts """
    usage: issues <user> <project> [count | #{@default_count}]
    """
    System.halt(0)
  end

  def process({user, project, count}) do
    Issues.GithubIssues.fetch(user, project)
    |> decode_response
    |> convert_to_list_of_hashdicts
    |> sort_into_ascending_order
    |> Enum.take(count)
    |> TF.print_table_for_columns(["number", "created_at", "title"])
  end

  def decode_response({:ok, body}), do: body
  def decode_response({:error, error}) do
    {_, message} = List.keyfind(error, "message", 0)
    IO.puts "Error fetching from Github: #{message}"
    System.halt(2)
  end

  def convert_to_list_of_hashdicts(list) do
    list |> Enum.map(&Enum.into(&1, HashDict.new))
  end

  def sort_into_ascending_order(list_of_issues) do
    Enum.sort(list_of_issues,
      fn i1, i2 -> i1["created_at"] <= i2["created_at"] end
    )
  end

  def get_fields(list) do
    for hd <- list do
      {hd["id"], hd["created_at"], hd["title"]}
    end
  end

  def format_as_table(list) do
    ids = Enum.map(list, &elem(&1, 0))
    created_ats = Enum.map(list, &elem(&1, 1))
    titles = Enum.map(list, &elem(&1, 2))
    max_id = Enum.max(ids)
    max_created_at = Enum.max(created_ats)
    max_title = Enum.max_by(titles, &String.length/1)
    id_length = String.length("#{max_id}")
    created_at_length = String.length(max_created_at)
    title_length = String.length(max_title)
    IO.puts " #{String.ljust("#", id_length-1)} | #{String.ljust("created_at", created_at_length)} | #{String.ljust("title", title_length)}"
    IO.puts "#{String.duplicate("-", id_length+1)}+#{String.duplicate("-", created_at_length+2)}+#{String.duplicate("-", title_length+1)}"
    for row <- list do
      IO.puts "#{String.ljust(Integer.to_string(elem(row, 0)), id_length)} | #{String.ljust(elem(row, 1), created_at_length)} | #{String.ljust(elem(row, 2), title_length)}"
    end
  end

end