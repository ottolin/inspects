defmodule TsFile do
  defstruct fname: "",
  ts_residue: <<>>,
  pat_num: 0,
  programs: [],
  streams: []
end

defmodule TsProgram do
  defstruct pid: -1,
  pgm_num: -1,
  pcr_pid: -1,
  pcr_list: []
end

defmodule TsStream do
  defstruct pid: -1,
  pmt_pid: -1,
  type: :unknown, # :unknown, :aac, :m1l2, :ac3, :dolbye, :mpeg2v, :avc, :hevc, :subtitle, :teletext, :scte35, :id3, :avs, :vc1
  pkt2pts: [],
  ccerros: 0
end
