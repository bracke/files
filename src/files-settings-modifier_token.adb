separate (Files.Settings)
   function Modifier_Token
     (Modifiers : Guikit.Input.Modifier_Set)
      return String
   is
      Result : Unbounded_String := Null_Unbounded_String;

      procedure Add (Name : String) is
      begin
         Append (Result, "+");
         Append (Result, Name);
      end Add;
   begin
      if Modifiers (Guikit.Input.Shift_Key) then
         Add ("shift");
      end if;
      if Modifiers (Guikit.Input.Control_Key) then
         Add ("control");
      end if;
      if Modifiers (Guikit.Input.Alt_Key) then
         Add ("alt");
      end if;
      if Modifiers (Guikit.Input.Meta_Key) then
         Add ("meta");
      end if;

      return To_String (Result);
   end Modifier_Token;
