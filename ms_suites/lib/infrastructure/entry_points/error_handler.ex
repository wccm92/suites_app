defmodule MsSuitesApp.Infrastructure.EntryPoint.ErrorHandler do

  @compile if Mix.env() == :test, do: :export_all

  def build_error_response({:error, :empty_fields}) do
    make_error_v2(
      "9994",
      "Error",
      "Campos nulos o vacíos",
      400
    )
  end

  def build_error_response({:error, :invalid_credentials}) do
    make_error_v2(
      "01",
      "Error",
      "Usuario o contraseña incorrecta",
      401
    )
  end

  def build_error_response({:error, :not_event}) do
    make_error_v2(
      "03",
      "Error",
      "Sin eventos",
      404
    )
  end

  def build_error_response({:error, :inactive_user}) do
    make_error_v2(
      "02",
      "Error",
      "Usuario bloqueado",
      401
    )
  end

  def build_error_response({:error, :expired_suite_session}) do
    make_error_v2(
      "04",
      "Error",
      "Sesión no valida",
      401
    )
  end

  def build_error_response({:error, :suite_bloqueada}) do
    make_error_v2(
      "06",
      "Error",
      "Suite bloqueada: 01",
      200
    )
  end

  def build_error_response({:error, :suite_en_mora}) do
    make_error_v2(
      "07",
      "Error",
      "Suite bloqueada: 02",
      200
    )
  end

  def build_error_response(_) do
    make_error_v2(
      "0382",
      "Lo sentimos, tenemos problemas con nuestro sistemas",
      "Lo sentimos, tenemos inconvenientes con nuestros sistemas, nuestro equipo se encuentra trabajando para brindarte una  solución. Intenta más tarde.",
      500
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

  defp make_error_v2(code, title, detail, http_status) do
    %{
      "errors" => [
        %{
          "code" => code,
          "title" => title,
          "detail" => detail,
          "http_status" => http_status
        }
      ]
    }
  end
end