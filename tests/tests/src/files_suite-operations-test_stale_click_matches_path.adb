separate (Files_Suite.Operations)
   --  A click on a frame older than the listing finds the drawn item by its
   --  path: the same name in another folder is not it.
   procedure Test_Stale_Click_Matches_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir_A    : constant String := Join (Root, "stale-a");
      Dir_B    : constant String := Join (Root, "stale-b");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Clicked  : Natural := 0;

      function Listing (Path : String) return Files.File_System.Item_Vectors.Vector is
        (Files.File_System.Load_Directory (Path, Settings).Items);

      function Index_Of (Name : String) return Natural is
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            if To_String (Files.Model.Visible_Item (Model, Index).Name) = Name then
               return Index;
            end if;
         end loop;
         return 0;
      end Index_Of;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir_A);
      Ada.Directories.Create_Path (Dir_B);
      Write_File (Join (Dir_A, "b.txt"), "b");
      Write_File (Join (Dir_A, "c.txt"), "c");
      Write_File (Join (Dir_B, "c.txt"), "other c");
      Files.Model.Initialize (Model, Dir_A, Listing (Dir_A), Root);
      declare
         Drawn : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         for Item of Drawn.Items loop
            if To_String (Item.Name) = "c.txt" then
               Clicked := Item.Visible_Index;
            end if;
         end loop;
         Assert (Clicked > 0, "c.txt is drawn");

         Files.Model.Navigate_To (Model, Dir_B, Listing (Dir_B));
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Item_Now (Drawn, Clicked, Model), 0,
            "c.txt in another folder is not the item clicked");

         Write_File (Join (Dir_A, "a.txt"), "a");
         Files.Model.Navigate_To (Model, Dir_A, Listing (Dir_A));
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Item_Now (Drawn, Clicked, Model), Index_Of ("c.txt"),
            "the item clicked is found where it is now");
         Assert (Index_Of ("c.txt") /= Clicked, "(it moved)");
      end;
      Reset_Root;
   end Test_Stale_Click_Matches_Path;
