with Files.Settings.Path_References;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Tree)
   procedure Test_Favorite_Selector_Star_And_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model      : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result     : Files.Interaction.Interaction_Result;
      Fav_Folder : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "fav-folder");
      Fav_File   : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "fav-file.txt");
      Found      : Boolean;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Fav_Folder);
      Files_Suite.Support.Disk.Write_File (Fav_File);
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Fav_Folder);
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Fav_File);

      Open_Favorites_Selector (Model, Settings);
      Assert (Files.Model.Root_Selector.Is_Open (Model), "the selector opens for the favorites test");

      --  The star-prefixed base names are what the selector renders for
      --  favorites (semantic label assertion, not pixels).
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         function Star (Name : String) return String is (Files.Localization.Text ("root.favorite", "name", Name));
         Saw_Folder : Boolean := False;
         Saw_File   : Boolean := False;
      begin
         for Row of Snapshot.Roots loop
            if Ada.Strings.Unbounded.To_String (Row.Label) = Star ("fav-folder") then
               Saw_Folder := True;
            elsif Ada.Strings.Unbounded.To_String (Row.Label) = Star ("fav-file.txt") then
               Saw_File := True;
            end if;
         end loop;
         Assert (Saw_Folder, "the folder favorite renders as a star-prefixed base name");
         Assert (Saw_File, "the file favorite renders as a star-prefixed base name");
      end;

      --  Clicking the folder favorite navigates into it.
      Click_Root_Row (Model, Settings, Fav_Folder, Found, Result);
      Assert (Found, "the folder favorite row is laid out");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Fav_Folder,
         "a folder favorite navigates into the folder");
      Assert (not Files.Model.Root_Selector.Is_Open (Model), "a folder favorite click closes the selector");

      --  Clicking the file favorite opens its parent with the file selected.
      Open_Favorites_Selector (Model, Settings);
      Click_Root_Row (Model, Settings, Fav_File, Found, Result);
      Assert (Found, "the file favorite row is laid out");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Files_Suite.Support.Disk.Root,
         "a file favorite navigates to the file's parent directory");
      declare
         Selected  : constant Files.Items.Item_Vectors.Vector :=
           Files.Model.Selection.Selected_Items (Model);
         Saw_File  : Boolean := False;
      begin
         for Item of Selected loop
            if Ada.Strings.Unbounded.To_String (Item.Name) = "fav-file.txt" then
               Saw_File := True;
            end if;
         end loop;
         Assert (Saw_File, "a file favorite selects the file in its parent directory");
      end;
   end Test_Favorite_Selector_Star_And_Clicks;
