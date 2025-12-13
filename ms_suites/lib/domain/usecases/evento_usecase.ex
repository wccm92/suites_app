defmodule MsSuitesApp.Domain.EventUsecase do
  alias MsSuitesApp.Infrastructure.Adapters.Eventos
  alias MsSuitesApp.Domain.Model.Evento

  require Logger
  import Ecto.Query, warn: false
  @spec get_evento_activo() ::
          {:ok, %{status: pos_integer(), body: map()}}
          | {:error, term()}
  def get_evento_activo do
    case Eventos.get_evento_activo() do
      nil ->
        Logger.debug("sin eventos")
        {:error, :not_event}

      %Evento{} = evento ->
        {:ok, %{status: 200, body: %{evento: to_response(evento)}}}
    end
  end

  defp to_response(%Evento{} = e) do
    %{
      id_evento: e.id_evento
      #cod_evento: e.cod_evento,
      #desc_evento: e.desc_evento,
      #fech_creacion: e.fech_creacion,
      #fech_inicio: e.fech_inicio,
      #fech_final: e.fech_final,
      #id_user: e.id_user,
      #estado: e.estado
    }
  end

end
