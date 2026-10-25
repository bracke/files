separate (Files_Suite.Operations)
   function Detail_Lines_Encoding
     (Lines_Prefix_Key : String;
      Lines            : String;
      Lines_Suffix_Key : String;
      Encoding_Key     : String)
      return String
   is
   begin
      return
        Detail_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
        & " "
        & Detail_Localized_Value
          ("info.extra.encoding.prefix", Encoding_Key, "info.extra.encoding.suffix");
   end Detail_Lines_Encoding;
