separate (Files_Suite.Operations)
   function Detail_Value
     (Prefix_Key : String;
      Value      : String;
      Suffix_Key : String)
      return String
   is
      Prefix : constant String :=
        Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
      Suffix : constant String :=
        Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
   begin
      if Suffix'Length > 0
        and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
      then
         return Prefix & " " & Value & " " & Suffix;
      else
         return Prefix & " " & Value & Suffix;
      end if;
   end Detail_Value;
