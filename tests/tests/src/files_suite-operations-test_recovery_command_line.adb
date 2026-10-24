separate (Files_Suite.Operations)
   procedure Test_Recovery_Command_Line (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest     : constant String := Join (Root, "kept.txt");
      Plain    : constant String := Join (Root, "plain.txt");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
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

      procedure Restore_Environment is
      begin
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      Reset_Root;
      Write_Binary_File (Plain, "not a payload");
      Assert (not Run (Plain), "an ordinary argument is not a recovery command");
      Assert (Run ("--discard-recovery", Plain) and then Failed and then Ada.Directories.Exists (Plain),
              "discarding a path that is not a recovery payload is refused and keeps it");
      Assert (Run ("--discard-recovery") and then Failed, "a command without its argument fails");

      Write_Binary_File (Dest, "original");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then not Ada.Directories.Exists (Dest), "the original is kept as a payload");
      Assert (Run ("--recover", To_String (Backup)) and then not Failed
              and then Project_Tools.Files.Read_Raw_File (Dest) = "original",
              "--recover puts the original back");

      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Run ("--discard-recovery", To_String (Backup)) and then not Failed
              and then not Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "--discard-recovery deletes the payload");
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Recovery_Command_Line;
