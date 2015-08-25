defmodule Util do

  def get_cur_pcr_for_stream(pid, tsfile) do
    pid
    |> get_stream(tsfile)
    |> get_pgm_from_stream(tsfile)
    |> get_pcr_from_pgm
  end

  defp get_pcr_from_pgm(nil) do
    {-1, -1}
  end

  defp get_pcr_from_pgm(program) do
    program.cur_pcr
  end

  defp get_pgm_from_stream(nil, _tsfile) do
    nil
  end

  defp get_pgm_from_stream(stream, tsfile) do
    get_pgm(stream.pmt_pid, tsfile)
  end

  defp get_pgm(nil, _tsfile) do
    nil
  end

  defp get_pgm(pmt_pid, tsfile) do
    Enum.find(tsfile.programs, fn p -> p.pid == pmt_pid end)
  end

  def get_stream(stream_pid, tsfile) do
    Enum.find(tsfile.streams, fn s -> s.pid == stream_pid end)
  end
end
