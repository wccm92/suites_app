defmodule MsSandbox.Utils.DocumentTypeConverter do

  @id_types_doc_original %{
    "TIPDOC_FS000" => "CD",
    "TIPDOC_FS001" => "CC",
    "TIPDOC_FS002" => "CE",
    "TIPDOC_FS003" => "NIT",
    "TIPDOC_FS004" => "TI",
    "TIPDOC_FS005" => "PAS",
    "TIPDOC_FS006" => "PNN",
    "TIPDOC_FS007" => "PJN",
    "TIPDOC_FS008" => "FC",
    "TIPDOC_FS009" => "RC",
    "CD" => "CD",
    "CC" => "CC",
    "CE" => "CE",
    "NIT" => "NIT",
    "TI" => "TI",
    "PAS" => "PAS",
    "PNN" => "PNN",
    "PJN" => "PJN",
    "FC" => "FC",
  }

  def get_id_types_doc_original(document_type) do
    case @id_types_doc_original[document_type] do
      nil -> document_type
      id_type -> id_type
    end
  end
end