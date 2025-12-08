defmodule MsSandbox.Utils.DocumentTypeConverterTest do
  use ExUnit.Case, async: true
  alias MsSandbox.Utils.DocumentTypeConverter

  describe "get_id_types_doc_original/1" do
    test "maps TIPDOC_FS*** to short code" do
      assert DocumentTypeConverter.get_id_types_doc_original("TIPDOC_FS001") == "CC"
      assert DocumentTypeConverter.get_id_types_doc_original("TIPDOC_FS004") == "TI"
    end

    test "passes through known short codes unchanged" do
      assert DocumentTypeConverter.get_id_types_doc_original("CC") == "CC"
      assert DocumentTypeConverter.get_id_types_doc_original("NIT") == "NIT"
    end

    test "returns input when unknown" do
      assert DocumentTypeConverter.get_id_types_doc_original("UNKNOWN") == "UNKNOWN"
    end
  end
end