separate (Check_All)
   procedure Check_Shared_Package_State is
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      Checked : Name_Sets.Set;

      procedure Check (Path : String) is
         Code  : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         Start : Positive := Code'First;
      begin
         --  A subprogram's subunit declares only its own locals (its with
         --  clauses, if any, come before the separate).
         if Ada.Strings.Fixed.Index (Code, "separate (") > 0
           and then Ada.Strings.Fixed.Index (Code, "package body") = 0
         then
            return;
         end if;
         for Index in Code'Range loop
            if Code (Index) = ASCII.LF or else Index = Code'Last then
               declare
                  Line  : constant String := Code (Start .. (if Code (Index) = ASCII.LF then Index - 1 else Index));
                  Colon : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
               begin
                  --  An object declared at the package's own level: three
                  --  spaces, a name, a colon, and no constant, exception or
                  --  renaming.
                  if Line'Length > 4
                    and then Line (Line'First .. Line'First + 2) = "   "
                    and then Line (Line'First + 3) in 'A' .. 'Z'
                    and then Colon > 0
                    and then (for all C of Line (Line'First + 3 .. Colon - 1) =>
                                C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | ' ' | ',')
                    and then Ada.Strings.Fixed.Index (Line, "constant") = 0
                    and then Ada.Strings.Fixed.Index (Line, "exception") = 0
                    and then Ada.Strings.Fixed.Index (Line, "renames") = 0
                    and then Ada.Strings.Fixed.Index (Line, ":=") /= Colon
                  then
                     Put_Line
                       (Standard_Error,
                        Path & ": a package-level variable is shared by every task that runs this code: "
                        & Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));
                     Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                     raise Program_Error;
                  end if;
               end;
               Start := Index + 1;
            end if;
         end loop;
      end Check;

      procedure Check_All (Pattern : String) is
         Found : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree (Root & "/src", Pattern, Generated_Directories);
      begin
         for Item of Found loop
            Check (To_String (Item));
            Checked.Include (Ada.Directories.Simple_Name (To_String (Item)));
         end loop;
         if Found'Length = 0 then
            Put_Line (Standard_Error, "src/" & Pattern & ": no source matches; update Check_Shared_Package_State");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Check_All;
   begin
      Check_All ("files-file_system-thumbnails.ad?");
      Check_All ("files-images*.ad?");
      Check_All ("files-preview_decoder.ad?");
      --  The worker tasks of Files.Background_Slots, and the readers the
      --  info pane's worker runs.
      Check_All ("files-background_slots.ad?");
      Check_All ("files-extra_info_reader.ad?");
      Check_All ("files-file_system-*_info.adb");
      Check_All ("files-file_system-extra_info_of.adb");
      Check_All ("files-extra_info.ads");
      Check_All ("files-file_system-count_text_lines.adb");
      Check_All ("files-file_system-text_encoding_name.adb");
      --  Its worker runs a tree walk on a large stack while the caller waits.
      Check_All ("files-file_system-support.adb");

      --  Every unit that runs a task of its own is checked above, or says
      --  here why its package-level variables are not shared with the task.
      declare
         Main_Thread_State : constant Name_Sets.Set :=
           Name_Sets.Union
             --  Reaper is set and read by Ensure_Reaper and Shutdown only, on
             --  the thread that starts jobs; the reaper task touches neither.
             (Name_Sets.To_Set ("files-process_jobs.adb"),
              --  The monitor task reads the report label from a protected
              --  object and the report folder from the environment; the
              --  package's report variables are Scavenge's and Clean_Report's.
              Name_Sets.To_Set ("files-job_scavenger.adb"));
      begin
         for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.adb", Generated_Directories) loop
            declare
               Path : constant String := To_String (Item);
               Name : constant String := Ada.Directories.Simple_Name (Path);
               Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            begin
               if Ada.Strings.Fixed.Index (Code, "task body") > 0
                 and then not Checked.Contains (Name)
                 and then not Main_Thread_State.Contains (Name)
               then
                  Put_Line
                    (Standard_Error,
                     "src/" & Name & " runs a task: add it to Check_Shared_Package_State,"
                     & " or say there why its package state is not shared");
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                  raise Program_Error;
               end if;
            end;
         end loop;
      end;
   end Check_Shared_Package_State;
