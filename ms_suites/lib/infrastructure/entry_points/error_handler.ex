defmodule MsSuitesApp.Infrastructure.EntryPoint.ErrorHandler do

  @compile if Mix.env() == :test, do: :export_all

  def build_error_response({:error, :empty_fields}) do
    make_error(
      "9994",
      "Error",
      "Campos nulos o vacíos"
    )
  end

  def build_error_response({:error, :invalid_credentials}) do
    make_error(
      "01",
      "Error",
      "Usuario o contraseña incorrecta"
    )
  end

  def build_error_response({:error, :not_event}) do
    make_error(
      "02",
      "Error",
      "Sin eventos"
    )
  end

  def build_error_response({:error, :inactive_user}) do
    make_error(
      "02",
      "Error",
      "Usuario bloqueado"
    )
  end

  def build_error_response({:error, :invalid_cid_aid_format}) do
    make_error(
      "9995",
      "Error",
      "Campo 'cid' y/o 'aid' con formato inválido"
    )
  end

  def build_error_response(_) do
    make_error(
      "0382",
      "Lo sentimos, tenemos problemas con nuestro sistemas",
      "Lo sentimos, tenemos inconvenientes con nuestros sistemas, nuestro equipo se encuentra trabajando para brindarte una  solución. Intenta más tarde."
    )
  end

  defp make_error(code, title, detail) do
    %{
      "errors" => [
        %{
          "code" => code,
          "title" => title,
          "detail" => detail
        }
      ]
    }
  end
end