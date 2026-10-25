separate (Files_Suite.Operations)
   procedure Test_Directory_Change_Watcher (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Before   : Files.File_System.Directory_Signature;
      Change   : Files.File_System.Directory_Change_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      declare
         First_Empty  : constant String := Join (Root, "signature-empty-a");
         Second_Empty : constant String := Join (Root, "signature-empty-b");
      begin
         Ada.Directories.Create_Directory (First_Empty);
         Ada.Directories.Create_Directory (Second_Empty);
         Before := Files.File_System.Directory_State (First_Empty);
         Change := Files.File_System.Detect_Directory_Change
           (Before, Second_Empty);
         Assert
           (Change.Changed
            and then Change.Before_State.Path /= Change.After_State.Path,
            "directory signatures from different empty roots never compare unchanged");
         Ada.Directories.Delete_Directory (First_Empty);
         Ada.Directories.Delete_Directory (Second_Empty);
      end;
      Ada.Directories.Create_Path (Join (Root, "search"));
      Ada.Directories.Create_Path (Join (Join (Root, "search"), "nested"));
      Write_File (Join (Join (Root, "search"), "alpha-match.txt"), "alpha");
      Write_File (Join (Join (Join (Root, "search"), "nested"), "beta-match.txt"), "beta");
      Write_File (Join (Join (Root, "search"), "skip.txt"), "skip");

      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Write_File (Join (Join (Root, "search"), "new-file.txt"), "new");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "polling directory watcher detects added entries");
      Files_Suite.Support.Assert_Equal
        (Change.After_State.Entry_Count,
         Before.Entry_Count + 1,
         "directory watcher reports updated entry count");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Join (Root, "search")));
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "unchanged directory watcher refresh succeeds");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         4,
         "unchanged watcher refresh keeps loaded item count");
      Write_File (Join (Join (Root, "search"), "watched-add.txt"), "watch");
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "changed directory watcher refresh succeeds");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         5,
         "changed watcher refresh reloads new directory items");
      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Ada.Directories.Delete_File (Join (Join (Root, "search"), "skip.txt"));
      Write_File (Join (Join (Root, "search"), "same-count-replacement.txt"), "replacement");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "directory watcher detects same-count replacement");
      Files_Suite.Support.Assert_Equal
        (Change.After_State.Entry_Count,
         Before.Entry_Count,
         "same-count replacement keeps directory entry count stable");
      Assert
        (Change.After_State.Entry_State_Checksum /= Before.Entry_State_Checksum,
         "same-count replacement changes directory entry checksum");
      Files.Model.Set_Directory_Signature (Model, Before);
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "same-count watcher refresh succeeds");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         5,
         "same-count watcher refresh keeps replacement entry count");
   end Test_Directory_Change_Watcher;
