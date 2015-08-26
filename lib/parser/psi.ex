defmodule Section do
  defstruct table_id: -1,
  section_syntax_indicator: -1,
  private_indicator: -1,
  reserved1: 0,
  section_length: 0,
  table_id_ext: -1,
  reserved2: 0,
  version: -1,
  cur_next_ind: -1,
  section_num: -1,
  last_section_num: -1,
  payload: "",
  crc32: 0

  def parse(<<table_id::8, 1::1, private_indicator::1, reserved1::2,
            section_length::12, table_id_ext::16, reserved2::2, version::5, cur_next_ind::1,
            section_num::8, last_section_num::8, rest::binary>>) do

    # section_syntax_indicator == 1, long section
    payload_len = section_length - 9;
    <<payload::binary-size(payload_len), crc32::32, _::binary>> = rest

    %Section{
      table_id: table_id,
      section_syntax_indicator: 1,
      private_indicator: private_indicator,
      reserved1: reserved1,
      section_length: section_length,
      table_id_ext: table_id_ext,
      reserved2: reserved2,
      version: version,
      cur_next_ind: cur_next_ind,
      section_num: section_num,
      last_section_num: last_section_num,
      payload: payload,
      crc32: crc32
    }
  end

  def parse(<<table_id::8, 0::1, private_indicator::1, reserved1::2,
            section_length::12, payload::binary-size(section_length)>>) do

    # section_syntax_indicator == 0, short section
    %Section{
      table_id: table_id,
      section_syntax_indicator: 0,
      private_indicator: private_indicator,
      reserved1: reserved1,
      section_length: section_length,
      payload: payload,
    }
  end
end

defmodule Parser.Psi do

  def pat(<<ptr_field::8, rest::binary>>) do
    # TODO: handling section > 1 pkt
    <<_prev_section::binary-size(ptr_field), section_bytes::binary>> = rest
    section = Section.parse(section_bytes)
    get_pgm(section.payload)
  end

  def pmt(<<ptr_field::8, rest::binary>>) do
    # TODO: handling section > 1 pkt
    <<_prev_section::binary-size(ptr_field), section_bytes::binary>> = rest
    section = Section.parse(section_bytes)

    <<_::3, pcr_pid::13, _::4, pgm_info_len::12, pgm_desc::binary-size(pgm_info_len), stream_info_bytes::binary>> = section.payload
    {pcr_pid, get_stream(stream_info_bytes)}

  end

  defp get_stream_type(type) do
    case type do
      0x01 -> :mpeg2v
      0x02 -> :mpeg2v
      0x03 -> :m1l2
      0x04 -> :m1l2
      0x0f -> :aac
      0x15 -> :id3
      0x1b -> :avc
      0x24 -> :hevc
      0x25 -> :hevc
      0x42 -> :avs
      0xea -> :vc1
      0x86 -> :scte35
      _    -> :others
    end
  end

  # return [{pid, stream_type}]
  defp get_stream(stream_info_payload) when is_binary(stream_info_payload) do
    get_stream(stream_info_payload, [])
  end

  defp get_stream(<<stream_type_id::8, _::3, pid::13, _::4, es_info_len::12, _descriptor::binary-size(es_info_len), rest::binary>>, streams) do
    stream_type = get_stream_type(stream_type_id)
    get_stream(rest, [{pid, stream_type} | streams])
  end

  defp get_stream(dont_care, streams) do
    Enum.reverse(streams)
  end

  # return [{pid, pgm_num}]
  defp get_pgm(pat_payload) when is_binary(pat_payload) do
    get_pgm(pat_payload, [])
  end

  defp get_pgm(<<program_number::16, _reserved::3, pid::13, rest::binary>>, programs) do
    get_pgm(rest, [{pid, program_number} | programs])
  end

  defp get_pgm(dont_care, programs) when is_binary(dont_care) do
    Enum.reverse(programs)
  end

end
