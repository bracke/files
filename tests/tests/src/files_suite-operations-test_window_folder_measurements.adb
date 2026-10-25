separate (Files_Suite.Operations)
   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model, Other : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);
      Before : Ada.Calendar.Time;
      Folder : constant String := Join (Root, "folder");
      Marker : constant String := Join (Root, "size-started");
      Started : Unbounded_String;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_FOLDER_SIZES");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "");
      File : Ada.Text_IO.File_Type;
      Empty : Files.Process_Jobs.Session;
      Finished, Cancelled : Boolean;
      procedure Restore is
      begin
         Files.Model.Cancel_Folder_Scan (Model);
         Files.Model.Cancel_Folder_Scan (Other);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
         end if;
      end Restore;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_Binary_File (Join (Folder, "data"), "one");
      Write_Binary_File (Join (Root, "ordinary.txt"), "ordinary");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Initialize (Other, Root, Load.Items, Root);
      Select_Name (Model, "folder");
      Select_Name (Other, "ordinary.txt");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Files.Operations.Update_Folder_Size (Model, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Marker);
      end loop;
      Assert (Ada.Directories.Exists (Marker), "the first window's size helper reaches stalled reads");
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Marker);
      Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (File), "started"));
      Ada.Text_IO.Close (File);
      Before := Ada.Calendar.Clock;
      for Frame in 1 .. 50 loop
         Files.Operations.Update_Folder_Size (Other, Settings);
         Files.Model.Poll_Folder_Sizes (Other);
         Files.Operations.Update_Folder_Size (Model, Settings);
         Files.Model.Poll_Folder_Sizes (Model);
      end loop;
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit and then Files.Model.Folder_Scan_Is_Active (Model)
              and then Ada.Directories.Exists (To_String (Started)),
              "input and cancellation in another window cannot terminate or restart a stalled scan");
      Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
      Select_Name (Other, "folder");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
      end loop;
      Assert (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 3
              and then Files.Model.Folder_Scan_Is_Active (Model),
              "a surviving window measures normally while another window's scan remains stalled");
      Write_Binary_File (Join (Folder, "data"), "longer contents");
      Step := Files.Operations.Refresh (Other, Settings);
      Assert (not Files.Model.Folder_Size_Cached_For (Other, Folder), "a successful refresh discards stale totals");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
      end loop;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes,
         15,
         "refresh remeasures descendant changes even when parent entries were unchanged");
      Files.Model.Cancel_Folder_Scan (Model);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
         exit when not Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Started))
              and then Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes = 15,
              "closing the stalled window terminates only its measurement and preserves the other's cache");
      Files.Model.Set_Background_Transfers (Other, True);
      Step := Files.Operations.Refresh (Other, Settings);
      Files.Operations.Update_Folder_Size (Other, Settings);
      Files.Model.Poll_Folder_Sizes (Other);
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Other))
              and then not Files.Model.Folder_Scan_Is_Active (Other),
              "size results cannot invalidate a pending listing request by changing its captured revision");
      Await_View (Other, Settings);
      Assert (not Files.Model.Folder_Size_Cached_For (Other, Folder),
              "a completed background refresh also invalidates the prior size");
      Files.Operations.Update_Folder_Size (Other, Settings);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Model.Poll_Folder_Sizes (Other);
         exit when not Files.Model.Folder_Scan_Is_Active (Other);
      end loop;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Folder_Size_Value (Other, Folder).Total_Bytes,
         15,
         "measurement resumes normally after the asynchronous listing was applied");
      Restore;
   exception
      when others => Restore; raise;
   end Test_Window_Folder_Measurements;
