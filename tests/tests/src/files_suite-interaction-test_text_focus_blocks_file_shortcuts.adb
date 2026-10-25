separate (Files_Suite.Interaction)
   procedure Test_Text_Focus_Blocks_File_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "text-focus-shortcuts");
      Victim   : constant String := Files_Suite.Support.Join (Dir, "keep.txt");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Victim);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "other.txt"));
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Files_Suite.Support.Root);

      for Field in 1 .. 2 loop
         Files_Suite.Support.Select_Name (Model, "keep.txt");
         if Field = 1 then
            Files.Model.Focus_Filter_Input (Model);
         else
            Files.Model.Focus_Path_Input (Model);
         end if;
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Delete, Shift, Base_Font, Result);
         Assert (Ada.Directories.Exists (Victim),
                 "Shift+Delete in a focused text field does not delete the selection");
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_A, Ctrl, Base_Font, Result);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Count (Model),
            1,
            "Ctrl+A in a focused text field does not select every file");
         Files.Model.Cancel_Focus_Or_Edit (Model);
      end loop;

      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_A, Ctrl, Base_Font, Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "with the grid focused the same shortcut still works");

      --  A settings-writing shortcut (Ctrl+B) is applied, not reported and dropped.
      Files_Suite.Support.Select_Name (Model, "keep.txt");
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_B, Ctrl, Base_Font, Result);
      Assert (Files.Settings.Is_Favorite (Settings, Ada.Directories.Full_Name (Victim)),
              "Ctrl+B favourites the selection through the keyboard path");
      Assert (Result.Settings_Changed and then Result.Clear_Pending_Text,
              "a settings shortcut reports the change and drops its character event");

      --  The controller applies the shortcut itself when given the settings.
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key (Model, Settings, "", Guikit.Input.Key_B, Ctrl);
      begin
         Assert (Outcome.Command = Files.Commands.Toggle_Favorite_Command
                 and then not Files.Settings.Is_Favorite (Settings, Ada.Directories.Full_Name (Victim)),
                 "the settings-aware controller applies Ctrl+B once");
      end;

      --  Enter on a settings command in the palette applies it too.
      declare
         Hidden_Before : constant Boolean := Settings.Show_Hidden_Files;
      begin
         Files.Model.Open_Command_Palette (Model);
         Files.Model.Focus_Command_Palette_Input (Model);
         declare
            Typed : constant Files.Controller.Controller_Result :=
              Files.Controller.Append_Focused_Text (Model, "hidden");
            pragma Unreferenced (Typed);
         begin
            null;
         end;
         Files_Suite.Support.Assert_Equal
           (Files.Model.Palette_Selected_Id (Model),
            Files.Commands.Command_Id'Pos (Files.Commands.Toggle_Hidden_Files_Command),
            "the palette query selects the hidden-files command");
         --  Toggle_Hidden_Files saves before it applies, so it needs a real file.
         Files.Interaction.Handle_Key
           (Model, Settings, Files_Suite.Support.Join (Files_Suite.Support.Root, "palette-settings.conf"),
            Guikit.Input.Key_Return, Guikit.Input.No_Modifiers, Base_Font, Result);
         Assert (Settings.Show_Hidden_Files /= Hidden_Before,
                 "Enter in the palette applies a settings command");
         Assert (not Files.Model.Command_Palette_Is_Open (Model), "the applied command closes the palette");
      end;
   end Test_Text_Focus_Blocks_File_Shortcuts;
