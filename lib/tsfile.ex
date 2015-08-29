import Kernel, except: [to_string: 1] # we will implement our own to_string functions

defmodule TsFile do
  defstruct fname: "",
  ts_residue: <<>>,
  pat_num: 0,
  programs: [],
  streams: [],
  pos: 0
end

defimpl String.Chars, for: TsFile do
  def to_string(tsfile) do
    "File: " <> tsfile.fname <> "\n" <>
    # Printing for each program and corresponding streams associated with the program
    Enum.reduce(tsfile.programs, "",
      fn (p, acc) ->
        acc <>
        "\tProgram: " <> Integer.to_string(p.pgm_num) <> " (Pid: " <> Integer.to_string(p.pid) <> ")\n" <>
        "\tPcr Pid: " <> Integer.to_string(p.pcr_pid) <> "\n" <>
        Enum.reduce(tsfile.streams, "",
          fn (s, acc) ->
            cond do
              s.pmt_pid != p.pid -> acc
              True -> acc <> Util.stream_to_string(s)
            end
          end
        )
        <> "\n"
      end
    ) <>
    # Printing for streams that is not associated with any program
    Enum.reduce(tsfile.streams, "",
      fn (s, acc) ->
        cond do
          s.pmt_pid == -1 -> acc <> Util.stream_to_string(s)
          True -> acc
        end
      end
    )

  end
end

defmodule TsProgram do
  defstruct pid: -1,
  pgm_num: -1,
  pcr_pid: -1,
  pcr_list: [],
  cur_pcr: {-1, -1} # {position, pcr}
end

defmodule TsStream do
  defstruct pid: -1,
  pmt_pid: -1,
  type: :unknown, # :unknown, :aac, :m1l2, :ac3, :dolbye, :mpeg2v, :avc, :hevc, :subtitle, :teletext, :scte35, :id3, :avs, :vc1
  timeinfo: [], # {pkt_pos, pcr_pos, pcr, pts, dts}
  ccerros: 0,
  last_cc: -1,
  pes_buf: "",
  es_process_fn: &Parser.Probe.noop/1
end
