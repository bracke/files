separate (Files_Suite.Operations)
   procedure Test_Recursive_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Search   : Files.File_System.Recursive_Search_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "search"));
      Ada.Directories.Create_Path (Join (Join (Root, "search"), "nested"));
      Write_File (Join (Join (Root, "search"), "alpha-match.txt"), "alpha");
      Write_File (Join (Join (Join (Root, "search"), "nested"), "beta-match.txt"), "beta");
      Write_File (Join (Join (Root, "search"), "skip.txt"), "skip");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "MATCH", Settings);
      Assert (Search.Success, "recursive search succeeds");
      Files_Suite.Support.Assert_Equal (Natural (Search.Items.Length), 2, "recursive search finds nested matches");
      Files_Suite.Support.Assert_Equal
        (To_String (Search.Items.Element (1).Name),
         "alpha-match.txt",
         "recursive search preserves deterministic parent order");
      Files_Suite.Support.Assert_Equal
        (To_String (Search.Items.Element (2).Name),
         "beta-match.txt",
         "recursive search descends into child directories");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "match", Settings, Max_Items => 1);
      Files_Suite.Support.Assert_Equal (Natural (Search.Items.Length), 1, "recursive search respects result limits");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is disabled without filter text");
      Files.Model.Set_Filter (Model, "match");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is enabled with filter text");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Search_Recursive_Command,
         "recursive search routes through command registry");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "recursive search command succeeds");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         2,
         "recursive search command loads nested result items");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Visible_Item (Model, 2).Name),
         "beta-match.txt",
         "recursive search command exposes nested matches in the model");
      Routed := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "refresh restores direct listing");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         3,
         "refresh after recursive search reloads direct children");
   end Test_Recursive_Search;
