defmodule Printer do
  def console_summary(tsfile) do
    # print summary to console
    IO.puts tsfile
  end

  def write_statistics(tsfile, output_folder) do
    # Writing stream summary
    summary = to_string tsfile;
    File.write(Path.join(output_folder, "summary.log"), summary)
    # Writing stream stat
    Enum.each(tsfile.streams,
      fn s ->
        stat_file = Path.join(output_folder, "#{s.pid}.csv")
        {:ok, f} = File.open(stat_file, [:write, :delayed_write])
        IO.write(f, "pkt_pos, pcr_pos, pcr, pts, dts, dts-pcr\n")
        Enum.each(Enum.reverse(s.timeinfo),
          fn {pkt_pos, pcr_pos, pcr, pts, dts} ->
            IO.write(f, "#{pkt_pos}, #{pcr_pos}, #{pcr}, #{pts}, #{dts}, #{dts - pcr}\n")
          end)
        File.close(f)
      end
    )

    # Writing pcr stat
    Enum.each(tsfile.programs,
      fn p ->
        stat_file = Path.join(output_folder, "pcr-#{p.pcr_pid}.csv")
        {:ok, f} = File.open(stat_file, [:write, :delayed_write])
        IO.write(f, "pkt_pos, pcr, bitrate\n")
        Enum.scan(Enum.reverse(p.pcr_list), {-1, -1},
          fn ({pos, pcr}, {last_pos, last_pcr}) ->
            str = "#{pos}, #{pcr}"
            if (last_pos != -1 && last_pcr != -1) do
              bitrate = 1504*(pos - last_pos) * 27000000 / (pcr - last_pcr)
              str = str <> ", #{bitrate}"
            end
            IO.write(f, str <> "\n")
            {pos, pcr}
          end)
        File.close(f)
      end
    )
  end
end
