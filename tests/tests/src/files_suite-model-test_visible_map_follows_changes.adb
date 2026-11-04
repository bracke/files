with Ada.Characters.Handling;
with Ada.Strings.Fixed;
separate (Files_Suite.Model)
   --  The visible rows are cached; every change that hides, shows or moves a
   --  row must drop the cache. Each step compares the model's rows with a
   --  count worked out here from its items and the filter.
   procedure Test_Visible_Map_Follows_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model  : Files.Model.Window_Model;

      function Items_Of (Names : String) return Files.Items.Item_Vectors.Vector is
         Result : Files.Items.Item_Vectors.Vector;
         First  : Positive := Names'First;
      begin
         for Index in Names'Range loop
            if Names (Index) = ' ' or else Index = Names'Last then
               Result.Append
                 (Files.File_System.Make_Item
                    (Files_Suite.Support.Root,
                     Names (First .. (if Names (Index) = ' ' then Index - 1 else Index)),
                     Files.Types.Regular_File_Item, "text/plain"));
               First := Index + 1;
            end if;
         end loop;
         return Result;
      end Items_Of;

      --  Both ways: each row names the item it should, and each item's
      --  path finds its row (0 when the filter hides it). A search's results
      --  are all shown, whatever the filter says.
      procedure Check (Step : String) is
         Expected : Natural := 0;
         Filter   : constant String := Files.Model.Filter_Text (Model);
      begin
         for Index in 1 .. Files.Model.Item_Count (Model) loop
            declare
               Item : constant Files.Items.Directory_Item := Files.Model.Testing.Item_At (Model, Index);
               Name : constant String := To_String (Item.Name);
            begin
               if Filter'Length = 0
                 or else Files.Model.Search_Results_Are_Active (Model)
                 or else Ada.Strings.Fixed.Index
                   (Ada.Characters.Handling.To_Lower (Name), Ada.Characters.Handling.To_Lower (Filter)) > 0
               then
                  Expected := Expected + 1;
                  Files_Suite.Support.Assert_Equal
                    (To_String (Files.Model.Visible_Item (Model, Expected).Name), Name,
                     Step & ": visible row" & Expected'Image);
                  Files_Suite.Support.Assert_Equal
                    (Files.Model.Visible_Index_Of (Model, To_String (Item.Full_Path)), Expected,
                     Step & ": the row of " & Name);
               else
                  Files_Suite.Support.Assert_Equal
                    (Files.Model.Visible_Index_Of (Model, To_String (Item.Full_Path)), 0,
                     Step & ": no row for hidden " & Name);
               end if;
            end;
         end loop;
         Files_Suite.Support.Assert_Equal (Files.Model.Visible_Count (Model), Expected, Step & ": visible count");
      end Check;

      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Mixed    : Files.Items.Item_Vectors.Vector := Items_Of ("zeta theta iota");
   begin
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items_Of ("delta Alpha beta gamma"), Files_Suite.Support.Root);
      Check ("initial");
      Files.Model.Set_Filter (Model, "a");
      Check ("filter a");
      Files.Model.Set_Filter (Model, "ta");
      Check ("filter ta");
      Files.Model.Replace_Items (Model, Items_Of ("zeta theta iota alpha"));
      Check ("a new listing under the filter");
      Files.Model.Select_Sort_Field (Model, Files.Types.Sort_Name);
      Check ("sorted");
      Files.Model.Clear_Filter (Model);
      Check ("filter cleared");

      --  A search shows its results whatever the filter; ending it filters again.
      Files.Model.Set_Filter (Model, "et");
      Check ("filter et");
      Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
      Check ("search results under the filter");
      Files.Model.Clear_Search_Results (Model);
      Check ("search ended");

      --  Grouping reorders the items under the filter.
      Mixed.Append
        (Files.File_System.Make_Item
           (Files_Suite.Support.Root, "atlas-et", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Replace_Items (Model, Mixed);
      Check ("a refresh with a folder under the filter");
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Settings.Group_By := Files.Types.Group_By_Type;
      Files.Model.Sync_Grouping (Model, Settings);
      Check ("grouped by type");
      Settings.Group_By := Files.Types.No_Grouping;
      Files.Model.Sync_Grouping (Model, Settings);
      Check ("ungrouped");

      --  Navigation brings a new listing.
      Files.Model.Navigate_To (Model, Files_Suite.Support.Root, Items_Of ("one two three"));
      Check ("navigated");
   end Test_Visible_Map_Follows_Changes;
