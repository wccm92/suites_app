defmodule MsSuitesApp.Domain.GuestsStatusUsecase do
  @moduledoc """
  Estado de los visitantes inscritos en una suite para el evento actual.

  Contrato API GET `/suites_app/guests_status/:id_suite`.
  Disponible para cualquier perfil (owner y leaseholder), igual que el
  detalle de suite. Respuesta exitosa (http 200):

      %{
        id_suite: "E001",
        invitados: [
          %{invitado: "1047451430", abonado: true, ingreso_evento: false},
          ...
        ]
      }

  * `abonado`        -> la cédula está en la tabla `abonados` para esta suite.
  * `ingreso_evento` -> la fila de `visitantexevento` tiene `estado == "1"`.
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter

  @estado_ingreso "1"

  def handle_guests_status(id_suite, token) when is_binary(id_suite) do
    with {:ok, event_user} <- LoginUsecase.validate_event_and_session(token),
         {:ok, invitados} <- fetch_guests_status(event_user.id, id_suite) do
      {:ok, %{id_suite: id_suite, invitados: invitados}}
    else
      {:error, _} = error -> error
    end
  end

  def handle_guests_status(_id_suite, _token), do: {:error, :invalid_body}

  defp fetch_guests_status(id_evento, id_suite) do
    Logger.debug("Consultando estado de visitantes de la suite #{inspect(id_suite)}")

    invitados =
      id_evento
      |> SuitesQueryAdapter.list_guests_status(id_suite)
      |> Enum.map(fn guest ->
        %{
          invitado: guest.invitado,
          abonado: guest.abonado,
          ingreso_evento: guest.estado == @estado_ingreso
        }
      end)

    {:ok, invitados}
  rescue
    error ->
      Logger.error("Error consultando estado de visitantes: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end
end
