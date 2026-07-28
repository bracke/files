separate (Files.Commands)
   function Shortcut_Text
     (Value : Shortcut)
      return String
   is
      Result : Unbounded_String;
      Key    : constant String := Key_Text (Value.Key);
   begin
      if not Value.Present or else Key = "" then
         return "";
      end if;

      if Value.Modifiers (Guikit.Input.Shift_Key) then
         Append (Result, "shift+");
      end if;
      if Value.Modifiers (Guikit.Input.Control_Key) then
         Append (Result, "control+");
      end if;
      if Value.Modifiers (Guikit.Input.Alt_Key) then
         Append (Result, "alt+");
      end if;
      if Value.Modifiers (Guikit.Input.Meta_Key) then
         Append (Result, "meta+");
      end if;
      Append (Result, Key);
      return To_String (Result);
   end Shortcut_Text;
