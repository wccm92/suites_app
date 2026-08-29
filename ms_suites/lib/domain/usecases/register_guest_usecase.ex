defmodule MsSuitesApp.Domain.RegisterGuestsUsecase do
  @moduledoc """
  Registro masivo de invitados y sus amparados.

  Contrato API POST `/suites_app/register_guests`:

      %{
        "id_suite" => "DEMO3",
        "invitados" => [
          %{"invitado" => "1047451430", "amparados" => ["uuid1", "uuid2", ...]},
          %{"invitado" => "1047451431", "amparados" => ["uuid4"]},
          %{"invitado" => "1047451432", "amparados" => []}
        ]
      }

  Los invitados se registran en `visitantexevento`; sus amparados en
  `amparadoxevento` (solo si el invitado se registró OK). El registro de
  amparados es best-effort: los fallos individuales se ignoran.

  Respuesta:

      %{
        successful_registrations: ["1047451430", "1047451432"],
        successful_registrations_amparados: [
          %{sponsor: "1047451430", amparados: ["uuid1", "uuid2", "uuid3"]},
          %{sponsor: "1047451432", amparados: []}
        ],
        not_registered_blocked: [],
        not_registered_already_suites: ["1047451431"]
      }
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter

  def handle_register_guests(id_suite, invitados, token) when is_list(invitados) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, results} <- register_guests(event_user_info.id, id_suite, invitados) do
      {:ok, results}
    else
      {:error, _} = err -> err
    end
  end

  def handle_register_guests(_id_suite, _invitados, _token), do: {:error, :invalid_body}

  defp register_guests(id_evento, id_suite, invitados) do
    results =
      invitados
      |> Enum.map(&normalize_invitado/1)
      |> Enum.reject(fn item -> is_nil(item) or item.invitado == "" end)
      |> Enum.map(&register_invitado(id_evento, id_suite, &1))

    {:ok, build_response(results)}
  end

  # Normaliza cada item {invitado, amparados} del request.
  defp normalize_invitado(%{"invitado" => invitado} = item) do
    %{
      invitado: normalize_doc(invitado),
      amparados: item |> Map.get("amparados", []) |> List.wrap()
    }
  end

  defp normalize_invitado(_), do: nil

  # Registra un invitado y, si entra OK, sus amparados.
  defp register_invitado(id_evento, id_suite, %{invitado: documento, amparados: amparados}) do
    if SuitesQueryAdapter.validate_blacklisted(documento) do
      %{status: :blocked, invitado: documento}
    else
      case register_guest(id_evento, id_suite, documento) do
        :ok ->
          AmparadosQueryAdapter.register_amparados(id_evento, id_suite, documento, amparados)
          %{status: :ok, invitado: documento, amparados: amparados}

        :already_registered ->
          %{status: :already_registered, invitado: documento}

        :error ->
          %{status: :error, invitado: documento}
      end
    end
  end

  # visitante (master) + visitantexevento, siguiendo el patrón de do_register_one.
  defp register_guest(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.ensure_visitante_exists(documento) do
      :ok -> do_register_guest(id_evento, id_suite, documento)
      _other -> :error
    end
  end

  defp do_register_guest(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} ->
        :ok

      {:error, {:constraint_error, "visitantexevento_pkey"}} ->
        :already_registered

      other ->
        Logger.error("Error registrando invitado #{documento}: #{inspect(other)}")
        :error
    end
  end

  defp build_response(results) do
    ok = Enum.filter(results, &(&1.status == :ok))

    %{
      successful_registrations: Enum.map(ok, & &1.invitado),
      successful_registrations_amparados:
        Enum.map(ok, &%{sponsor: &1.invitado, amparados: &1.amparados}),
      not_registered_blocked:
        results |> Enum.filter(&(&1.status == :blocked)) |> Enum.map(& &1.invitado),
      not_registered_already_suites:
        results |> Enum.filter(&(&1.status == :already_registered)) |> Enum.map(& &1.invitado)
    }
  end

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
end