separate (Files_Suite.Operations_Support)
   function Detail_Lines_Encoding (Key : String; Lines : String; Encoding_Key : String) return String is
   begin
      return
        Detail_Value (Key, "lines", Lines) & " "
        & Detail_Localized_Value ("info.extra.encoding", "encoding", Encoding_Key);
   end Detail_Lines_Encoding;
