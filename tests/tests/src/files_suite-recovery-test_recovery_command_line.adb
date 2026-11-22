with Files.File_System.Recovery_Registry;
with Files_Suite.Support.Guards;
separate (Files_Suite.Recovery)
   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest     : constant String := Join (Root, "kept.txt");
      Plain    : constant String := Join (Root, "plain.txt");
      Backup   : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Failed   : Boolean;

      function Run (First : String; Second : String := "") return Boolean is
         Arguments : Files.Types.String_Vectors.Vector;
      begin
         Arguments.Append (To_Unbounded_String (First));
         if Second /= "" then
            Arguments.Append (To_Unbounded_String (Second));
         end if;
         return Files.Recovery_CLI.Run (Arguments, Failed);
      end Run;

      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Write_Binary_File (Plain, "not a payload");
      Assert (not Run (Plain), "an ordinary argument is not a recovery command");
      Assert (Run ("--discard-recovery", Plain),
              "discarding a path that is not a recovery payload is refused and keeps it: handled as a command");
      Assert (Failed, "discarding a path that is not a recovery payload is refused and keeps it: refused");
      Assert (Ada.Directories.Exists (Plain),
              "discarding a path that is not a recovery payload is refused and keeps it: path kept");
      Assert (Run ("--discard-recovery") and then Failed, "a command without its argument fails");

      Write_Binary_File (Dest, "original");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Recovery_Registry.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then not Ada.Directories.Exists (Dest), "the original is kept as a payload");
      Assert (Run ("--recover", To_String (Backup)), "--recover puts the original back: handled as a command");
      Assert (not Failed, "--recover puts the original back: succeeded");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Dest), "original", "--recover puts the original back: bytes");

      Result := Files.File_System.Recovery_Registry.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "the restored original is kept as a payload again");
      Assert (Run ("--discard-recovery", To_String (Backup)),
              "--discard-recovery deletes the payload: handled as a command");
      Assert (not Failed, "--discard-recovery deletes the payload: succeeded");
      Assert (not Files.File_System.Recovery_Registry.Is_Recovery_Payload (To_String (Backup)),
              "--discard-recovery deletes the payload: payload gone");

      --  The list keeps each path on its line and in its field, and sends no
      --  control byte to the terminal; a path pasted from it reads back.
      declare
         Odd : constant String := "/x/a" & ASCII.HT & "b" & ASCII.LF & "c" & ASCII.ESC & "[2J" & ASCII.CR;
         Odd_Windows : constant String := "C:\x\a" & ASCII.HT & "b" & ASCII.ESC;
      begin
         if Hostkit.Fs.Separator = '\' then
            Files_Suite.Support.Assert_Equal
              (Files.Recovery_CLI.Escaped (Odd_Windows), "C:\x\a\tb\x1b",
               "control bytes print escaped, separators as they are");
            Files_Suite.Support.Assert_Equal
              (Files.Recovery_CLI.Unescaped ("C:\temp\x41"), "C:\temp\x41", "a Windows path reads as it is");
         else
            Files_Suite.Support.Assert_Equal
              (Files.Recovery_CLI.Escaped (Odd & "\"), "/x/a\tb\nc\x1b[2J\r\\",
               "control bytes and backslashes print escaped");
            Files_Suite.Support.Assert_Equal
              (Files.Recovery_CLI.Unescaped (Files.Recovery_CLI.Escaped (Odd & "\q")), Odd & "\q",
               "a printed path reads back as the path");
         end if;
         Files_Suite.Support.Assert_Equal
           (Files.Recovery_CLI.Escaped ("/plain/" & "caf" & Character'Val (16#C3#) & Character'Val (16#A9#)),
            "/plain/" & "caf" & Character'Val (16#C3#) & Character'Val (16#A9#),
            "a path with nothing to escape prints as it is");
      end;
   end Test_Recovery_Command_Line;
