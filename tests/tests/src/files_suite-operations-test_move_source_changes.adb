with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Move_Source_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote : Files_Suite.Volumes.Remote_Directory;
      Source : constant String := Join (Root, "changing-source");
      Held : constant String := Join (Root, "held-source");
      Paths : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
      Checks : Natural;
      Current : Positive;
      Old_Time : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5);
      Original_Id : Unbounded_String;
      function Change_Source return Boolean is
         Change_At : constant Positive := (if Current <= 2 then 4 elsif Current = 4 then 6 else 5);
      begin
         Checks := Checks + 1;
         if Checks = Change_At then
            case Current is
               when 1 =>
                  Assert (Hostkit.Fs.Move_No_Replace (Source, Held), "retain the old source inode");
                  Write_Binary_File (Source, "new bytes");
               when 2 =>
                  Write_Binary_File (Source, "new bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, Old_Time);
                  Assert (Files.File_Identities.Token (Source) = Original_Id, "the edited source keeps its inode");
               when 3 =>
                  Write_Binary_File (Join (Source, "child"), "new bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Source, "child"), Old_Time);
               when 4 => Write_Binary_File (Join (Source, "late-child"), "new bytes");
               when others =>
                  Assert (Hostkit.Fs.Move_No_Replace (Join (Source, "child"), Held), "retain the old child inode");
                  Write_Binary_File (Join (Source, "child"), "new bytes");
            end case;
         end if;
         return False;
      end Change_Source;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Move_Source_Changes", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-source-changes-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Move_Source_Changes", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      for Kind in 1 .. 5 loop
         Reset_Root;
         Current := Kind;
         Checks := 0;
         if Kind <= 2 then
            Write_Binary_File (Source, "old bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, Old_Time);
         else
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "child"), "old bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Source, "child"), Old_Time);
         end if;
         Original_Id := To_Unbounded_String (Files.File_Identities.Token (Source));
         Paths.Clear;
         Paths.Append (Files.File_System.Drop_Import_Plan'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (Remote.Path, "destination")),
            Files.File_System.Drop_Move, True, Null_Unbounded_String));
         Mutation := Files.File_System.Execute_Drop_Import (Paths, Change_Source'Unrestricted_Access);
         Assert (not Mutation.Success and then Ada.Directories.Exists (Source)
                 and then not Ada.Directories.Exists (Join (Remote.Path, "destination")),
                 "a changed move source is kept and only the owned destination copy is rolled back");
         Assert (File_Has_Bytes
           ((if Kind <= 2 then Source elsif Kind = 4 then Join (Source, "late-child") else Join (Source, "child")),
            "new bytes"), "the uncopied replacement or edit survives failure");
      end loop;
   end Test_Move_Source_Changes;
