defmodule MsSuitesApp.Domain.ValidateSeasonTicketHoldersLimitUsecase do
  @moduledoc """
  Validación del límite de abonados (season ticket holders) de una suite.

  Una suite no puede tener más abonados que su `capacidad` (tabla `suites`).

  Contrato API GET `/suites_app/validate_season_ticket_holders_limit/:id_suite`.
  Respuesta exitosa (http 200), cuando aún se pueden inscribir abonados:

      %{
        id_suite: "E001",
        capacidad: 10,
        abonados_inscritos: 7,
        cupos_abonados_disponibles: 3,
        cupos_visitantes_disponibles: 4
      }

  `cupos_visitantes_disponibles` son los cupos libres de la suite para el
  evento actual (capacidad − invitados − amparados), usados por el front para
  decidir si ofrece registrar al abonado también como visitante del evento.

  Si la suite ya alcanzó el límite -> code "12" (:season_ticket_holders_limit_reached).
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter

  def handle_validate_limit(id_suite, token) when is_binary(id_suite) do
    with {:ok, event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         {:ok, limit} <- check_limit(id_suite) do
      {:ok,
        Map.put(
          limit,
          :cupos_visitantes_disponibles,
          cupos_visitantes_disponibles(event_user.id, id_suite, limit.capacidad)
        )}
    else
      {:error, _} = error -> error
    end
  end

  def handle_validate_limit(_id_suite, _token), do: {:error, :invalid_body}

  @doc """
  Verifica que la suite admita un abonado más.
  Devuelve `{:ok, %{id_suite, capacidad, abonados_inscritos, cupos_abonados_disponibles}}`
  o `{:error, :season_ticket_holders_limit_reached}`.
  """
  def check_limit(id_suite) do
    case SuitesQueryAdapter.get_suite_capacity(id_suite) do
      nil ->
        {:error, :suite_not_found}

      capacidad ->
        inscritos = AbonadosQueryAdapter.count_season_ticket_holders_by_suite(id_suite)

        if inscritos >= capacidad do
          {:error, :season_ticket_holders_limit_reached}
        else
          {:ok,
            %{
              id_suite: id_suite,
              capacidad: capacidad,
              abonados_inscritos: inscritos,
              cupos_abonados_disponibles: capacidad - inscritos
            }}
        end
    end
  rescue
    error ->
      Logger.error("Error validando límite de abonados: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  @doc """
  Cupos libres de la suite para el evento actual. Cada invitado y cada
  amparado ocupan un cupo (misma regla que el detalle de suite).
  """
  def cupos_visitantes_disponibles(id_evento, id_suite, capacidad) do
    invitados = SuitesQueryAdapter.count_guests_in_suite(id_evento, id_suite)

    amparados =
      id_evento
      |> AmparadosQueryAdapter.count_amparados_by_suite(id_suite)
      |> Map.values()
      |> Enum.sum()

    max(capacidad - invitados - amparados, 0)
  end
end
