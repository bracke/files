separate (Files_Suite.Operations)
   procedure With_Desktop_Application_Fixture (Check : not null access procedure) is
      LF         : constant Character := ASCII.LF;
      CRLF       : constant String := "" & ASCII.CR & ASCII.LF;
      App_Base   : constant String := Join (Root, "xdg_apps");
      Apps_Dir   : constant String := Join (App_Base, "applications");
      System_Base : constant String := Join (Root, "xdg_system");
      System_Apps : constant String := Join (System_Base, "applications");
      Try_Exec    : constant String := Files_Suite.Support.No_Op_Executable;
      Had_Home   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Dirs   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_DIRS");
      Had_Desktop : constant Boolean :=
        Ada.Environment_Variables.Exists ("XDG_CURRENT_DESKTOP");
      Had_Locale : constant Boolean :=
        Ada.Environment_Variables.Exists ("LC_ALL");
      Old_Home   : Unbounded_String;
      Old_Dirs   : Unbounded_String;
      Old_Desktop : Unbounded_String;
      Old_Locale : Unbounded_String;

      function Desktop_Escape (Value : String) return String is
         Result : Unbounded_String;
      begin
         for Character_Value of Value loop
            if Character_Value = '\' then
               Append (Result, "\\");
            else
               Append (Result, Character_Value);
            end if;
         end loop;
         return To_String (Result);
      end Desktop_Escape;

      function Desktop_Exec_Escape (Value : String) return String is
         Result : Unbounded_String;
      begin
         --  A desktop value decoder and the Exec tokenizer each consume one
         --  escaping layer. Preserve Windows separators through both layers.
         for Character_Value of Value loop
            if Character_Value = '\' then
               Append (Result, "\\\\");
            else
               Append (Result, Character_Value);
            end if;
         end loop;
         return To_String (Result);
      end Desktop_Exec_Escape;

      procedure Restore_Environment is
      begin
         if Had_Home then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Dirs then
            Ada.Environment_Variables.Set ("XDG_DATA_DIRS", To_String (Old_Dirs));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_DIRS");
         end if;
         if Had_Desktop then
            Ada.Environment_Variables.Set
              ("XDG_CURRENT_DESKTOP", To_String (Old_Desktop));
         else
            Ada.Environment_Variables.Clear ("XDG_CURRENT_DESKTOP");
         end if;
         if Had_Locale then
            Ada.Environment_Variables.Set ("LC_ALL", To_String (Old_Locale));
         else
            Ada.Environment_Variables.Clear ("LC_ALL");
         end if;
      end Restore_Environment;
   begin
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Dirs then
         Old_Dirs := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_DIRS"));
      end if;
      if Had_Desktop then
         Old_Desktop := To_Unbounded_String
           (Ada.Environment_Variables.Value ("XDG_CURRENT_DESKTOP"));
      end if;
      if Had_Locale then
         Old_Locale := To_Unbounded_String
           (Ada.Environment_Variables.Value ("LC_ALL"));
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Apps_Dir);
      Ada.Directories.Create_Path (System_Apps);

      Write_File
        (Join (Apps_Dir, "editor.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Text Editor" & LF & "Exec=editor %F" & LF);
      Write_File
        (Join (Apps_Dir, "crlf.desktop"),
         "[Desktop Entry]" & CRLF & "Type=Application" & CRLF
         & "Name=ZZ CRLF Application" & CRLF
         & "Exec=viewer %F" & CRLF);
      Write_File
        (Join (Root, "linked-application-target.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Linked Application" & LF & "Exec=viewer %F" & LF);
      declare
         Link_Created : constant Boolean := Create_Symlink
           (Join (Root, "linked-application-target.desktop"),
            Join (Apps_Dir, "linked-application.desktop"));
         pragma Unreferenced (Link_Created);
      begin
         null;
      end;
      declare
         Excessive_Exec : Unbounded_String := To_Unbounded_String ("viewer");
      begin
         for Index in 1 .. 257 loop
            Append (Excessive_Exec, " argument" & Natural'Image (Index));
         end loop;
         Write_File
           (Join (Apps_Dir, "excessive-exec.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Excessive Exec" & LF
            & "Exec=" & To_String (Excessive_Exec) & LF);
      end;
      Write_Filler_File
        (Join (Apps_Dir, "oversized.desktop"),
         ' ',
         1 * 1024 * 1024 + 1,
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Oversized Entry" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "viewer.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Image Viewer" & LF & "Exec=viewer --open %U" & LF
         & "TryExec=" & Desktop_Escape (Try_Exec) & LF
         & "Terminal=false" & LF);
      Write_File
        (Join (Apps_Dir, "multi-marker.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Multi Target Marker" & LF
         & "Exec=" & Desktop_Exec_Escape (Files_Suite.Support.Marker_Executable)
         & " %f" & LF);
      Write_File
        (Join (Apps_Dir, "quoted.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Quoted App" & LF & "Icon=quoted-icon" & LF
         & "Exec=""/opt/Quoted Editor/bin/editor"" ""--mode=two words"""
         & " %F --after %% %c %i %k" & LF);
      Write_File
        (Join (Apps_Dir, "nodisplay.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Hidden Display" & LF & "NoDisplay=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "hidden.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Gone" & LF & "Hidden=true" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "link.desktop"),
         "[Desktop Entry]" & LF & "Type=Link" & LF
         & "Name=A Link" & LF & "Exec=nope" & LF);
      Write_File
        (Join (Apps_Dir, "noexec.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=No Command" & LF & "Exec=%F" & LF);
      Write_File
        (Join (Apps_Dir, "unknown-field.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Unknown Field" & LF & "Exec=viewer %Z" & LF);
      Write_File
        (Join (Apps_Dir, "unterminated.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Unterminated" & LF & "Exec=viewer ""broken" & LF);
      Write_File
        (Join (Apps_Dir, "invalid-boolean.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Invalid Boolean" & LF & "Hidden=FALSE" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-key.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Key" & LF & "Hidden=true" & LF
         & "Hidden=false" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Link" & LF
         & "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Group" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "duplicate-auxiliary-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Duplicate Auxiliary Group" & LF & "Exec=viewer %F" & LF
         & "[Extra]" & LF & "Value=one" & LF
         & "[Extra]" & LF & "Value=two" & LF);
      Write_File
        (Join (Apps_Dir, "malformed-line.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Malformed Line" & LF & "Hidden true" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "malformed-group.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Malformed Group" & LF & "Exec=viewer %F" & LF
         & "[Broken" & LF);
      Write_File
        (Join (Apps_Dir, "localized-name-only.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name[da]=Localized Name Only" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "localized-icon-only.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Localized Icon Only" & LF & "Icon[da]=localized-icon" & LF
         & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "missing.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Z Missing" & LF
         & "Exec=/tmp/files-open-with-definitely-missing %F" & LF);
      Write_File
        (Join (Apps_Dir, "same-one.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Shared Name" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "same-two.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Shared Name" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "masked.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Masked User Entry" & LF & "Hidden=true" & LF
         & "Exec=nope" & LF);
      Write_File
        (Join (System_Apps, "masked.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Should Stay Masked" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (System_Apps, "editor.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=System Editor" & LF & "Exec=viewer %F" & LF);
      Write_File
        (Join (Apps_Dir, "try-missing.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Try Missing" & LF & "Exec=viewer %F" & LF
         & "TryExec="
         & Desktop_Escape (Join (Root, "definitely-missing-try-exec")) & LF);
      Write_File
        (Join (Apps_Dir, "only-current.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=V Current Desktop" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "only-other.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Only Other Desktop" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "not-current.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Not Current Desktop" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "not-other.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=W Other Desktop Exclusion" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "both-visibility.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=X Both Visibility Lists" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF & "NotShowIn=KDE;" & LF);
      Write_File
        (Join (Apps_Dir, "excluded-later.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Excluded By Later Desktop" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF & "NotShowIn=GNOME;" & LF);
      Write_File
        (Join (Apps_Dir, "escaped-desktop.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Y Escaped Desktop Name" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=Escaped\;Desktop;" & LF);
      Write_File
        (Join (Apps_Dir, "invalid-list-escape.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Invalid List Escape" & LF & "Exec=viewer %F" & LF
         & "NotShowIn=FilesTest\q;" & LF);
      Write_File
        (Join (Apps_Dir, "overlapping-visibility.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Overlapping Visibility Lists" & LF & "Exec=viewer %F" & LF
         & "OnlyShowIn=FilesTest;" & LF & "NotShowIn=FilesTest;" & LF);
      Write_File
        (Join (Apps_Dir, "localized.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF
         & "Name=Fallback\sName" & LF
         & "Name[da]=Dansk\sNavn" & LF
         & "Name[da_DK]=Dansk\sProgram" & LF
         & "Icon=base\\icon" & LF
         & "Icon[da]=danish\\icon" & LF
         & "Icon[da_DK]=regional\\icon" & LF
         & "Exec=viewer --label=%c ""C:\\\\Temp"" %F %i" & LF);

      --  Application discovery is recursive, but a linked child must never
      --  become a traversal edge back to an ancestor.
      declare
         Loop_Created : constant Boolean :=
           Files_Suite.Support.Create_Symlink (Apps_Dir, Join (Apps_Dir, "loop"));
         pragma Unreferenced (Loop_Created);
      begin
         null;
      end;

      --  A malformed or hostile application tree must also have a finite
      --  recursion cost even where directory links are unavailable.
      declare
         Deep : Unbounded_String := To_Unbounded_String (Join (Apps_Dir, "deep"));
      begin
         for Level in 1 .. 66 loop
            Append
              (Deep,
               "/" & Character'Val
                 (Character'Pos ('a') + Level mod 26));
         end loop;
         Ada.Directories.Create_Path (To_String (Deep));
         Write_File
           (Join (To_String (Deep), "too-deep.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Too Deep" & LF & "Exec=viewer %F" & LF);
      end;

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", App_Base);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_DIRS", System_Base);
      Ada.Environment_Variables.Set
        ("XDG_CURRENT_DESKTOP", "FilesTest:GNOME:Escaped;Desktop");
      Ada.Environment_Variables.Set ("LC_ALL", "da_DK.UTF-8");

      Check.all;
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end With_Desktop_Application_Fixture;
