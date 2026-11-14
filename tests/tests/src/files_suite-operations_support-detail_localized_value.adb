separate (Files_Suite.Operations_Support)
   function Detail_Localized_Value (Key : String; Name : String; Value_Key : String) return String is
   begin
      return Detail_Value (Key, Name, Files.Localization.Text (Value_Key));
   end Detail_Localized_Value;
