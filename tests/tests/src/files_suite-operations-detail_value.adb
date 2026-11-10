separate (Files_Suite.Operations)
   function Detail_Value (Key : String; Name : String; Value : String) return String is
   begin
      return Files.Localization.Text (Key, Name, Value);
   end Detail_Value;
