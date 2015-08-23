defmodule Inspects do
  def main(args) do
    args
    |> parse_args
    |> process
  end

  def parse_args(args) do
    {opt, _, _} = OptionParser.parse(args, switches: [file: :string])
    opt
  end

  def usage do
    IO.puts "inspects --file=/home/bar/foo.ts"
  end

  def process([]) do
    usage
  end

  def process(opt) do
    IO.puts "Processing #{opt[:file]}..."
    tsfile = %TsFile{fname: opt[:file]}

    [final_info] = File.stream!(tsfile.fname, [:read], 188 * 5000) # taking in 188 * 5k per read
    |> Stream.scan(tsfile, &Parser.Ts.parse/2)
    |> Stream.take(-1)
    |> Enum.to_list

    IO.inspect final_info
  end
end
