defmodule Util do

  def get_cur_pcr_for_stream(pid, tsfile) do
    pid
    |> get_stream(tsfile)
    |> get_pgm_from_stream(tsfile)
    |> get_pcr_from_pgm
  end

  def get_stream(stream_pid, tsfile) do
    Enum.find(tsfile.streams, fn s -> s.pid == stream_pid end)
  end

  def get_updated_programs(programs, tsfile) do
    # programs is a list: [{pid, pgm_num}]
    programs
    |> Enum.filter(fn {pid, _pgm_num} ->
      not pid in Enum.map(tsfile.programs, fn pgm -> pgm.pid end)
    end)
    |> Enum.reduce(tsfile.programs,
      fn ({pid, pgm_num}, acc) -> [%TsProgram{pid: pid, pgm_num: pgm_num} | acc] end
    )
  end

  def get_updated_streams_and_programs({pcr_pid, stream_list}, pmt_pid, tsfile) do
    updated_streams = stream_list
    |> Enum.filter(fn {pid, stream_type} ->
      not pid in Enum.map(tsfile.streams, fn stm -> stm.pid end)
    end)
    |> Enum.reduce(tsfile.streams,
      fn ({pid, stream_type}, acc) -> [%TsStream{pid: pid, pmt_pid: pmt_pid, type: stream_type} | acc] end
    )

    updated_programs = Enum.map(tsfile.programs,
      fn p ->
        cond do
          (p.pid == pmt_pid) -> %{p | pcr_pid: pcr_pid}
          True -> p
        end
      end)
    {updated_streams, updated_programs}
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

end