with Files_Suite.Listings;
with Files.Operation_Results;
with Files.File_System.Trash;
with Files.Commands.Status;
with Files_Suite.Support.Guards;
with Ada.Calendar.Formatting;
with Hostkit.Metadata;
separate (Files_Suite.Trash)
   procedure Test_Empty_Trash_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Source_A     : constant String := Join (Root, "empty-a.txt");
      Source_B     : constant String := Join (Root, "empty-b.txt");
      --  Restores what the test changes, on failure too.
      Environment  : Files_Suite.Support.Guards.Environment_Guard;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Enablement: an ordinary directory never offers Empty Trash.
      Write_File (Source_A, "aaa");
      Write_File (Source_B, "bbb");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Assert (Load.Success, "empty-trash setup loads the ordinary directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is disabled in an ordinary directory");

      --  Trash two files so both a payload and its .trashinfo sidecar exist.
      declare
         Trash_A : constant Files.File_System.Mutation_Result := Files.File_System.Trash.Move_To_Trash (Source_A);
         Trash_B : constant Files.File_System.Mutation_Result := Files.File_System.Trash.Move_To_Trash (Source_B);
      begin
         Assert (Trash_A.Success, "empty-trash setup trashes both files: a");
         Assert (Trash_B.Success, "empty-trash setup trashes both files: b");
      end;
      Assert (Ada.Directories.Exists (Join (Trash_File, "empty-a.txt")), "payload a is trashed");
      Assert (Ada.Directories.Exists (Join (Trash_Info, "empty-a.txt.trashinfo")), "sidecar a is written");
      Assert (Ada.Directories.Exists (Join (Trash_File, "empty-b.txt")), "payload b is trashed");
      Assert (Ada.Directories.Exists (Join (Trash_Info, "empty-b.txt.trashinfo")), "sidecar b is written");

      --  Enablement: the non-empty trash view offers Empty Trash.
      Load := Files_Suite.Listings.Load_Directory (Files.File_System.Trash.Trash_Files_Directory, Settings);
      Assert (Load.Success, "empty-trash setup loads the trash view");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Files.Operations.Settle_Current_Is_Trash (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "the trash view lists both trashed items");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is enabled in the non-empty trash view");

      --  Emptying purges every payload and sidecar and reloads an empty view.
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "empty trash reports success");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         0,
         "the trash view reloads empty after empty trash");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "empty-a.txt")), "payload a is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_Info, "empty-a.txt.trashinfo")), "sidecar a is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "empty-b.txt")), "payload b is purged");
      Assert (not Ada.Directories.Exists (Join (Trash_Info, "empty-b.txt.trashinfo")), "sidecar b is purged");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
         "empty trash is disabled once the trash view is empty");

      --  An info file describing nothing (a crash between writing it and
      --  moving the item in) goes with Empty Trash once it is old enough
      --  not to be a trash in progress; a fresh one stays.
      declare
         Unix_Now : constant Long_Long_Integer :=
           Long_Long_Integer
             (Ada.Calendar."-" (Ada.Calendar.Clock, Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0)));
         Old_Orphan   : constant String := Join (Trash_Info, "gone.txt.trashinfo");
         Fresh_Orphan : constant String := Join (Trash_Info, "moving.txt.trashinfo");
      begin
         Write_File (Old_Orphan, "[Trash Info]");
         Write_File (Fresh_Orphan, "[Trash Info]");
         Assert (Hostkit.Metadata.Set_File_Times (Old_Orphan, Unix_Now - 3600, Unix_Now - 3600),
                 "the old orphan is dated an hour back");
         Write_File (Source_A, "aaa");
         Assert (Files.File_System.Trash.Move_To_Trash (Source_A).Success, "an item is trashed beside them");
         Load := Files_Suite.Listings.Load_Directory (Files.File_System.Trash.Trash_Files_Directory, Settings);
         Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
         Files.Operations.Settle_Current_Is_Trash (Model);
         Result :=
           Files.Controller.Execute_Non_Settings_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
         Assert (not Ada.Directories.Exists (Old_Orphan), "an old info file describing nothing is removed");
         Assert (Ada.Directories.Exists (Fresh_Orphan), "a fresh one, maybe a trash in progress, stays");
      end;

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Empty_Trash_Operation;
