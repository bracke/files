separate (Files_Suite.Interaction)
   procedure Test_Bottom_Bar_Sort_Persists (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Sort_Field;
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "sort-persist.conf");

      function Items return Files.File_System.Item_Vectors.Vector is
         V : Files.File_System.Item_Vectors.Vector;
      begin
         V.Append (Files.File_System.Make_Item
                     (Files_Suite.Support.Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
         V.Append (Files.File_System.Make_Item
                     (Files_Suite.Support.Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
         return V;
      end Items;

      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Dispatch (Command : Files.Commands.Command_Id) is
         Action : constant Files.Events.Input_Action :=
           (Kind => Files.Events.Command_Input_Action, Command => Command, Activate => True, others => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
      end Dispatch;
   begin
      Files_Suite.Support.Reset_Root;
      Files.Model.Initialize
        (Model,
         Directory_Path => Files_Suite.Support.Root,
         Items          => Items,
         Home_Path      => "/home/test");

      --  Default sort is by name, ascending. Selecting size from the bottom bar
      --  must apply live and persist the field to the settings file.
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Name,
         "the model starts sorted by name");
      Dispatch (Files.Commands.Sort_By_Size_Command);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Size,
         "the sort command applies live");
      Files_Suite.Support.Assert_Equal
        (Settings.Sort_Field_Value,
         Files.Types.Sort_Size,
         "the sort field is written to settings");
      Assert (Result.Settings_Changed, "the sort command reports a settings change");
      Assert (Ada.Directories.Exists (Path), "the sort command persists the settings file");

      --  Re-selecting the same field flips direction; that flip must persist too --
      --  the reported bug was that the bottom-bar direction change was not saved.
      Assert (Files.Model.Sort_Is_Ascending (Model), "selecting a new field sorts ascending");
      Dispatch (Files.Commands.Sort_By_Size_Command);
      Assert (not Files.Model.Sort_Is_Ascending (Model), "re-selecting the field flips to descending");
      Assert (not Settings.Sort_Ascending, "the flipped direction is written to settings");

      --  The direction survives a round-trip through the on-disk settings file.
      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Load_File (Path);
      begin
         Assert (Reloaded.Success, "the persisted settings file reloads cleanly");
         Files_Suite.Support.Assert_Equal
           (Reloaded.Settings.Sort_Field_Value,
            Files.Types.Sort_Size,
            "the reloaded settings keep the chosen sort field");
         Assert (not Reloaded.Settings.Sort_Ascending,
                 "the reloaded settings keep the descending direction");
      end;
   end Test_Bottom_Bar_Sort_Persists;
