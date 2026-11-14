with Files.Folder_Size;
separate (Files_Suite.Interaction)
   --  A settings change in one window reached another by reloading its
   --  folder, which replaced the search results that window showed with the
   --  folder's listing, and measured its folder sizes again from scratch.
   --  The results now take the new settings in place -- hidden items go, a
   --  new order applies -- and a reload for shared settings keeps the sizes
   --  measured; only a refresh the user asks for measures them again.
   procedure Test_Shared_Settings_Keep_Search_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files_Suite.Support;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shared   : Files.Settings.Settings_Model;
      Folder   : constant String := Join (Root, "folder");

      function Name_At (Index : Positive) return String is
        (Ada.Strings.Unbounded.To_String (Files.Model.Visible_Item (Model, Index).Name));

      procedure Load is
         Load_Result : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Directory_Path => Root, Items => Load_Result.Items, Home_Path => "/home/test");
      end Load;
   begin
      Reset_Root;
      Write_File (Join (Root, "Alpha.txt"));
      Write_File (Join (Root, "Beta.txt"));
      Write_File (Join (Root, ".hidden_two"));
      Settings.Show_Hidden_Files := True;
      Load;
      Assert_Equal (Files.Model.Visible_Count (Model), 3, "the results hold the hidden item too");
      Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
      Select_Name (Model, "Beta.txt");
      --  On disk only: a reload would list it, the results do not.
      Write_File (Join (Root, "Gamma.txt"));

      --  Another window hides hidden files.
      Shared := Settings;
      Shared.Show_Hidden_Files := False;
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Search_Results_Are_Active (Model), "the window still shows its search results");
      Assert_Equal (Files.Model.Visible_Count (Model), 2, "the hidden result goes, and nothing is read again");
      Assert (Name_At (1) = "Alpha.txt" and then Name_At (2) = "Beta.txt", "the results keep their order");
      Assert (Ada.Strings.Unbounded.To_String (Files.Model.Selection.Selected_Item (Model).Name) = "Beta.txt",
              "the selection stays");

      --  And then sorts the other way.
      Shared := Settings;
      Shared.Sort_Ascending := not Settings.Sort_Ascending;
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Search_Results_Are_Active (Model), "the results stay through a new order");
      Assert_Equal (Files.Model.Visible_Count (Model), 2, "with the same items");
      Assert (Name_At (1) = "Beta.txt" and then Name_At (2) = "Alpha.txt", "the new order applies to them");

      --  A folder listing reloaded for shared settings keeps its folder sizes.
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_File (Join (Root, ".hidden_two"));
      Settings := Files.Settings.Default_Settings;
      Load;
      Select_Name (Model, "folder");
      declare
         Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      begin
         Measured.Append
           (Files.Folder_Size.Measurement'
              (Path   => Ada.Strings.Unbounded.To_Unbounded_String (Folder),
               Result => (Available => True, Total_Bytes => 7, File_Count => 1, Item_Count => 1, Capped => False),
               others => <>));
         Files.Model.Folder_Sizes.Note_Folder_Sizes (Model, Measured);
      end;
      Assert (Files.Model.Folder_Sizes.Folder_Size_Cached_For (Model, Folder), "the folder's size is measured");
      Shared := Settings;
      Shared.Show_Hidden_Files := True;
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert_Equal (Files.Model.Visible_Count (Model), 2, "the listing is read again with hidden files");
      Assert (Files.Model.Folder_Sizes.Folder_Size_Cached_For (Model, Folder), "and the size measured is kept");
      Reset_Root;
   end Test_Shared_Settings_Keep_Search_Results;
