defmodule Inspects do
  def main(args) do
    args
    |> parse_args
    |> process
  end

  def parse_args(args) do
    {opt, path, _} = OptionParser.parse(args, switches: [])
    {opt, hd(path)}
  end

  def usage do
    IO.puts "inspects --file=/home/bar/foo.ts"
  end

  def process([]) do
    usage
  end

  def process({_opt, path}) do
    IO.puts "Processing #{path}..."
    tsfile = %TsFile{fname: path}

    [final_info] = File.stream!(tsfile.fname, [:read], 188 * 5000) # taking in 188 * 5k per read
    |> Stream.scan(tsfile, &Parser.Ts.parse/2)
    |> Stream.take(-1) # we are just interested in the last processing result
    |> Enum.to_list

    Printer.console_summary(final_info)
    stat_folder = Path.join(Path.dirname(tsfile.fname), Path.basename(tsfile.fname) <> ".stat")
    File.mkdir_p(stat_folder)
    Printer.write_statistics(final_info, stat_folder)
  end
end
