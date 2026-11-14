separate (Files_Suite.Operations)
   --  A desktop entry with Terminal=true runs inside a terminal emulator:
   --  Terminal and Path are read, the launch wraps the program in the
   --  terminal's way of being handed one, and the entry is offered only
   --  where a terminal can run it.
   procedure Test_Desktop_Terminal_Entries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LF          : constant Character := ASCII.LF;
      Home        : constant String := Join (Root, "terminal-home");
      System_Base : constant String := Join (Root, "terminal-system");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Apps        : Files.Desktop_Applications.Application_Vectors.Vector;
      Program     : constant Files.Settings.Open_Action :=
        Files.Settings.Make_Action
          ("top", Files.Types.String_Vectors."&" (To_Unbounded_String ("-d"), To_Unbounded_String ("1")));

      --  Path as a desktop-entry string: a backslash is an escape there, so a
      --  Windows path's own backslashes are written doubled.
      function Escaped (Path : String) return String is
         Result : Unbounded_String;
      begin
         for C of Path loop
            Append (Result, (if C = '\' then "\\" else [C]));
         end loop;
         return To_String (Result);
      end Escaped;

      function Arguments_Image (Action : Files.Settings.Open_Action) return String is
         Result : Unbounded_String;
      begin
         for Argument of Action.Arguments loop
            Append (Result, "[" & To_String (Argument) & "]");
         end loop;
         return To_String (Result);
      end Arguments_Image;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "XDG_DATA_DIRS");
      Files_Suite.Support.Save (Environment, "XDG_CURRENT_DESKTOP");
      Files_Suite.Support.Save (Environment, "TERMINAL");
      Reset_Root;
      Ada.Directories.Create_Path (Join (Home, "applications"));
      Ada.Directories.Create_Path (Join (System_Base, "applications"));
      Write_File
        (Join (Join (Home, "applications"), "terminal-program.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF & "Name=Terminal Program" & LF
         & "Exec=top -d 1" & LF & "Terminal=true" & LF & "Path=" & Escaped (Root) & LF);
      Write_File
        (Join (Join (Home, "applications"), "window-program.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF & "Name=Window Program" & LF
         & "Exec=viewer %F" & LF & "Terminal=false" & LF);
      Write_File
        (Join (Join (Home, "applications"), "unclear-program.desktop"),
         "[Desktop Entry]" & LF & "Type=Application" & LF & "Name=Unclear Program" & LF
         & "Exec=viewer %F" & LF & "Terminal=maybe" & LF);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Home);
      Ada.Environment_Variables.Set ("XDG_DATA_DIRS", System_Base);
      Ada.Environment_Variables.Set ("XDG_CURRENT_DESKTOP", "");
      --  A program every POSIX host runs stands for the terminal.
      Ada.Environment_Variables.Set ("TERMINAL", "sh");

      Apps := Files.Desktop_Applications.Available_Applications;
      declare
         Window : constant Files.Desktop_Applications.Application := Find_Application (Apps, "Window Program");
         Shell  : constant Files.Desktop_Applications.Application := Find_Application (Apps, "Terminal Program");
         Terminal : constant String := Hostkit.Process.Default_Terminal;
         --  The entry's action as the scan builds it (on some hosts that is
         --  not the plain program: a name the host cannot run as it stands),
         --  which is what decides whether the entry is offered.
         Built    : constant Files.Settings.Open_Action :=
           Files.Desktop_Applications.Build_Open_Action
             ((Name => To_Unbounded_String ("Terminal Program"), Exec => To_Unbounded_String ("top -d 1"),
               Terminal => True, others => <>),
              Files.Types.String_Vectors.Empty_Vector);
         Runs     : constant Boolean :=
           To_String (Files.Desktop_Applications.In_Terminal (Built, Terminal).Executable) /= "";
         --  What the scan saw, for a failure message.
         Seen     : constant String :=
           " (terminal " & Terminal & ", action " & To_String (Built.Executable)
           & (if Built.Use_Shell then " through the shell" else "") & ")";
      begin
         Assert (To_String (Window.Exec) /= "" and then not Window.Terminal
                 and then To_String (Window.Working_Directory) = "",
                 "Terminal=false is a window program with no working directory");
         Assert (To_String (Find_Application (Apps, "Unclear Program").Exec) = "",
                 "an invalid Terminal value rejects the entry");
         if not Runs then
            Assert (To_String (Shell.Exec) = "", "with no usable terminal a terminal program is not offered" & Seen);
         else
            Assert (To_String (Shell.Exec) /= "" and then Shell.Terminal,
                    "Terminal=true is read where a terminal can run it" & Seen);
            Files_Suite.Support.Assert_Equal
              (To_String (Shell.Working_Directory), Root, "Path= is read as the working directory");
            declare
               Actions : constant Files.Desktop_Applications.Open_Action_Vectors.Vector :=
                 Files.Desktop_Applications.Launch_Actions
                   (Shell, Files.Types.String_Vectors.Empty_Vector, "xterm");
            begin
               Assert (Natural (Actions.Length) = 1
                       and then To_String (Actions.First_Element.Executable) = "xterm"
                       and then Arguments_Image (Actions.First_Element) = "[-e][top][-d][1]",
                       "the launch runs the program inside the terminal: "
                       & (if Actions.Is_Empty then "" else Arguments_Image (Actions.First_Element)));
               Assert (Natural (Actions.Length) = 1
                       and then Actions.First_Element.Working_Directory = Shell.Working_Directory,
                       "the launch starts in the entry's working directory");
            end;
         end if;
         Assert (Files.Desktop_Applications.Launch_Actions
                   (Shell, Files.Types.String_Vectors.Empty_Vector, "").Is_Empty
                 or else not Shell.Terminal,
                 "a terminal program has no launch without a terminal");
         Assert (To_String (Files.Desktop_Applications.Launch_Actions
                   (Window, Files.Types.String_Vectors.Empty_Vector, "xterm").First_Element.Executable) = "viewer",
                 "a window program is launched as it is");
      end;

      --  Each terminal's own way of being handed a program.
      declare
         procedure Check (Terminal, Expected_Arguments : String) is
            Wrapped : constant Files.Settings.Open_Action :=
              Files.Desktop_Applications.In_Terminal (Program, Terminal);
         begin
            Files_Suite.Support.Assert_Equal
              (To_String (Wrapped.Executable) & " " & Arguments_Image (Wrapped),
               (if Expected_Arguments = "" then " " else Terminal & " " & Expected_Arguments),
               "the program runs inside " & Terminal);
         end Check;
      begin
         Check ("xterm", "[-e][top][-d][1]");
         Check ("/usr/bin/gnome-terminal", "[--][top][-d][1]");
         Check ("xfce4-terminal", "[-x][top][-d][1]");
         Check ("wezterm", "[start][--][top][-d][1]");
         Check ("kitty", "[top][-d][1]");
         Check ("pwsh", "");
         Check ("", "");
      end;
      Reset_Root;
   end Test_Desktop_Terminal_Entries;
