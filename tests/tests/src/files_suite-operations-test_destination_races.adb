separate (Files_Suite.Operations)
   procedure Test_Destination_Races (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "race-source");
      Dest   : constant String := Join (Root, "race-dest");
      Target : constant String := Join (Root, "race-target");
      type Entry_Kind is (File_Entry, Directory_Entry, Link_Entry);
      Current : Entry_Kind;
      Created : Boolean;
      Checks  : Natural;
      Plans   : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Result  : Files.File_System.Mutation_Result;

      function Race return Boolean is
      begin
         Checks := Checks + 1;
         if Checks = 1 then
            case Current is
               when File_Entry => Write_Binary_File (Dest, "unrelated");
               when Directory_Entry =>
                  Ada.Directories.Create_Directory (Dest);
                  Write_Binary_File (Join (Dest, "keep"), "unrelated");
               when Link_Entry => Created := Hostkit.Fs.Create_Link (Target, Dest);
            end case;
         end if;
         return False;
      end Race;
   begin
      Reset_Root;
      Write_Binary_File (Source, "source");
      Write_Binary_File (Target, "unrelated");
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Kind in Entry_Kind loop
            Current := Kind;
            Created := True;
            Checks := 0;
            Plans.Clear;
            Plans.Append (Files.File_System.Drop_Import_Plan'
                            (To_Unbounded_String (Source), To_Unbounded_String (Dest), Mode, True,
                             Null_Unbounded_String));
            Result := Files.File_System.Execute_Drop_Import (Plans, Race'Unrestricted_Access);
            if Created then
               Assert (not Result.Success, "a collision after validation fails without overwriting");
               case Kind is
                  when File_Entry =>
                     Assert (Project_Tools.Files.Read_Raw_File (Dest) = "unrelated", "the raced file is preserved");
                  when Directory_Entry =>
                     Assert (Project_Tools.Files.Read_Raw_File (Join (Dest, "keep")) = "unrelated",
                             "the raced directory and its contents are preserved");
                  when Link_Entry => Assert (Hostkit.Fs.Is_Link (Dest), "the raced symlink is preserved");
               end case;
               Assert (Project_Tools.Files.Read_Raw_File (Source) = "source",
                       "the source is never deleted on collision");
               Result := Files.File_System.Delete_Permanently (Dest);
               Assert (Result.Success, "the owned collision fixture is cleaned");
            else
               --  Hosts without link privileges may complete this copy or move.
               if not Ada.Directories.Exists (Source) then
                  Ada.Directories.Rename (Dest, Source);
               elsif Ada.Directories.Exists (Dest) then
                  Ada.Directories.Delete_File (Dest);
               end if;
            end if;
         end loop;
      end loop;
      Assert (Project_Tools.Files.Read_Raw_File (Target) = "unrelated", "link targets remain untouched");
      Ada.Directories.Create_Directory (Join (Root, "source-dir"));
      Ada.Directories.Create_Directory (Join (Root, "target-dir"));
      Write_Binary_File (Join (Join (Root, "source-dir"), "keep"), "source");
      Assert (not Hostkit.Fs.Move_No_Replace (Join (Root, "source-dir"), Join (Root, "target-dir")),
              "a directory move refuses to replace even an empty existing directory");
      Assert (Ada.Directories.Exists (Join (Join (Root, "source-dir"), "keep")),
              "the directory source survives an atomic move collision");
   end Test_Destination_Races;
