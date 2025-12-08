defmodule MsSandbox.Domain.Model.EnterprisesRequest do
  @moduledoc """
  Provide behaviors to handle the session token creation
  """

  @compile if Mix.env() == :test, do: :export_all

  alias MsSandbox.Utils.DataTypeUtils

  alias __MODULE__
  @derive [Poison.Encoder]
  defstruct [
    :message_id,
    :channel,
    :name,
    :tip_doc,
    :cid,
    :aid,
    :document_number,
    :mdm_code,
    :usr_type,
    :rol,
    :owner_num,
    :owner_doc,
    :entitlement
  ]

  def create_session_create_struct(request) do
    {:ok, struct(EnterprisesRequest, request)}
  end

  def validate_request(%{} = to_validate) do
    with {:ok, true} <- validate_required_fields(to_validate),
         {:ok, true} <- DataTypeUtils.validate_format?(to_validate.cid),
         {:ok, true} <- DataTypeUtils.validate_format?(to_validate.aid) do
      {:ok, to_validate}
    end
  end

  defp validate_required_fields(%{} = to_validate)
       when to_validate.message_id != nil and to_validate.message_id != "" and
            to_validate.channel != nil and to_validate.channel != "" and
            to_validate.name != nil and to_validate.name != "" and
            to_validate.tip_doc != nil and to_validate.tip_doc != "" and
            to_validate.cid != nil and to_validate.cid != "" and
            to_validate.aid != nil and to_validate.aid != "" and
            to_validate.document_number != nil and to_validate.document_number != "" and
            to_validate.mdm_code != nil and to_validate.mdm_code != "" and
            to_validate.usr_type != nil and to_validate.usr_type != "" and
            to_validate.rol != nil and to_validate.rol != "" and
            to_validate.owner_num != nil and to_validate.owner_num != "" and
            to_validate.owner_doc != nil and to_validate.owner_doc != "" and
            to_validate.entitlement != nil and to_validate.entitlement != "" do
    {:ok, true}
  end

  defp validate_required_fields(_) do
    {:error, :empty_fields}
  end
end
