separate (Files_Suite.Model)
   --  Build_Snapshot looks favorites and labels up in a hashed index of the
   --  settings rather than scanning both lists per item. It must answer as
   --  Files.Settings.Is_Favorite and Label_Of do -- exact path equality, no
   --  case folding or separator trimming, and the first of repeated labels.
   procedure Test_Snapshot_Labels_And_Favorites_At_Scale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Count    : constant := 400;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Favorites : Natural := 0;
      Labelled  : Natural := 0;

      function Name_Of (Index : Positive) return String is
        ("item_" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left) & ".txt");

      function Color_For (Index : Positive) return Files.Types.Color_Label is
        (if Index mod 2 = 0 then Files.Types.Red else Files.Types.Blue);
   begin
      for Index in 1 .. Count loop
         Items.Append
           (Files.File_System.Make_Item (Root, Name_Of (Index), Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Directory_Path => Root, Items => Items, Home_Path => "/home/test");

      for Index in 1 .. Count loop
         if Index mod 3 = 0 then
            Files.Settings.Toggle_Favorite_Path (Settings, Join (Root, Name_Of (Index)));
         end if;
         if Index mod 5 = 0 then
            Files.Settings.Set_Label (Settings, Join (Root, Name_Of (Index)), Color_For (Index));
         end if;
      end loop;
      --  Paths that only resemble an item's: another case, a trailing
      --  separator. Neither names item 1 or 2 for the settings.
      Files.Settings.Toggle_Favorite_Path (Settings, Join (Root, "ITEM_1.TXT"));
      Files.Settings.Set_Label (Settings, Join (Root, Name_Of (2)) & "/", Files.Types.Green);
      --  A repeated entry, as a hand-edited settings file can hold: the first
      --  one is the label.
      Settings.Labels.Append
        (Files.Settings.Path_Label'
           (Path => To_Unbounded_String (Join (Root, Name_Of (5))), Label => Files.Types.Green));

      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal (Natural (Snapshot.Items.Length), Count, "every item is in the snapshot");
         for Item of Snapshot.Items loop
            declare
               Name : constant String := To_String (Item.Name);
               Path : constant String := Join (Root, Name);
            begin
               Files_Suite.Support.Assert_Equal
                 (Item.Is_Favorite,
                  Files.Settings.Is_Favorite (Settings, Path),
                  Name & " is a favorite exactly when the settings say so");
               Assert (Item.Label = Files.Settings.Label_Of (Settings, Path),
                       Name & " carries exactly the label the settings store for it");
               if Item.Is_Favorite then
                  Favorites := Favorites + 1;
               end if;
               if Item.Label /= Files.Types.No_Label then
                  Labelled := Labelled + 1;
               end if;
               if Name = Name_Of (1) then
                  Assert (not Item.Is_Favorite, "a favorite stored in another case does not mark the item");
               elsif Name = Name_Of (2) then
                  Assert (Item.Label = Files.Types.No_Label,
                          "a label stored with a trailing separator does not mark the item");
               elsif Name = Name_Of (5) then
                  Assert (Item.Label = Color_For (5), "the first of two stored labels for a path wins");
               end if;
            end;
         end loop;
         Files_Suite.Support.Assert_Equal (Favorites, Count / 3, "every stored favorite is marked, and no other item");
         Files_Suite.Support.Assert_Equal (Labelled, Count / 5, "every stored label is shown, and no other");
      end;
   end Test_Snapshot_Labels_And_Favorites_At_Scale;
