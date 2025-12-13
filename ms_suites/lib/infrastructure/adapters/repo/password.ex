defmodule MsSuitesApp.Infrastructure.Adapters.Password do
  use Bitwise
  require Logger
  @dk_len 64

  @doc """
  Verifica hashes tipo:
  scrypt:32768:8:1$salt$hex_digest
  (formato Werkzeug / Flask)
  """
  def verify(password, "scrypt:" <> rest) when is_binary(password) do
    #Logger.debug("""
    #[Password.verify]
    #password='#{password}'
    #hash='#{rest}'
    #""")
    with {:ok, n, r, p, salt, hex_digest} <- parse(rest),
         {:ok, log_n} <- log2_pow2(n),
         derived <- :crypto.hash(:sha512, scrypt(password, salt, log_n, r, p)),
         derived_hex <- Base.encode16(derived, case: :lower) do
      Logger.debug("""
      [Password.verify DEBUG]
      password=#{password}
      salt=#{salt}
      iterations=#{n * r * p}
      derived_hex=#{derived_hex}
      expected_hex=#{hex_digest}
      """)
      secure_eq?(derived_hex, String.downcase(hex_digest))
    else
      _ -> false
    end
  end

  def verify(_, _), do: false

  # -------- internals --------

  defp parse(rest) do
    case String.split(rest, "$") do
      [params, salt, digest] ->
        case String.split(params, ":") do
          [n, r, p] ->
            {:ok, String.to_integer(n), String.to_integer(r), String.to_integer(p), salt, digest}

          _ -> {:error, :bad_params}
        end

      _ ->
        {:error, :bad_format}
    end
  end

  defp log2_pow2(n) when n > 0 do
    log_n = trunc(:math.log2(n))
    if (1 <<< log_n) == n, do: {:ok, log_n}, else: {:error, :n_not_pow2}
  end

  # Implementación básica de scrypt usando crypto
  defp scrypt(password, salt, log_n, r, p) do
    n = 1 <<< log_n
    :crypto.pbkdf2_hmac(:sha256, password, salt, n * r * p, @dk_len)
  end

  # comparación en tiempo constante
  defp secure_eq?(a, b) when byte_size(a) == byte_size(b) do
    a
    |> :crypto.exor(b)
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn x, acc -> acc ||| x end)
    |> Kernel.==(0)
  end

  defp secure_eq?(_, _), do: false
end
