separate (Files_Suite.Interaction)
   procedure Test_Labels_Follow_Moves_And_Stay_Loadable (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Operations.Operation_Status;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "label-moves");
      One      : constant String := Files_Suite.Support.Join (Dir, "one.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "first.txt");
      Sub      : constant String := Files_Suite.Support.Join (Dir, "sub");
      Inner    : constant String := Files_Suite.Support.Join (Sub, "inner.txt");
      Sub_Two  : constant String := Files_Suite.Support.Join (Dir, "sub2");
      Sibling  : constant String := Files_Suite.Support.Join (Files_Suite.Support.Join (Dir, "sub-other"), "x");
      Model    : Files.Model.Window_Model;
      Op       : Files.Operations.Operation_Result;
      Followed : Boolean;

      procedure Rename (Name, New_Name : String) is
      begin
         Files_Suite.Support.Select_Name (Model, Name);
         Files.Model.Toggle_Rename (Model);
         Files.Model.Set_Rename_Text (Model, New_Name);
         Op := Files.Operations.Commit_Rename (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Op.Status,
            Files.Operations.Operation_Success,
            "rename " & Name & " to " & New_Name);
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      end Rename;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Files_Suite.Support.Write_File (One, "a");
      Files_Suite.Support.Write_File (Inner, "b");
      Files.Settings.Set_Label (Settings, One, Files.Types.Green);
      Files.Settings.Set_Label (Settings, Inner, Files.Types.Blue);
      Files.Settings.Set_Label (Settings, Sibling, Files.Types.Red);
      Files.Settings.Toggle_Favorite_Path (Settings, Sub);
      Model := Loaded_Model (Dir);

      Rename ("one.txt", "first.txt");
      Assert (Followed, "a rename of a labeled file changes the settings");
      Assert (Files.Settings.Label_Of (Settings, Renamed) = Files.Types.Green
              and then Files.Settings.Label_Of (Settings, One) = Files.Types.No_Label,
              "the label follows the renamed file and leaves the old path");

      Rename ("sub", "sub2");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Files_Suite.Support.Join (Sub_Two, "inner.txt")),
         Files.Types.Blue,
         "a label inside a renamed folder follows it");
      Assert (Files.Settings.Is_Favorite (Settings, Sub_Two) and then not Files.Settings.Is_Favorite (Settings, Sub),
              "a favorite folder follows its rename");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Sibling),
         Files.Types.Red,
         "a path that only shares the folder's name as a prefix is left alone");

      Op := Files.Operations.Undo_Last (Model, Settings);
      Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      Assert (Files.Settings.Label_Of (Settings, Inner) = Files.Types.Blue
              and then Files.Settings.Is_Favorite (Settings, Sub),
              "Undo of the folder rename brings its label and favorite back");

      --  Near the settings file's entry bound, labeling the selection would
      --  make the file unloadable: the edit is refused whole.
      --  Grow the labels ten at a time to just below the bound: ten more
      --  would not load.
      declare
         Next : Natural := 0;
         Grown : Files.Settings.Settings_Model;
      begin
         loop
            Grown := Settings;
            for Index in Next + 1 .. Next + 10 loop
               Files.Settings.Set_Label (Grown, "/nowhere/" & Index'Image, Files.Types.Gray);
            end loop;
            exit when not Files.Settings.Loadable (Grown) or else Next > 10_000;
            Settings := Grown;
            Next := Next + 10;
         end loop;
         Assert (Next > 0 and then Next <= 10_000, "the settings file has an entry bound");
      end;
      Assert (Files.Settings.Loadable (Settings), "the settings still load just under the bound");
      for Index in 1 .. 20 loop
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "f" & Index'Image), "x");
      end loop;
      Model := Loaded_Model (Dir);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Open_Label_Picker (Model);
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind => Files.Events.Label_Picker_Choice_Input_Action,
          Item_Index => Files.Types.Color_Label'Pos (Files.Types.Purple),
          others => <>),
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Settings.Label_Of (Settings, Files_Suite.Support.Join (Dir, "f" & Integer'(1)'Image))
                = Files.Types.No_Label
              and then Files.Settings.Loadable (Settings),
              "an edit past the bound is refused and the settings stay loadable");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.settings.full",
         "the refusal says why");
   end Test_Labels_Follow_Moves_And_Stay_Loadable;
