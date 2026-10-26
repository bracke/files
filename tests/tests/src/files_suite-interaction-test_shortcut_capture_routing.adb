with Files.Overlays;
separate (Files_Suite.Interaction)
   --  With a settings Shortcut row armed, the key seam routes the next physical
   --  chord to capture (rebinding the live keymap) rather than acting on it, and
   --  Escape cancels, Backspace unbinds, and Delete resets to the built-in
   --  default -- exercising Files.Controller.Capture_Settings_Shortcut end to end.
   procedure Test_Shortcut_Capture_Routing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the overrides this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      use type Guikit.Input.Key_Code;
      use type Files.Commands.Shortcut;
      Path : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "capture.conf");
      Cmd  : constant Files.Commands.Command_Id := Files.Commands.Select_Small_Icons_Command;

      --  Open the pane, jump to the last (Shortcuts) section, and arm its first
      --  row (Select_Small_Icons). Leaves the model capturing.
      procedure Open_And_Arm
        (Model    : in out Files.Model.Window_Model;
         Settings : in out Files.Settings.Settings_Model)
      is
         Result : Files.Interaction.Interaction_Result;
         Rects  : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text   : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes  : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Guikit.Input.Key_Comma, Modifiers => Ctrl,
            Current_Font_Size => Base_Font, Result => Result);
         Files.Overlays.Build_Settings_Frame
           (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
            Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
            Rectangles => Rects, Text => Text, Accessibility => Nodes);
         Files.Model.Settings_Set_Active_Section (Model, Natural'Last);
         Files.Model.Settings_Begin_Capture (Model);
      end Open_And_Arm;

      procedure Press
        (Model    : in out Files.Model.Window_Model;
         Settings : in out Files.Settings.Settings_Model;
         Key      : Guikit.Input.Key_Code;
         Mods     : Guikit.Input.Modifier_Set)
      is
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Key, Modifiers => Mods, Current_Font_Size => Base_Font, Result => Result);
      end Press;
   begin
      Files_Suite.Support.Reset_Root;

      --  (1) A chord captured while armed rebinds the live keymap.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Assert (Files.Model.Settings_Is_Capturing (Model), "the first shortcut row is armed");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Capturing_Key (Model),
            "shortcut.view.small",
            "the armed row is the first command's shortcut field");
         Press (Model, Settings, Guikit.Input.Key_5, Ctrl_Shift);
         Assert (not Files.Model.Settings_Is_Capturing (Model), "capturing a chord disarms the row");
         declare
            SC : constant Files.Commands.Shortcut := Files.Commands.Shortcut_For (Cmd);
         begin
            Assert (SC.Present, "the captured chord rebinds the command in the live keymap (present)");
            Files_Suite.Support.Assert_Equal
              (SC.Key, Guikit.Input.Key_5,
               "the captured chord rebinds the command in the live keymap (key)");
            Assert
              (SC.Modifiers (Guikit.Input.Control_Key),
               "the captured chord rebinds the command in the live keymap (Control)");
            Assert
              (SC.Modifiers (Guikit.Input.Shift_Key),
               "the captured chord rebinds the command in the live keymap (Shift)");
         end;
      end;

      --  (2) Escape cancels capture and leaves the binding untouched.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Escape, Guikit.Input.No_Modifiers);
         Assert (not Files.Model.Settings_Is_Capturing (Model), "Escape disarms the row");
         Assert (Files.Commands.Shortcut_For (Cmd) = Files.Commands.Default_Shortcut_For (Cmd),
                 "Escape leaves the binding at its default");
      end;

      --  (3) Backspace unbinds the command.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Backspace, Guikit.Input.No_Modifiers);
         Assert (not Files.Commands.Shortcut_For (Cmd).Present,
                 "Backspace unbinds the command");
      end;

      --  (4) Delete resets a rebound command to its built-in default.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Is_Set   : Boolean;
      begin
         Files.Commands.Reset_Shortcut_Overrides;
         Files.Commands.Set_Shortcut_Override
           (Cmd, Files.Commands.Parse_Shortcut ("control+shift+5"));
         Open_And_Arm (Model, Settings);
         Press (Model, Settings, Guikit.Input.Key_Delete, Guikit.Input.No_Modifiers);
         declare
            Ignore : constant Files.Commands.Shortcut := Files.Commands.Shortcut_Override (Cmd, Is_Set);
         begin
            pragma Unreferenced (Ignore);
            Assert (not Is_Set, "Delete clears the override, resetting to the built-in default");
         end;
         Assert (Files.Commands.Shortcut_For (Cmd) = Files.Commands.Default_Shortcut_For (Cmd),
                 "the command resolves to its default binding after a reset");
      end;
   end Test_Shortcut_Capture_Routing;
