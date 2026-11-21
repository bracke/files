with Files.Model.Jobs;
with Files.Operation_Results;
with Files.Window_Polls;
with Ada.Strings.Maps;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Info)
   --  The watch poll's background read neither restarts a folder measurement
   --  nor, when it finds nothing new, forces a new revision: in a large folder
   --  that read comes round every few seconds, and a slow folder measured
   --  from scratch each time never finished.
   procedure Test_Folder_Size_Survives_Background_Read (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      pragma Unreferenced (Step);
      Folder   : constant String := Join (Root, "folder");
      Marker   : constant String := Join (Root, "size-started");
      Revision : Natural;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TEST_STALL_FOLDER_SIZES");
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_Binary_File (Join (Folder, "data"), "one");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));

      Revision := Files.Model.Revision (Model);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Revision (Model), Revision, "an unchanged signature is no new revision");

      Select_Name (Model, "folder");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Files.Window_Polls.Update_Folder_Size (Model);
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (Marker);
      end loop;
      Assert (Ada.Directories.Exists (Marker), "the measurement is under way");
      --  The helper's job directory: a restart would end this helper and
      --  remove it. The marker goes, so a new helper's would show.
      declare
         --  The hook writes it with Text_IO, which ends the line.
         Started : constant String :=
           Ada.Strings.Fixed.Trim
             (Project_Tools.Files.Read_Raw_File (Marker),
              Ada.Strings.Maps.Null_Set, Ada.Strings.Maps.To_Set (ASCII.LF & ASCII.CR));
      begin
         Ada.Directories.Delete_File (Marker);

         Write_Binary_File (Join (Root, "beta"), "beta");
         Step := Files.Operations.Refresh_If_Changed (Model, Settings);
         Assert (Files.Process_Jobs.Active (Files.Model.Jobs.Background_Refresh (Model)), "a background read runs");
         for Frame in 1 .. 5 loop
            Files.Window_Polls.Update_Folder_Size (Model);
            Files.Window_Polls.Poll_Folder_Sizes (Model);
         end loop;
         Assert (Files.Model.Testing.Folder_Scan_Is_Active (Model),
                 "the background read leaves the measurement running");

         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when Files.Refresh_Jobs.Advance (Model, Settings)
              or else not Files.Process_Jobs.Active (Files.Model.Jobs.Background_Refresh (Model));
         end loop;
         Files.Window_Polls.Update_Folder_Size (Model);
         Assert (Files.Model.Testing.Folder_Scan_Is_Active (Model),
                 "and so does taking the selection up again after it");
         Assert (Ada.Directories.Exists (Started) and then not Ada.Directories.Exists (Marker),
                 "the measurement running is the first one, not a restart: " & Started);
      end;
      Files.Window_Polls.Cancel_Folder_Scan (Model);
   exception
      when others =>
         Files.Window_Polls.Cancel_Folder_Scan (Model);
         raise;
   end Test_Folder_Size_Survives_Background_Read;
