with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
separate (Files_Suite.Settings)
   --  On a host whose volumes fold names (Windows), a folder typed in
   --  another case than it was starred or labelled under is the same folder:
   --  its star shows, starring it again unstars it rather than adding a
   --  second favorite, its label shows, Recent keeps it once, and moving or
   --  forgetting it reaches every spelling. Where names do not fold, two
   --  spellings stay two paths.
   procedure Test_Paths_Match_As_The_Host_Folds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Refs renames Files.Settings.Path_References;
      use type Files.Types.Color_Label;
      Stored  : constant String := "/Users/Me/Documents";
      Typed   : constant String := "/users/me/DOCUMENTS";
      File    : constant String := "/Users/Me/Documents/Report.txt";
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Changed : Boolean;
   begin
      Refs.Testing.Simulate_Folding_Host (True);
      Refs.Add_Favorite (Settings, Stored);
      Refs.Set_Label (Settings, File, Files.Types.Red);
      Assert (Refs.Is_Favorite (Settings, Typed), "the star shows for the folder however it is typed");
      Assert (Refs.Is_Favorite (Refs.Index_Paths (Settings), Typed), "and through the index");
      Assert (Refs.Label_Of (Settings, "/users/me/documents/report.TXT") = Files.Types.Red,
              "the label shows for the file however it is typed");
      Assert (Refs.Label_Of (Refs.Index_Paths (Settings), "/users/me/documents/report.TXT") = Files.Types.Red,
              "and through the index");

      Refs.Add_Favorite (Settings, Typed);
      Assert (Natural (Refs.Favorite_Paths (Settings).Length) = 1, "adding the other spelling adds no second favorite");
      Refs.Note_Recent (Settings, Stored);
      Refs.Note_Recent (Settings, Typed);
      Assert (Natural (Refs.Recent_Paths (Settings).Length) = 1, "Recent keeps the folder once");
      Refs.Set_Label (Settings, "/USERS/me/documents/report.txt", Files.Types.Blue);
      Assert (Natural (Refs.Path_Labels (Settings).Length) = 1
              and then Refs.Label_Of (Settings, File) = Files.Types.Blue,
              "relabelling under another spelling changes the one label");

      Refs.Toggle_Favorite_Path (Settings, Typed);
      Assert (not Refs.Is_Favorite (Settings, Stored), "starring it again in another spelling unstars it");

      Refs.Toggle_Favorite_Path (Settings, Stored);
      Refs.Move_Path_References (Settings, "/users/me/documents", "/Users/Me/Archive", Changed);
      Assert (Changed and then Refs.Label_Of (Settings, "/Users/Me/Archive/Report.txt") = Files.Types.Blue,
              "a move named in another spelling takes the label along");
      Refs.Forget_Path_References (Settings, "/users/ME/archive", Changed);
      Assert (Changed and then Refs.Path_Labels (Settings).Is_Empty and then Refs.Favorite_Paths (Settings).Is_Empty
              and then Refs.Recent_Paths (Settings).Is_Empty,
              "forgetting it in another spelling drops its label, star and Recent entry");

      --  Where names do not fold, two spellings are two paths. Linux only:
      --  Windows folds every path, and macOS asks the volume, whose default
      --  APFS folds too.
      Refs.Testing.Simulate_Folding_Host (False);
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Refs.Add_Favorite (Settings, Stored);
         Assert (not Refs.Is_Favorite (Settings, Typed), "a host that tells case apart keeps the spellings apart");
      end if;
   exception
      when others =>
         Refs.Testing.Simulate_Folding_Host (False);
         raise;
   end Test_Paths_Match_As_The_Host_Folds;
