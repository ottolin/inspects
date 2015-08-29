defmodule Parser.Probe do
  parser_list = [
    {:mpeg2v, &Parser.M2v.process/1},
  ]

  # Macros for generating different get_parser calls based on parser_list
  for {stream_type, parse_fn} <- parser_list do
    def get_parser(unquote(stream_type)) do
      unquote(parse_fn)
    end
  end

  # Default case for codec that doesnt need ES parsing
  def get_parser(_) do
    &Parser.Probe.noop/1
  end

  def noop(_) do
  end
end
