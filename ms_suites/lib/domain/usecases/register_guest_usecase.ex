defmodule MsSuitesApp.Domain.RegisterGuestsUsecase do
  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter


  def handle_register_guests(id_suite, visitantes, token) when is_list(visitantes)do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, results} <- register_guests(event_user_info.id_evento, id_suite, visitantes) do
      {:ok, results}
    else
      {:error, _} = err -> err
      false -> {:error, :invalid_body}
    end
  end
  #mapea los documentos
  defp register_guests(id_evento, id_suite, visitantes) do
    results =
      visitantes
      |> Enum.map(&normalize_doc/1)
      |> Enum.reject(&is_nil_or_empty?/1)
      |> Enum.map(&register_one(id_evento, id_suite, &1))

    {:ok, build_response(results)}
  end

  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""

  defp normalize_doc(doc) do
    doc
    |> to_string()
    |> String.trim()
  end
  #registra visitantes
  defp register_one(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.ensure_visitante_exists(documento) do
      :ok ->
        do_register_one(id_evento, id_suite, documento)

      {:error, {:visitante_insert_failed, changeset}} ->
        error_result(documento, "visitor_insert_failed", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "error", %{detail: inspect(other)})
    end
  end
  #registra visitantesxevento
  defp do_register_one(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} ->
        %{documento: documento, status: "OK"}

      {:error, {:constraint_error, "visitantexevento_pkey"}} ->
        already_registered_response(id_evento, documento)

      {:error, {:constraint_error, constraint_name}} ->
        error_result(documento, "constraint_error", %{constraint: constraint_name})

      {:error, %Ecto.Changeset{} = changeset} ->
        error_result(documento, "register_failed", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "error", %{detail: inspect(other)})
    end
  end
  #si no se pudo registrar en visitantexevento verifica en que suite esta registrado
  defp already_registered_response(id_evento, documento) do
    case SuitesQueryAdapter.validate_guess_in_event(id_evento, documento) do
      {:ok, existing_suite_id} ->
        error_result(documento, "already_registered", %{id_suite_actual: existing_suite_id})

      :not_found ->
        error_result(documento, "already_registered", %{})
    end
  end



  defp error_result(documento, code, extra \\ %{}) do
    Map.merge(%{documento: documento, status: "error", code: code}, extra)
  end

  defp build_response(results) do
    %{
      successful_registrations: successful(results),
      not_registered_blocked: [],
      not_registered_already_suites: already_registered_docs(results)
    }
  end

  defp successful(results) do
    results
    |> Enum.filter(&(&1.status == "OK"))
    |> Enum.map(& &1.documento)
  end

  defp already_registered_docs(results) do
    results
    |> Enum.filter(&(&1.status == "error" and &1.code == "already_registered"))
    |> Enum.map(& &1.documento)
  end

end
