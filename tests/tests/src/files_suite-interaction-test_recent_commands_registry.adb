separate (Files_Suite.Interaction)
   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "reg-recent-dir");
      Empty    : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "reg-empty-dir");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Navigate_Recent_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Empty);

      --  Both commands are registered and palette-visible.
      Assert (Files.Commands.Contains ("navigate.recent"), "Navigate Recent is a registered command");
      Assert (Files.Commands.Contains ("recent.clear"), "Clear Recent is a registered command");
      Assert (Files.Commands.Command_Palette_Visible (Files.Commands.Navigate_Recent_Command),
              "Navigate Recent appears in the command palette");
      Assert (Files.Commands.Command_Palette_Visible (Files.Commands.Clear_Recent_Command),
              "Clear Recent appears in the command palette");

      --  Seed a recent path, then enter the recent view through the real reducer.
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (Dir));
      Items.Append
        (Files.File_System.Make_Item
           (Files_Suite.Support.Root, "reg-recent-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);

      --  Outside the recent view: Navigate Recent is enabled, Clear Recent is not.
      Assert (Files.Commands.Is_Enabled (Files.Commands.Navigate_Recent_Command, Model),
              "Navigate Recent is enabled in an ordinary view");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Clear_Recent_Command, Model),
              "Clear Recent is disabled outside the recent view");

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
      Assert (Files.Model.In_Recent_View (Model), "the reducer enters the recent view");
      Assert (Files.Model.Item_Count (Model) > 0, "the recent view lists the stored path");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Clear_Recent_Command, Model),
              "Clear Recent is enabled in a non-empty recent view");

      --  The empty-area context menu offers Clear Recent (alongside Empty Trash).
      declare
         Menu_Model : Files.Model.Window_Model := Loaded_Model (Empty);
         Menu_Result : Files.Interaction.Interaction_Result;
      begin
         Open_Empty_Context_Menu (Menu_Model, Settings, Menu_Result);
         Assert (Menu_Offers (Menu_Model, Settings, Files.Commands.Clear_Recent_Command),
                 "the empty-area menu lists Clear Recent");
      end;

      --  Missing recent paths are intentionally omitted from the listing, but
      --  they still need a usable Clear Recent command so stale persisted state
      --  is not trapped behind an empty view.
      Files.Settings.Clear_Recent (Settings);
      Files.Settings.Note_Recent
        (Settings, Files_Suite.Support.Join (Files_Suite.Support.Root, "missing-recent"));
      declare
         Rebuilt : constant Files.Operations.Operation_Result :=
           Files.Operations.Navigate_Recent (Model, Settings);
         Clear_Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Clear_Recent_Command,
            others  => <>);
         pragma Unreferenced (Rebuilt);
      begin
         Assert
           (Files.Model.Item_Count (Model) = 0
            and then Files.Commands.Is_Enabled
              (Files.Commands.Clear_Recent_Command, Model),
            "Clear Recent remains enabled when every persisted path is stale");
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Action            => Clear_Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
         Assert
           (Files.Settings.Recent_Paths (Settings).Is_Empty
            and then Result.Settings_Changed,
            "Clear Recent removes stale persisted paths from an empty virtual view");
      end;
   end Test_Recent_Commands_Registry;
