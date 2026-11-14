separate (Files_Suite.Operations)
   --  A size measured before its folder changed was kept: the running
   --  helper went on while the new listing asked for the same folder, and a
   --  finished result waiting in the scan was applied after the reload, so
   --  the stale total was cached. Each folder is now asked for with the time
   --  it was listed at; a helper measuring an older listing is restarted,
   --  and a result for one is dropped and the folder measured again.
   procedure Test_Stale_Folder_Size_Dropped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Folder   : constant String := Join (Root, "folder");
      Marker   : constant String := Join (Root, "size-started");
      Earlier  : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2001, 1, 1, Time_Zone => 0);
      Later    : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (2002, 1, 1, Time_Zone => 0);
      Scan     : Files.Folder_Size.Session;
      Paths    : Files.Folder_Size.Path_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      Stale    : constant Files.File_System.Directory_Size_Result :=
        (Available => True, Total_Bytes => 999, File_Count => 1, Item_Count => 1, Capped => False);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      function Listed (Time : Ada.Calendar.Time) return Files.Folder_Size.Time_Vectors.Vector is
        (Files.Folder_Size.Time_Vectors.To_Vector (Time, 1));

      procedure Await_Marker (Message : String) is
      begin
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Marker);
         end loop;
         Assert (Ada.Directories.Exists (Marker), Message);
         Ada.Directories.Delete_File (Marker);
      end Await_Marker;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TEST_STALL_FOLDER_SIZES");
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_Binary_File (Join (Folder, "data"), "one");
      Paths.Append (To_Unbounded_String (Folder));

      --  A helper measuring the folder as listed then is kept while the
      --  same listing is asked for, and restarted for a newer one.
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Files.Folder_Size.Set_Targets (Scan, Paths, Listed (Earlier));
      Await_Marker ("the measurement is under way");
      Files.Folder_Size.Set_Targets (Scan, Paths, Listed (Earlier));
      delay 0.2;
      Assert (not Ada.Directories.Exists (Marker), "the same listing keeps the running measurement");
      Files.Folder_Size.Set_Targets (Scan, Paths, Listed (Later));
      Await_Marker ("a newer listing of the folder restarts it");
      Assert (Files.Folder_Size.Testing.Target (Scan) = Folder, "for the same folder");
      Files.Folder_Size.Cancel (Scan);
      Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");

      --  A finished result for an older listing is not cached: the folder is
      --  measured again, as it is now.
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "folder");
      Measured.Append
        (Files.Folder_Size.Measurement'(Path => To_Unbounded_String (Folder), Result => Stale, Listed => Earlier));
      declare
         Again : Files.Folder_Size.Measurement_Vectors.Vector;

         --  What Operations.Poll_Folder_Sizes does with the folders handed back.
         procedure Measure_Again (Scan : in out Files.Folder_Size.Session) is
         begin
            for Folder of Again loop
               Files.Folder_Size.Measure_Again (Scan, To_String (Folder.Path), Folder.Listed);
            end loop;
         end Measure_Again;
      begin
         Files.Model.Note_Folder_Sizes (Model, Measured, Again);
         Assert (Natural (Again.Length) = 1, "the stale folder is handed back to be measured again");
         Files.Model.Update_Folder_Scan (Model, Measure_Again'Access);
      end;
      Assert (not Files.Model.Folder_Size_Cached_For (Model, Folder), "a size of an older listing is dropped");
      for Attempt in Files_Suite.Support.Polling loop
         Files.Operations.Poll_Folder_Sizes (Model);
         exit when Files.Model.Folder_Size_Cached_For (Model, Folder);
      end loop;
      Assert (Files.Model.Folder_Size_Cached_For (Model, Folder), "the folder is measured again");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Folder_Size_Value (Model, Folder).Total_Bytes, 3, "as it is now");

      --  One for the listing in view is taken as it is.
      Measured.Clear;
      Measured.Append
        (Files.Folder_Size.Measurement'
           (Path => To_Unbounded_String (Folder), Result => Stale,
            Listed => Files.Model.Selected_Item (Model).Modified_Time));
      Files.Model.Note_Folder_Sizes (Model, Measured);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Folder_Size_Value (Model, Folder).Total_Bytes, 999, "a size of the listing in view is kept");
      Files.Operations.Cancel_Folder_Scan (Model);
   exception
      when others =>
         Files.Folder_Size.Cancel (Scan);
         Files.Operations.Cancel_Folder_Scan (Model);
         raise;
   end Test_Stale_Folder_Size_Dropped;
