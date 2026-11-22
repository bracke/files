with Files.Item_Lists;
with Files.Preference_Types;
with Files.Settings.Path_References;
with Hostkit.Fs;
with Hostkit.Host;
separate (Files_Suite.Model)
   --  Build_Snapshot looks favorites and labels up in a hashed index of the
   --  settings rather than scanning both lists per item. It must answer as
   --  Files.Settings.Path_References.Is_Favorite and Label_Of do -- exact path equality
   --  where the volume tells case apart, no separator trimming, and the first of
   --  repeated labels.
   procedure Test_Snapshot_Labels_And_Favorites_At_Scale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Preference_Types.Color_Label;
      Count    : constant := 400;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Favorites : Natural := 0;
      Labelled  : Natural := 0;
      --  Whether favorites match Root's names without regard to case, as
      --  Path_References decides it.
      Folds_Case : constant Boolean :=
        Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows)
        or else (Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.MacOS)
                 and then Hostkit.Fs.Folds_Name_Case (Root));

      function Name_Of (Index : Positive) return String is
        ("item_" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left) & ".txt");

      function Color_For (Index : Positive) return Files.Preference_Types.Color_Label is
        (if Index mod 2 = 0 then Files.Preference_Types.Red else Files.Preference_Types.Blue);
   begin
      for Index in 1 .. Count loop
         Items.Append
           (Files.Item_Lists.Make_Item (Root, Name_Of (Index), Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Directory_Path => Root, Items => Items, Home_Path => "/home/test");

      for Index in 1 .. Count loop
         if Index mod 3 = 0 then
            Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Join (Root, Name_Of (Index)));
         end if;
         if Index mod 5 = 0 then
            Files.Settings.Path_References.Set_Label (Settings, Join (Root, Name_Of (Index)), Color_For (Index));
         end if;
      end loop;
      --  Paths that only resemble an item's: another case, a trailing
      --  separator. Neither names item 1 or 2 for the settings.
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Join (Root, "ITEM_1.TXT"));
      Files.Settings.Path_References.Set_Label (Settings, Join (Root, Name_Of (2)) & "/", Files.Preference_Types.Green);

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
                  Files.Settings.Path_References.Is_Favorite (Settings, Path),
                  Name & " is a favorite exactly when the settings say so");
               Assert (Item.Label = Files.Settings.Path_References.Label_Of (Settings, Path),
                       Name & " carries exactly the label the settings store for it");
               if Item.Is_Favorite then
                  Favorites := Favorites + 1;
               end if;
               if Item.Label /= Files.Preference_Types.No_Label then
                  Labelled := Labelled + 1;
               end if;
               if Name = Name_Of (1) then
                  --  Another case is another name only where the volume tells
                  --  case apart; where it folds case (Windows, most macOS
                  --  volumes) it is the same entry, and the favorite marks it.
                  Assert (Item.Is_Favorite = Folds_Case,
                          "a favorite stored in another case marks the item exactly where names fold case");
               elsif Name = Name_Of (2) then
                  Assert (Item.Label = Files.Preference_Types.No_Label,
                          "a label stored with a trailing separator does not mark the item");
               end if;
            end;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Favorites, Count / 3 + (if Folds_Case then 1 else 0),
            "every stored favorite is marked, and no other item");
         Files_Suite.Support.Assert_Equal (Labelled, Count / 5, "every stored label is shown, and no other");
      end;
   end Test_Snapshot_Labels_And_Favorites_At_Scale;
