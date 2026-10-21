with Files.Localization;

separate (Files.Commands)
   function Shortcut_Display_Text
     (Value : Shortcut)
      return String
   is
      Key    : constant String := Key_Text (Value.Key);
      Result : Unbounded_String;

      --  The key's own name: a letter or digit as printed on the key, and named
      --  keys (arrows included) as the current language's catalog spells them.
      function Key_Name return String is
      begin
         if Key'Length = 1 then
            return Ada.Characters.Handling.To_Upper (Key);
         elsif Key (Key'First) = 'f' and then Key'Length in 2 .. 3 then
            return "F" & Key (Key'First + 1 .. Key'Last);
         elsif Key = "equal" then
            return "=";
         elsif Key = "minus" then
            return "-";
         else
            return Files.Localization.Text ("key.name." & Key);
         end if;
      end Key_Name;

      procedure Add_Modifier (Name : String) is
      begin
         Append (Result, Files.Localization.Text ("key.modifier." & Name));
         Append (Result, "+");
      end Add_Modifier;
   begin
      if not Value.Present or else Key = "" then
         return "";
      end if;

      if Value.Modifiers (Guikit.Input.Control_Key) then
         Add_Modifier ("control");
      end if;
      if Value.Modifiers (Guikit.Input.Shift_Key) then
         Add_Modifier ("shift");
      end if;
      if Value.Modifiers (Guikit.Input.Alt_Key) then
         Add_Modifier ("alt");
      end if;
      if Value.Modifiers (Guikit.Input.Meta_Key) then
         Add_Modifier ("meta");
      end if;
      Append (Result, Key_Name);
      return To_String (Result);
   end Shortcut_Display_Text;
