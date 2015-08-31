defmodule Parser.Ts do

  def parse(data, %TsFile{ts_residue: <<>>} = tsfile) when is_binary(data) do
    # No residue left last time. directly calling ts parsing
    parse_ts(data, tsfile)
  end

  def parse(data, %TsFile{ts_residue: last_residue} = tsfile) when is_binary(data) do
    parse_ts(<<last_residue, data>>, tsfile)
  end

  # function to handle non-188 align buffer.
  # although we wont use it that way in the inspects module
  defp parse_ts(<<0x47, ts_data::binary-size(187), rest::binary>>, tsfile) do
    # sync byte matched, doing real ts parsing
    updated_tsfile = parse_ts_187(ts_data, %{tsfile | pos: tsfile.pos + 1})
    parse_ts(rest, updated_tsfile)
  end

  defp parse_ts(<<_::8, rest::binary>>, tsfile) when byte_size(rest) >= 188 do
    parse_ts(rest, tsfile)
  end

  defp parse_ts(tspkt_smaller_than_188, tsfile) do
    # simply drop it?
    %{tsfile | ts_residue: tspkt_smaller_than_188}
  end

  defp parse_ts_187(<<_tei::1, pusi::1, _priority::1, pid::13, _::binary>> = data, tsfile) when is_binary(data) do
    tsfile1 = parse_ts_header(data, tsfile)
    parse_data(get_type(pid, tsfile1), pid, pusi, data, tsfile1)
  end

  # function to extract ts payload
  defp payload(<<_::18, 0::1, 1::1, _cc::4, payload::binary>>) do
    payload
  end

  defp payload(<<_::18, 1::1, 1::1, _cc::4, adap_len::8, _adap::binary-size(adap_len), payload::binary>>) do
    payload
  end

  defp payload(<<_::18, _::1, 0::1, _cc::4, _payload::binary>>) do
    <<>>
  end

  defp get_type(pid, tsfile) do
    cond do
      pid == 0 -> :pat
      pid in Enum.map(tsfile.programs, fn pgm -> pgm.pid end) -> :pmt
      True -> :data
    end
  end

  defp parse_adap_field(<<_discon::1, _rai::1, _priority::1, 1::1, _opcr::1, _splice::1, _tspriv::1, _ext::1, pcr33::33, _pad::6, pcr_ext::9, _rest::binary>> = _adap_field_bytes) do
    # we only care about pcr right now. can extend for other fields in the future
    pcr = (pcr33 * 300) + pcr_ext
    {pcr}
  end

  defp parse_adap_field(_) do
    {-1}
  end

  defp parse_ts_header(<<_::3, pid::13, _scramble::2, 1::1, _::1, _cc::4, adap_len::8, adap::binary-size(adap_len), _payload::binary>>, tsfile) do
    # currently we only care PCR. can extend for other fields also.
    {pcr} = parse_adap_field (adap)
    tsfile_rv = tsfile
    if pcr != -1 do
      cur_pcr = {tsfile.pos, pcr}
      if Enum.any?(tsfile.programs, fn p -> p.pcr_pid == pid end) do
        # This is a rogue pcr that doesnt belongs to any program
        rp = tsfile_rv.rogue_pcr[pid]
        rp = cond do
          rp == nil -> [cur_pcr]
          True -> [cur_pcr | rp]
        end
        tsfile_rv = %{tsfile_rv | rogue_pcr: Map.put(tsfile_rv.rogue_pcr, pid, rp)}
      else
        programs = tsfile.programs
        |> Enum.map(fn p ->
          cond do
            p.pcr_pid == pid -> %{p| cur_pcr: cur_pcr, pcr_list: [ cur_pcr | p.pcr_list]}
            True -> p
          end
        end)

        # Removing if it's in rogue list
        tsfile_rv = %{tsfile_rv | programs: programs, rogue_pcr: Map.delete(tsfile_rv.rogue_pcr, pid)}
      end
    end

    # TODO: cc error checking
    tsfile_rv
  end

  defp parse_ts_header(_, tsfile) do
    tsfile
  end

  defp parse_data(:pat, 0, _pusi, data, tsfile) do
    updated_programs = data
    |> payload
    |> Parser.Psi.pat
    |> Util.get_updated_programs(tsfile)

    %{tsfile | pat_num: tsfile.pat_num+1, programs: updated_programs}
  end

  defp parse_data(:pmt, pid, _pusi, data, tsfile) do
    {updated_streams, updated_programs} = data
    |> payload
    |> Parser.Psi.pmt
    |> Util.get_updated_streams_and_programs(pid, tsfile)

    %{tsfile | programs: updated_programs, streams: updated_streams}
  end

  defp parse_data(:data, pid, 0, data, tsfile) do
    # no pusi, update pes stream buffer
    stream = Util.get_stream(pid, tsfile)
    rv = tsfile
    if stream != nil && byte_size(stream.pes_buf) > 0 do
      updated_streams = Enum.map(tsfile.streams,
        fn s ->
          cond do
            (s.pid == pid) -> %{s | pes_buf: s.pes_buf <> payload(data)}
            True -> s
          end
        end)

      rv = %{tsfile | streams: updated_streams}
    end
    rv
  end

  defp parse_data(:data, pid, 1, data, tsfile) do
    parse_pes_header(pid, 1, payload(data), tsfile)
  end

  defp parse_pes_header(pid, 1, <<0x00, 0x00, 0x01, _stream_id::8, _pes_len::16, pes_header_and_rest::binary>>, tsfile) do
    stream = Util.get_stream(pid, tsfile)
    rv = tsfile
    if stream != nil do
      {pts, dts} = Parser.Pes.pts_dts(pes_header_and_rest)
      #IO.inspect {pid, pts, dts}
      {pcr_pos, pcr} = Util.get_cur_pcr_for_stream(pid, tsfile)
      stream.es_process_fn.(stream.pes_buf)
      stream = %{stream | timeinfo: [{tsfile.pos, pcr_pos, pcr, pts, dts} | stream.timeinfo],
                          # Reset pse_buf as we have new pes start
                          pes_buf: Parser.Pes.payload(pes_header_and_rest)}

      updated_streams = Enum.map(tsfile.streams,
        fn s ->
          cond do
            (s.pid == pid) -> stream
            True -> s
          end
        end)

      rv = %{tsfile | streams: updated_streams}
    end
    rv
  end

  defp parse_pes_header(_pid, 1, _no_pes_header, tsfile) do
    # Payload start but no pes header.
    # Section handling?
    tsfile
  end

end
