separate (Check_All)
   procedure Check_Environment_Access is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      --  Whether lower-cased code (comments dropped, literals kept) reads the
      --  environment: Ada's own, Hostkit's (which Files.Environment wraps), a
      --  C getenv bound by hand, GNAT's command-line environment, the C
      --  environment block imported whole (environ, _environ, __environ,
      --  _wenviron, macOS's _NSGetEnviron), or the Win32 calls.
      function Reads_Environment (Lower : String) return Boolean is
         type Pattern_List is array (Positive range <>) of Unbounded_String;
         Patterns : constant Pattern_List :=
           [To_Unbounded_String ("ada.environment_variables"),
            To_Unbounded_String ("hostkit.environment"),
            To_Unbounded_String ("getenv"),
            To_Unbounded_String ("environment_value"),
            To_Unbounded_String ("command_line.environment"),
            To_Unbounded_String ("""environ"""),
            To_Unbounded_String ("""_environ"""),
            To_Unbounded_String ("""__environ"""),
            To_Unbounded_String ("""_wenviron"""),
            To_Unbounded_String ("nsgetenviron"),
            To_Unbounded_String ("getenvironmentstrings"),
            To_Unbounded_String ("getenvironmentvariable")];
      begin
         return (for some Pattern of Patterns => Ada.Strings.Fixed.Index (Lower, To_String (Pattern)) > 0);
      end Reads_Environment;

      --  The lint itself, on the imports it exists for: if it stopped seeing
      --  one, the tree search below would pass on every source.
      type Sample_List is array (Positive range <>) of Unbounded_String;
      Samples : constant Sample_List :=
        [To_Unbounded_String ("V : constant String := Ada.Environment_Variables.Value (Name);"),
         To_Unbounded_String
           ("Env : System.Address" & ASCII.LF & "  with Import, Convention => C, External_Name => ""environ"";"),
         To_Unbounded_String
           ("pragma Import (C, Env, ""__environ"");"),
         To_Unbounded_String
           ("function NS_Get_Environ return System.Address" & ASCII.LF
            & "  with Import, Convention => C, External_Name => ""_NSGetEnviron"";"),
         To_Unbounded_String
           ("function Block return System.Address with Import, Convention => Stdcall,"
            & " External_Name => ""GetEnvironmentStringsW"";")];
   begin
      for Index in Samples'Range loop
         if not Reads_Environment (Ada.Characters.Handling.To_Lower (Code_Of (To_String (Samples (Index))))) then
            Put_Line
              (Standard_Error,
               "check_all's Check_Environment_Access no longer sees the read in its sample" & Natural'Image (Index));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end loop;

      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path : constant String := Ada.Directories.Full_Name (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            Lower : constant String := Ada.Characters.Handling.To_Lower (Code);
         begin
            if Ada.Directories.Simple_Name (Path) not in "files-environment.adb" | "files-environment.ads"
              and then Reads_Environment (Lower)
            then
               Ada.Directories.End_Search (Search);
               Put_Line (Standard_Error, Path & ": reads the environment directly; use Files.Environment");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Environment_Access;
