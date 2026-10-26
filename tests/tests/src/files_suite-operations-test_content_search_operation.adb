with Files.Commands.Status;
separate (Files_Suite.Operations)
   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Search_Root : constant String := Join (Root, "content-search");
      Nested      : constant String := Join (Search_Root, "nested");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Routed   : Files.Controller.Controller_Result;
      Big      : String (1 .. 70_000) := [others => 'a'];
   begin
      --  Pure match seam: case-insensitive substring, binary and empty handled.
      Assert (Files.Operations.Content_Matches ("The Needle is here", "needle"),
              "content match is case-insensitive");
      Assert (not Files.Operations.Content_Matches ("nothing relevant", "needle"),
              "content match misses when the query is absent");
      Assert (not Files.Operations.Content_Matches ("needle", ""),
              "an empty query never matches");
      Assert (not Files.Operations.Content_Matches ("", "needle"),
              "empty bytes never match");
      Assert
        (not Files.Operations.Content_Matches ("nee" & Character'Val (0) & "dle needle", "needle"),
         "binary bytes (NUL) are skipped even when the query text is present");

      Reset_Root;
      Ada.Directories.Create_Path (Search_Root);
      Ada.Directories.Create_Path (Nested);
      Write_File (Join (Search_Root, "top-match.txt"), "alpha NEEDLE omega");
      Write_File (Join (Nested, "deep-match.txt"), "hidden needle inside");
      Write_File (Join (Search_Root, "plain.txt"), "nothing to see here");
      Write_Binary_File
        (Join (Search_Root, "binary.dat"), "needle" & Character'Val (0) & "needle");
      Big (Big'Last - 5 .. Big'Last) := "needle";

      Load := Files.File_System.Load_Directory (Search_Root, Settings);
      Files.Model.Initialize (Model, Search_Root, Load.Items, Root);

      --  Default scope is Filter_Here and the command is disabled without a query.
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "a freshly loaded directory defaults to the Filter_Here scope");
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Search_Contents_Command, Model),
         "content search is disabled without filter text");

      Files.Model.Set_Filter (Model, "needle");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Search_Contents_Command, Model),
         "content search is enabled once the filter has text");

      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Search_Contents_Command,
         "content search routes through the command registry");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "content search command succeeds");
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Contents,
         "running content search sets the Search_Contents scope");
      Assert (Files.Model.Search_Results_Are_Active (Model), "content search shows search results");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         2,
         "content search returns only the two textual files whose contents match, "
         & "skipping binary and non-matching files");

      Files_Suite.Support.Assert_Equal

        (Files.Model.Visible_Count (Model),

         2,

         "content-search matches stay visible even when the filenames do not match the query");

      --  Search_Recursive_Command uses the Names scope on the same query.
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Names,
         "recursive name search sets the Search_Names scope");

      --  Clearing the filter returns to Filter_Here and drops search-results state.
      Files_Suite.Support.Run_Command (Files.Commands.Clear_Filter_Command, Model);
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "clearing the filter returns to the Filter_Here scope");
      Assert
        (not Files.Model.Search_Results_Are_Active (Model),
         "clearing the filter drops the search-results state");

      --  A byte cap cannot silently omit a match beyond the preview window.
      Write_File (Join (Search_Root, "oversize.txt"), Big);
      Files.Model.Set_Filter (Model, "needle");
      Routed := Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Failed
              and then Files.Model.Last_Error_Key (Model) = "error.search.failed",
              "content search reports an incomplete oversized file instead of silently skipping it");

      --  An empty query performs no search.
      Files.Model.Set_Filter (Model, "");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Contents_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Disabled,
         "an empty query performs no content search");
   end Test_Content_Search_Operation;
