separate (Files_Suite.Operations_Support)
   function Detail_Value (Key : String; Name : String; Value : String) return String is
   begin
      return Files.Localization.Text (Key, Name, Value);
   end Detail_Value;
