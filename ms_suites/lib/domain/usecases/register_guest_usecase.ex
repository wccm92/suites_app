defmodule MsSuitesApp.Domain.RegisterGuestsUsecase do
  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter


  def handle_register_guests(id_suite, visitantes, invitados_amparados, token)
      when is_list(visitantes) and is_list(invitados_amparados) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, results} <- register_guests(event_user_info.id, id_suite, visitantes, invitados_amparados) do
      {:ok, results}
    else
      {:error, _} = err -> err
      false -> {:error, :invalid_body}
    end
  end

  # Construye un mapa padre_doc -> amparado_doc (quitando el "0" inicial del amparado)
  defp build_amparados_map(invitados_amparados) do
    Enum.reduce(invitados_amparados, %{}, fn doc, acc ->
      normalized = normalize_doc(doc)
      parent = String.replace_prefix(normalized, "0", "")
      Map.put(acc, parent, normalized)
    end)
  end

  #mapea los documentos
  defp register_guests(id, id_suite, visitantes, invitados_amparados) do
    amparados_map = build_amparados_map(invitados_amparados)

    results =
      visitantes
      |> Enum.map(&normalize_doc/1)
      |> Enum.reject(&is_nil_or_empty?/1)
      |> Enum.flat_map(&register_with_amparado(id, id_suite, &1, amparados_map))

    {:ok, build_response(results)}
  end

  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""

  defp normalize_doc(doc) do
    doc
    |> to_string()
    |> String.trim()
  end

  # Si el padre está bloqueado, bloquea también al amparado sin intentar registrarlo
  defp register_with_amparado(id, id_suite, documento, amparados_map) do
    amparado = Map.get(amparados_map, documento)

    if SuitesQueryAdapter.validate_blacklisted(documento) do
      padre_bloqueado = [tag(error_result(documento, "blocked"), :adult)]
      amparado_bloqueado = if amparado, do: [tag(error_result(amparado, "blocked"), :amparado)], else: []
      padre_bloqueado ++ amparado_bloqueado
    else
      parent_result = tag(register_one_doc(id, id_suite, documento), :adult)

      amparado_results =
        if amparado && parent_result.status == "OK" do
          [tag(register_one_doc(id, id_suite, amparado), :amparado)]
        else
          []
        end

      [parent_result | amparado_results]
    end
  end

  defp tag(result, tipo), do: Map.put(result, :tipo, tipo)

  #registra un documento (sin chequeo de blacklist, ya fue validado en el padre)
  defp register_one_doc(id, id_suite, documento) do
    case SuitesQueryAdapter.ensure_visitante_exists(documento) do
      :ok ->
        do_register_one(id, id_suite, documento)

      {:error, {:visitante_insert_failed, changeset}} ->
        error_result(documento, "visitor_insert_failed", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "error", %{detail: inspect(other)})
    end
  end
  #registra visitantesxevento
  defp do_register_one(id, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id, id_suite, documento) do
      {:ok, _} ->
        %{documento: documento, status: "OK"}

      {:error, {:constraint_error, "visitantexevento_pkey"}} ->
        already_registered_response(id, documento)

      {:error, {:constraint_error, constraint_name}} ->
        error_result(documento, "constraint_error", %{constraint: constraint_name})

      {:error, %Ecto.Changeset{} = changeset} ->
        error_result(documento, "register_failed", %{detail: inspect(changeset.errors)})

      other ->
        error_result(documento, "error", %{detail: inspect(other)})
    end
  end
  #si no se pudo registrar en visitantexevento verifica en que suite esta registrado
  defp already_registered_response(id, documento) do
    case SuitesQueryAdapter.validate_guess_in_event(id, documento) do
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
    adults    = Enum.filter(results, &(&1.tipo == :adult))
    amparados = Enum.filter(results, &(&1.tipo == :amparado))

    %{
      successful_registrations: successful(adults),
      not_registered_blocked: blocked_docs(adults),
      not_registered_already_suites: already_registered_docs(adults),
      successful_registrations_amparados: successful(amparados)
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

  defp blocked_docs(results) do
    results
    |> Enum.filter(&(&1.status == "error" and &1.code == "blocked"))
    |> Enum.map(& &1.documento)
  end

end
