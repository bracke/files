with Files.Text_Basics;
with Files.Text_Case;

separate (Files.Commands)
   procedure Read_Shortcut
     (Text   : String;
      Result : out Shortcut;
      Valid  : out Boolean)
   is
      Mods  : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Key   : Guikit.Input.Key_Code := Guikit.Input.Key_Unknown;
      Keys  : Natural := 0;
      Start : Integer := Text'First;

      procedure Token (S : String) is
         L : constant String := Files.Text_Case.To_Lower_Ascii (Files.Text_Basics.Trim_Blanks (S));
      begin
         if L = "shift" then
            Mods (Guikit.Input.Shift_Key) := True;
         elsif L = "control" or else L = "ctrl" then
            Mods (Guikit.Input.Control_Key) := True;
         elsif L = "alt" or else L = "option" or else L = "opt" then
            Mods (Guikit.Input.Alt_Key) := True;
         elsif L = "meta" or else L = "cmd" or else L = "super" then
            Mods (Guikit.Input.Meta_Key) := True;
         elsif L = "" then
            --  An empty token (a stray '+', or "a++b") names nothing.
            Valid := False;
         else
            Keys := Keys + 1;
            Key := Text_To_Key (L);
            if Key = Guikit.Input.Key_Unknown then
               Valid := False;
            end if;
         end if;
      end Token;
   begin
      Valid := True;
      if Files.Text_Basics.Trim_Blanks (Text) = "" then
         --  No combo at all: an explicit unbind, which is well-formed.
         Result := (Present => False, Key => Guikit.Input.Key_Unknown, Modifiers => Mods);
         return;
      end if;
      for I in Text'Range loop
         if Text (I) = '+' then
            Token (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      Token (Text (Start .. Text'Last));
      --  Exactly one key: a second one would silently replace the first.
      if Keys /= 1 then
         Valid := False;
      end if;
      Result := (Present => Key /= Guikit.Input.Key_Unknown, Key => Key, Modifiers => Mods);
   end Read_Shortcut;
