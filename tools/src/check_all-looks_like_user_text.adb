separate (Check_All)
   function Looks_Like_User_Text (Literal : String) return Boolean is
      Has_Letter : Boolean := False;
      Has_Space  : Boolean := False;
   begin
      --  Shell/command fragments and similar code carry metacharacters that
      --  never appear in user-visible prose; they are not localizable text.
      for Char of Literal loop
         if Char in '$' | ';' | '|' | '<' | '>' then
            return False;
         end if;
      end loop;

      --  An absolute filesystem path is not prose. Font files force the point:
      --  "/System/Library/Fonts/Apple Color Emoji.ttc" is a name Apple chose,
      --  spaces and capitals and all, and there is nothing in it to translate.
      if Literal'Length > 1 and then Literal (Literal'First) = '/' then
         return False;
      end if;

      --  Shell verbs assembled into the terminal command line. They carry no
      --  metacharacter of their own -- "cd /d " is cmd's change-directory form,
      --  "cd " every POSIX shell's -- but they are shell syntax, not localizable
      --  user text.
      if Literal = "cd /d "
        or else Literal = "cd "
      then
         return False;
      end if;

      if Literal = "untitled "
        or else Literal = "untitled.txt"
        or else Literal = "[Trash Info]"
        or else Literal = "Path="
        or else Literal = "DeletionDate="
        or else Literal = "default_view_mode = "
        or else Literal = "show_hidden_files = "
        or else Literal = "sort_field = "
        or else Literal = "sort_ascending = "
        or else Literal = "high_contrast_theme = "
        or else Literal = "icon_theme = "
        or else Literal = "font_pixel_size = "
        or else Literal = "info_pane_open = "
        or else Literal = "use_system_default_opener = "
        or else Literal = "window_width = "
        or else Literal = "window_height = "
        or else Literal = "bookmark = "
      then
         return False;
      end if;

      for Char of Literal loop
         if (Char >= 'A' and then Char <= 'Z') or else (Char >= 'a' and then Char <= 'z') then
            Has_Letter := True;
         elsif Char = ' ' then
            Has_Space := True;
         end if;
      end loop;

      return Has_Letter and then Has_Space;
   end Looks_Like_User_Text;
