defmodule MsSuitesApp.Domain.RegisterAmparadoUsecase do
  @moduledoc """
  Registro de amparados (menores que acompañan a un invitado en el ingreso).

  Contrato API POST `/suites_app/register_amparado`:

      %{
        "id_suite" => "DEMO3",
        "invitado" => "1047451430",
        "amparados" => ["3ba68b94-...", "c62e5802-...", ...]
      }

  Respuesta:

      %{title: "success", detail: "Amparados registrados correctamente"}

  Solo valida sesión y evento activo. El registro de cada amparado es
  best-effort: los fallos individuales (duplicados, etc.) se ignoran.
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter

  def handle_register_amparados(id_suite, invitado, amparados, token)
      when is_binary(id_suite) and is_list(amparados) do
    with {:ok, event_user} <- LoginUsecase.validate_event_and_session(token) do
      registrados =
        AmparadosQueryAdapter.register_amparados(
          event_user.id,
          id_suite,
          normalize(invitado),
          amparados
        )

      Logger.debug(
        "Amparados registrados para #{inspect(invitado)}: #{inspect(registrados)}"
      )

      {:ok, success_response()}
    else
      {:error, _} = error -> error
    end
  end

  def handle_register_amparados(_id_suite, _invitado, _amparados, _token),
      do: {:error, :invalid_body}

  defp success_response do
    %{title: "success", detail: "Amparados registrados correctamente"}
  end

  defp normalize(value), do: value |> to_string() |> String.trim()
end