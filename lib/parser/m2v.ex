defmodule Parser.M2v do
  def process("") do
  end

  def process(es_bytes) when is_binary(es_bytes) do
    # TODO: any thing we need from ES ?
    # IO.puts byte_size(es_bytes)
  end
end
