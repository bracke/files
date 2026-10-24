separate (Files_Suite.Operations)
   procedure Test_Available_Applications (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
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
      Original_Directory : constant String := Ada.Directories.Current_Directory;

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

      function Find
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Applications.Application is
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               return App;
            end if;
         end loop;
         return
           (Name         => Null_Unbounded_String,
            Exec         => Null_Unbounded_String,
            Icon         => Null_Unbounded_String,
            Desktop_File => Null_Unbounded_String);
      end Find;

      function Count_Name
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String) return Natural
      is
         Result : Natural := 0;
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count_Name;
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

      declare
         Apps : constant Files.Applications.Application_Vectors.Vector :=
           Files.Applications.Available_Applications;
         Editor : constant Files.Applications.Application := Find (Apps, "Text Editor");
         Viewer : constant Files.Applications.Application := Find (Apps, "Image Viewer");
         Quoted : constant Files.Applications.Application := Find (Apps, "Quoted App");
         Localized : constant Files.Applications.Application :=
           Find (Apps, "Dansk Program");
      begin
         Assert
           (Natural (Apps.Length) = 13,
            "valid desktop IDs are returned without collapsing shared display names");
         Assert
           (To_String (Apps.First_Element.Name) = "Dansk Program",
            "applications use and sort by the best localized decoded name");
         Assert
           (Count_Name (Apps, "Shared Name") = 2,
            "distinct desktop IDs may expose the same application name");
         Assert
           (To_String (Find (Apps, "Should Stay Masked").Exec) = ""
            and then To_String (Find (Apps, "System Editor").Exec) = "",
            "higher-priority desktop IDs mask lower-priority system entries");
         Assert
           (To_String (Find (Apps, "Try Missing").Exec) = "",
            "an unavailable TryExec keeps an application out of the picker");
         Assert
           (To_String (Find (Apps, "Oversized Entry").Exec) = "",
            "oversized desktop entries are rejected before line allocation");
         Assert
           (To_String (Find (Apps, "Linked Application").Exec) = "",
            "application discovery refuses linked desktop entries");
         Assert
           (To_String (Find (Apps, "Excessive Exec").Exec) = "",
            "desktop entries with excessive Exec vectors are rejected");
         Assert
           (To_String (Find (Apps, "ZZ CRLF Application").Exec) = "viewer %F",
            "desktop entries with CRLF line endings are accepted");
         Assert
           (To_String (Find (Apps, "Invalid Boolean").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Key").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Group").Exec) = "",
            "invalid booleans, duplicate keys, and duplicate groups are rejected");
         Assert
           (To_String (Find (Apps, "Duplicate Auxiliary Group").Exec) = ""
            and then To_String (Find (Apps, "Malformed Line").Exec) = ""
            and then To_String (Find (Apps, "Malformed Group").Exec) = "",
            "malformed syntax and duplicate auxiliary groups are rejected");
         Assert
           (To_String (Find (Apps, "Localized Name Only").Exec) = ""
            and then To_String (Find (Apps, "Localized Icon Only").Exec) = "",
            "localized values require their unlocalized base keys");
         Assert
           (To_String (Find (Apps, "V Current Desktop").Exec) /= ""
            and then To_String (Find (Apps, "Only Other Desktop").Exec) = ""
            and then To_String (Find (Apps, "Not Current Desktop").Exec) = ""
            and then To_String
              (Find (Apps, "W Other Desktop Exclusion").Exec) /= "",
            "desktop visibility keys are applied to every current desktop name");
         Assert
           (To_String (Find (Apps, "X Both Visibility Lists").Exec) /= ""
            and then To_String
              (Find (Apps, "Excluded By Later Desktop").Exec) = ""
            and then To_String (Find (Apps, "Y Escaped Desktop Name").Exec) /= ""
            and then To_String (Find (Apps, "Invalid List Escape").Exec) = ""
            and then To_String
              (Find (Apps, "Overlapping Visibility Lists").Exec) = "",
            "visibility lists decode escapes, honor later exclusions, and permit only disjoint coexistence");
         Assert
           (To_String (Editor.Exec) = "editor %F",
            "the desktop Exec template is retained for positional expansion");
         Assert
           (To_String (Viewer.Exec) = "viewer --open %U",
            "base arguments and their target field position are retained");

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Localized, Targets);
            Assert
              (To_String (Localized.Icon) = "regional\icon"
               and then Natural (Action.Arguments.Length) = 6
               and then To_String (Action.Arguments.Element (1)) =
                 "--label=Dansk Program"
               and then To_String (Action.Arguments.Element (2)) = "C:\Temp"
               and then To_String (Action.Arguments.Element (5)) = "--icon"
               and then To_String (Action.Arguments.Element (6)) =
                 "regional\icon",
               "localized values and two-stage desktop escapes expand correctly");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Viewer, Targets);
            Assert
              (To_String (Action.Executable) = "viewer",
               "action executable is the first Exec token");
            Assert
              (not Action.Use_Shell,
               "open-with action is not shell-wrapped");
            Assert
              (Natural (Action.Arguments.Length) = 3,
               "arguments are remaining Exec tokens followed by each target");
            Assert
              (To_String (Action.Arguments.Element (1)) = "--open",
               "base Exec argument is preserved");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a.txt",
               "first target path is appended");
            Assert
              (To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "second target path is appended");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Quoted, Targets);
            Assert
              (To_String (Action.Executable) = "/opt/Quoted Editor/bin/editor",
               "a quoted desktop executable remains one executable token");
            Assert
              (Natural (Action.Arguments.Length) = 9,
               "quoted arguments and desktop field codes expand to the expected vector");
            Assert
              (To_String (Action.Arguments.Element (1)) = "--mode=two words",
               "a quoted desktop argument remains one argument");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a file.txt"
               and then To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "a list field code expands in place with argument boundaries intact");
            Assert
              (To_String (Action.Arguments.Element (4)) = "--after",
               "arguments after the target field keep their position");
            Assert
              (To_String (Action.Arguments.Element (5)) = "%",
               "a doubled percent becomes one literal percent argument");
            Assert
              (To_String (Action.Arguments.Element (6)) = "Quoted App",
               "the application-name field expands as one argument");
            Assert
              (To_String (Action.Arguments.Element (7)) = "--icon"
               and then To_String (Action.Arguments.Element (8)) = "quoted-icon",
               "the icon field expands to its two specified arguments");
            Assert
              (Hostkit.Metadata.Same_File
                 (To_String (Action.Arguments.Element (9)),
                  Join (Apps_Dir, "quoted.desktop")),
               "the desktop-file field expands to the source desktop entry");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Single_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Single Target"),
               Exec         => To_Unbounded_String ("viewer --before %f --after"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Percent_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Percent Executable"),
               Exec         => To_Unbounded_String ("viewer%%tool %F"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Actions : Files.Applications.Open_Action_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Actions := Files.Applications.Build_Open_Actions (Single_App, Targets);
            Assert
              (Natural (Actions.Length) = 2
               and then Natural (Actions.Element (1).Arguments.Length) = 3
               and then To_String (Actions.Element (1).Arguments.Element (2)) =
                 "/tmp/a.txt"
               and then Natural (Actions.Element (2).Arguments.Length) = 3
               and then To_String (Actions.Element (2).Arguments.Element (2)) =
                 "/tmp/b.txt",
               "single-file fields produce one positional launch per selected target");

            Actions := Files.Applications.Build_Open_Actions (Viewer, Targets);
            Assert
              (Natural (Actions.Length) = 1
               and then Natural (Actions.First_Element.Arguments.Length) = 3,
               "multi-file fields retain one launch containing every target");

            Action := Files.Applications.Build_Open_Action (Percent_App, Targets);
            Assert
              (To_String (Action.Executable) = "viewer%tool"
               and then Natural (Action.Arguments.Length) = 2,
               "a doubled percent is decoded in the executable token");
         end;

         declare
            Model      : Files.Model.Window_Model;
            Targets    : Files.Types.String_Vectors.Vector;
            Routed     : Files.Controller.Controller_Result;
            Marker_One : constant String := Join (Root, "open-with-first-marker");
            Marker_Two : constant String := Join (Root, "open-with-second-marker");
         begin
            Targets.Append (To_Unbounded_String (Marker_One));
            Targets.Append (To_Unbounded_String (Marker_Two));
            Files.Model.Initialize
              (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Open_Command_Palette (Model);
            Files.Model.Set_Open_With_Targets (Model, Targets);
            Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Palette_Set_Query (Model, "Multi Target Marker");
            Files.Model.Palette_Select_First (Model);

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Assert
              (Routed.Operation.Status = Files.Operations.Operation_Action_Executed
               and then Routed.Operation.Execution_Attempted
               and then Routed.Operation.Executable_Found,
               "Open With launches a single-target application for multiple selections: "
               & "status=" & Files.Operations.Operation_Status'Image (Routed.Operation.Status)
               & " attempted=" & Boolean'Image (Routed.Operation.Execution_Attempted)
               & " found=" & Boolean'Image (Routed.Operation.Executable_Found)
               & " exit=" & Integer'Image (Routed.Operation.Exit_Status)
               & " executable=" & To_String (Routed.Operation.Action_Executable));
            Assert
              (To_String (Routed.Operation.Path) = Marker_One
               and then Routed.Operation.Action_Arguments = 1
               and then To_String (Routed.Operation.Action.Arguments.First_Element) =
                 Marker_One,
               "a multi-launch result retains the first target's action metadata");

            for Attempt in 1 .. 5_000 loop
               exit when Ada.Directories.Exists (Marker_One)
                 and then Ada.Directories.Exists (Marker_Two);
               delay 0.001;
            end loop;
            Assert
              (Ada.Directories.Exists (Marker_One)
               and then Ada.Directories.Exists (Marker_Two),
               "Open With executes one %f launch for every selected target");
         end;

         declare
            Model   : Files.Model.Window_Model;
            Targets : Files.Types.String_Vectors.Vector;
            Routed  : Files.Controller.Controller_Result;
         begin
            Files.Model.Initialize
              (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Files.Model.Open_Command_Palette (Model);
            Files.Model.Set_Open_With_Targets (Model, Targets);
            Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
            Files.Model.Palette_Select_Last (Model);
            Assert
              (Files.Model.Palette_Selected_Id (Model) = 13,
               "the missing executable fixture is selected from the Open With palette");

            Routed := Files.Controller.Activate_Palette_Command
              (Model, Files.Settings.Default_Settings);
            Assert
              (Routed.Operation.Status = Files.Operations.Operation_Failed
               and then To_String (Routed.Operation.Error_Key) =
                 "error.open_action.executable_missing",
               "Open With reports a missing application executable as failure");
            Assert
              (not Routed.Operation.Execution_Attempted
               and then not Routed.Operation.Executable_Found,
               "Open With rejects the application before attempting a process");
            Assert
              (To_String (Routed.Operation.Path) = "/tmp/a file.txt"
               and then Routed.Operation.Action_Arguments = 1,
               "the failed Open With result retains its target and action metadata");
            Assert
              (Files.Model.Last_Error_Key (Model) =
                 "error.open_action.executable_missing"
               and then not Files.Model.Command_Palette_Is_Open (Model),
               "Open With exposes the diagnostic and closes the handled picker");
         end;
      end;

      --  XDG base-directory variables never make relative paths meaningful.
      --  Change the process directory so a buggy implementation would find
      --  both fixtures, while a conforming one still sees the absolute system
      --  component that follows the invalid relative component.
      declare
         Relative_Home : constant String := Join (Root, "relative-home");
         Relative_Dirs : constant String := Join (Root, "relative-system");
         Apps : Files.Applications.Application_Vectors.Vector;
      begin
         Ada.Directories.Create_Path (Join (Relative_Home, "applications"));
         Ada.Directories.Create_Path (Join (Relative_Dirs, "applications"));
         Write_File
           (Join (Join (Relative_Home, "applications"), "relative-home.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Home" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (Join (Relative_Dirs, "applications"), "relative-dir.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Relative Data Directory" & LF & "Exec=viewer %F" & LF);
         Write_File
           (Join (System_Apps, "absolute-system.desktop"),
            "[Desktop Entry]" & LF & "Type=Application" & LF
            & "Name=Absolute System Directory" & LF & "Exec=viewer %F" & LF);

         Ada.Directories.Set_Directory (Root);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", "relative-home");
         Ada.Environment_Variables.Set
           ("XDG_DATA_DIRS", "relative-system:" & System_Base);
         Apps := Files.Applications.Available_Applications;
         Assert
           (To_String (Find (Apps, "Relative Data Home").Exec) = ""
            and then To_String (Find (Apps, "Relative Data Directory").Exec) = ""
            and then To_String (Find (Apps, "Absolute System Directory").Exec) /= "",
            "application discovery ignores relative XDG paths and keeps absolute components");
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;

      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Available_Applications;
