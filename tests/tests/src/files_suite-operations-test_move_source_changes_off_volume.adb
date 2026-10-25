with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  A folder moved off another volume, a child edited during the copy to
   --  the same size with its time put back: the change time catches it on a
   --  POSIX volume, its content on a FAT stick, whose change time moves with
   --  the modification time. Either way the source is kept.
   procedure Test_Move_Source_Changes_Off_Volume (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Old_Time : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 6);
      Checks   : Natural := 0;
      Source   : Unbounded_String;

      function Edit_Child return Boolean is
         Child : constant String := Join (To_String (Source), "child");
      begin
         Checks := Checks + 1;
         if Checks = 5 then
            Write_Binary_File (Child, "new bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Child, Old_Time);
         end if;
         return False;
      end Edit_Child;
   begin
      Reset_Root;
      Remote.Create ("files-test-off-volume-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Move_Source_Changes_Off_Volume", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Source := To_Unbounded_String (Join (Remote.Path, "changing"));
      Ada.Directories.Create_Directory (To_String (Source));
      Write_Binary_File (Join (To_String (Source), "child"), "old bytes");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (To_String (Source), "child"), Old_Time);
      declare
         Plans    : Files.File_System.Drop_Import_Plan_Vectors.Vector;
         Mutation : Files.File_System.Mutation_Result;
      begin
         Plans.Append (Files.File_System.Drop_Import_Plan'
           (Source, To_Unbounded_String (Join (Root, "moved")), Files.File_System.Drop_Move, True,
            Null_Unbounded_String));
         Mutation := Files.File_System.Execute_Drop_Import (Plans, Edit_Child'Unrestricted_Access);
         Assert (Checks >= 5, "the copy reached the point where the child changes");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key), "error.move.source_changed",
            "a move whose source changed during the copy is refused as changed");
         Assert (File_Has_Bytes (Join (To_String (Source), "child"), "new bytes"),
                 "the edited source is kept");
         Assert (not Ada.Directories.Exists (Join (Root, "moved")), "the stale copy is rolled back");
      end;
   end Test_Move_Source_Changes_Off_Volume;
