defmodule MsSuitesApp.Domain.RegisterGuestsUsecase do
  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter


  def handle_register_guests(id_suite, visitantes, token) when is_list(visitantes)do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, results} <- register_guests(event_user_info.id_evento, id_suite, visitantes) do
      {:ok, %{resultados: results}}
    else
      {:error, _} = err -> err
      false -> {:error, :invalid_body}
    end
  end

  defp register_guests(id_evento, id_suite, visitantes) do
    results =
      visitantes
      |> DataTypeUtils.normalize()
      |> Enum.map(& &1[:documento])
      |> Enum.map(&normalize_doc/1)
      |> Enum.reject(&is_nil_or_empty?/1)
      |> Enum.map(&register_one(id_evento, id_suite, &1))

    {:ok, results}
  end

  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""

  defp normalize_doc(doc) do
    doc
    |> to_string()
    |> String.trim()
  end

  defp register_one(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.ensure_visitante_exists(documento) do
      :ok ->
        do_register_one(id_evento, id_suite, documento)

      {:error, {:visitante_insert_failed, changeset}} ->
        error_result(documento, "VISITOR_INSERT_FAILED", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "UNKNOWN_ERROR", %{detail: inspect(other)})
    end
  end

  defp do_register_one(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} ->
        %{documento: documento, status: "OK"}

      {:error, {:constraint_error, "visitantexevento_pkey"}} ->
        already_registered_response(id_evento, documento)

      {:error, {:constraint_error, constraint_name}} ->
        error_result(documento, "CONSTRAINT_ERROR", %{constraint: constraint_name})

      {:error, %Ecto.Changeset{} = changeset} ->
        error_result(documento, "REGISTER_FAILED", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "UNKNOWN_ERROR", %{detail: inspect(other)})
    end
  end

  defp already_registered_response(id_evento, documento) do
    case SuitesQueryAdapter.validate_guess_in_event(id_evento, documento) do
      {:ok, existing_suite_id} ->
        error_result(documento, "ALREADY_REGISTERED", %{id_suite_actual: existing_suite_id})

      :not_found ->
        error_result(documento, "ALREADY_REGISTERED", %{})
    end
  end



  defp error_result(documento, code, extra \\ %{}) do
    Map.merge(%{documento: documento, status: "ERROR", code: code}, extra)
  end
end
