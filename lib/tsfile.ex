defmodule TsFile do
  defstruct fname: "",
  ts_residue: <<>>,
  pat_num: 0,
  programs: [],
  streams: [],
  pos: 0
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
  ccerros: 0
end
