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
    updated_tsfile = parse_data(ts_data, tsfile)
    parse_ts(rest, updated_tsfile)
  end

  defp parse_ts(<<_::8, rest::binary>>, tsfile) when byte_size(rest) >= 188 do
    parse_ts(rest, tsfile)
  end

  defp parse_ts(tspkt_smaller_than_188, tsfile) do
    # simply drop it?
    %{tsfile | ts_residue: tspkt_smaller_than_188}
  end

  # function to extract ts payload
  defp payload(<<_::18, 0::1, 1::1, _::4, payload::binary>>) do
    payload
  end

  defp payload(<<_::18, 1::1, 1::1, adap_len::8, _adap::binary-size(adap_len), payload::binary>>) do
    payload
  end

  defp payload(<<_::18, _::1, 0::1, _::4, _payload::binary>>) do
    <<>>
  end

  defp get_type(pid, tsfile) do
    cond do
      pid == 0 -> :pat
      pid in Enum.map(tsfile.programs, fn pgm -> pgm.pid end) -> :pmt
      True -> :data
    end
  end

  defp parse_data(<<_::3, pid::13, _::binary>> = data, tsfile) when is_binary(data) do
    parse_data(get_type(pid, tsfile), pid, data, tsfile)
  end

  defp parse_data(:pat, 0, data, tsfile) do
    data
    |> payload
    |> Parser.Psi.pat(tsfile)
  end

  defp parse_data(:pmt, pid, data, tsfile) do
    data
    |> payload
    |> Parser.Psi.pmt(pid, tsfile)
  end

  defp parse_data(:data, pid, data, tsfile) do
    tsfile
  end

end
