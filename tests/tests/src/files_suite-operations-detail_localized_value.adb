separate (Files_Suite.Operations)
   function Detail_Localized_Value
     (Prefix_Key : String;
      Value_Key  : String;
      Suffix_Key : String)
      return String
   is
   begin
      return Detail_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
   end Detail_Localized_Value;
