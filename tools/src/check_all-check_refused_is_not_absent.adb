separate (Check_All)
   procedure Check_Refused_Is_Not_Absent is
      --  The units that remove, unregister, forget or retire recovery and
      --  job state when what it points at is gone. Each body is read with
      --  its subunits (<stem>-*.adb).
      Units : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("src/files-file_system-recovery.adb"),
         To_Unbounded_String ("src/files-file_system-delete_transport_entry.adb"),
         To_Unbounded_String ("src/files-file_system-delete_verified_entry.adb"),
         To_Unbounded_String ("src/files-file_system-rename_item.adb"),
         To_Unbounded_String ("src/files-job_context.adb"),
         To_Unbounded_String ("src/files-job_transports.adb"),
         To_Unbounded_String ("src/files-job_scavenger.adb"),
         To_Unbounded_String ("src/files-job_cleanup.adb"),
         To_Unbounded_String ("src/files-process_jobs.adb")];

      --  Exists and Entry_Exists answer "not there" when the host refuses
      --  the lookup, so "not" of either takes a refusal for absence.
      Negations : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("not files.fs_primitives.exists"),
         To_Unbounded_String ("not files.fs_primitives.entry_exists"),
         To_Unbounded_String ("not fs_primitives.exists"),
         To_Unbounded_String ("not fs_primitives.entry_exists")];

      --  Text lowered, with every run of blanks and line ends one space, so
      --  a negation split over lines is still seen.
      function Collapsed (Text : String) return String is
         Result : Unbounded_String;
         Blank  : Boolean := False;
      begin
         for C of Text loop
            if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
               Blank := True;
            else
               if Blank and then Length (Result) > 0 then
                  Append (Result, ' ');
               end if;
               Blank := False;
               Append (Result, (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C));
            end if;
         end loop;
         return To_String (Result);
      end Collapsed;

      procedure Check_File (Path : String) is
         Code : constant String :=
           Collapsed (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
      begin
         for Pattern of Negations loop
            if Ada.Strings.Fixed.Index (Code, To_String (Pattern)) > 0 then
               Report
                 (Path & ": a removal or forget decision asks '" & To_String (Pattern)
                  & "', which takes a refused lookup for absence; ask Files.Fs_Primitives.Entry_Is_Absent "
                  & "(gone for sure), or a kind (Directory_Exists, File_Exists) for a validity check");
            end if;
         end loop;
      end Check_File;
   begin
      for Unit of Units loop
         declare
            Base : constant String := Root & "/" & To_String (Unit);
            Dir  : constant String := Ada.Directories.Containing_Directory (Base);
            Stem : constant String := Ada.Directories.Base_Name (Base);
         begin
            --  A guard on a unit that was renamed or split away guards nothing.
            if not Project_Tools.Files.File_Exists (Base) then
               Report ("guarded unit is missing: " & Base & " (refused-is-not-absent)");
            else
               Check_File (Base);
               for Subunit of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
                  Check_File (To_String (Subunit));
               end loop;
            end if;
         end;
      end loop;
   end Check_Refused_Is_Not_Absent;
