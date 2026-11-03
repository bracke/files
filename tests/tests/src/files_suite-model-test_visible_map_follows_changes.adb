with Ada.Characters.Handling;
with Ada.Strings.Fixed;
separate (Files_Suite.Model)
   --  The visible rows are cached; every change that hides, shows or moves a
   --  row must drop the cache. Each step compares the model's rows with a
   --  count worked out here from its items and the filter.
   procedure Test_Visible_Map_Follows_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model  : Files.Model.Window_Model;
      Filter : Unbounded_String;

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

      procedure Check (Step : String) is
         Expected : Natural := 0;
      begin
         for Index in 1 .. Files.Model.Item_Count (Model) loop
            declare
               Name : constant String := To_String (Files.Model.Testing.Item_At (Model, Index).Name);
            begin
               if Length (Filter) = 0
                 or else Ada.Strings.Fixed.Index
                   (Ada.Characters.Handling.To_Lower (Name), Ada.Characters.Handling.To_Lower (To_String (Filter))) > 0
               then
                  Expected := Expected + 1;
                  Files_Suite.Support.Assert_Equal
                    (To_String (Files.Model.Visible_Item (Model, Expected).Name), Name,
                     Step & ": visible row" & Expected'Image);
               end if;
            end;
         end loop;
         Files_Suite.Support.Assert_Equal (Files.Model.Visible_Count (Model), Expected, Step & ": visible count");
      end Check;
   begin
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items_Of ("delta Alpha beta gamma"), Files_Suite.Support.Root);
      Check ("initial");
      Filter := To_Unbounded_String ("a");
      Files.Model.Set_Filter (Model, "a");
      Check ("filter a");
      Filter := To_Unbounded_String ("ta");
      Files.Model.Set_Filter (Model, "ta");
      Check ("filter ta");
      Files.Model.Replace_Items (Model, Items_Of ("zeta theta iota alpha"));
      Check ("a new listing under the filter");
      Files.Model.Select_Sort_Field (Model, Files.Types.Sort_Name);
      Check ("sorted");
      Filter := Null_Unbounded_String;
      Files.Model.Clear_Filter (Model);
      Check ("filter cleared");
   end Test_Visible_Map_Follows_Changes;
