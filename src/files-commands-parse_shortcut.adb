separate (Files.Commands)
   function Parse_Shortcut (Text : String) return Shortcut is
      Mods  : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Key   : Guikit.Input.Key_Code := Guikit.Input.Key_Unknown;
      Start : Integer := Text'First;

      procedure Token (S : String) is
         L : constant String := Ada.Characters.Handling.To_Lower (S);
      begin
         if L = "shift" then
            Mods (Guikit.Input.Shift_Key) := True;
         elsif L = "control" or else L = "ctrl" then
            Mods (Guikit.Input.Control_Key) := True;
         elsif L = "alt" or else L = "option" or else L = "opt" then
            Mods (Guikit.Input.Alt_Key) := True;
         elsif L = "meta" or else L = "cmd" or else L = "super" then
            Mods (Guikit.Input.Meta_Key) := True;
         elsif L /= "" then
            Key := Text_To_Key (L);
         end if;
      end Token;
   begin
      for I in Text'Range loop
         if Text (I) = '+' then
            Token (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      Token (Text (Start .. Text'Last));
      return (Present => Key /= Guikit.Input.Key_Unknown, Key => Key, Modifiers => Mods);
   end Parse_Shortcut;
