defmodule MsSuitesApp.Utils.DataTypeUtils do
  require Logger

  @moduledoc """
  Provides functions for normalize data
  """

  @compile if Mix.env() == :test, do: :export_all

  @u_hex32  ~r/^U[0-9A-F]{32}$/
  @hex32    ~r/^[0-9A-F]{32}$/
  @hex33    ~r/^[0-9A-F]{33}$/
  @hex_any  ~r/^[0-9A-Fa-f]+$/

  def normalize(%{__struct__: _} = value), do: value

  def normalize(%{} = map) do
    Map.to_list(map)
    |> Enum.map(fn {key, value} -> {String.to_atom(key), normalize(value)} end)
    |> Enum.into(%{})
  end

  def normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  def normalize(value), do: value

  def base64_decode(string) do
    {:ok, value} = Base.decode64(string, padding: false)
    value
  end

  def extract_header(headers, name) when is_list(headers) do
    case extract_header!(headers, name) do
      {:ok, value} when value != nil -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  def extract_header(headers, name) do
    {:error, "headers is not a list when finding #{inspect(name)}: #{inspect(headers)}"}
  end

  def extract_header!(headers, name) when is_list(headers) do
    out = Enum.filter(headers, create_evaluator(name))

    case out do
      [{_, value} | _] -> {:ok, value}
      _ -> {:ok, nil}
    end
  end

  defp create_evaluator(name) do
    fn
      {^name, _} -> true
      _ -> false
    end
  end

  def format("true", "boolean"), do: true
  def format("false", "boolean"), do: false

  def format(value, "number") when is_binary(value) do
    {number, ""} = Float.parse(value)
    number
  rescue
    _err ->
      Logger.warning("Error parsing #{value} to float")
      nil
  end

  def format(value, _type), do: value

  def validate_format?(value, patterns \\ [@u_hex32, @hex32, @hex33, @hex_any])

  def validate_format?(value, patterns) when is_list(patterns) do
    if Enum.any?(patterns, &Regex.match?(&1, value)) do
      {:ok, true}
    else
      {:error, :invalid_cid_aid_format}
    end
  end

  def validate_format?(_, _), do: {:error, :not_a_string}

  def system_time_to_milliseconds(system_time) do
    (system_time / 1.0e6) |> round()
  end

  def monotonic_time_to_milliseconds(monotonic_time) do
    monotonic_time |> System.convert_time_unit(:native, :millisecond)
  end

  def create_confirm_number do
    {:ok, Enum.random(10_000..99_999) |> to_string()}
  end

  def start_time(), do: System.monotonic_time()

  def duration_time(start),
    do: (System.monotonic_time() - start) |> monotonic_time_to_milliseconds()

  def get_authorization_header_value(headers) do
    Enum.find_value(
      headers,
      fn {key, value} when is_binary(key) ->
        if String.downcase(key) == "authorization", do: value, else: nil
      _ -> nil
      end)
  end
end
