with Files.Command_Palette;
with Files.Overlays;
separate (Files_Suite.Interaction)
   --  A click on the settings panel or on a palette row reaches the controller
   --  through Apply_Input_Action, and a palette row whose command changes
   --  settings runs through the settings path (it is applied and saved).
   procedure Test_Overlay_Clicks_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "clicks.conf");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text     : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons    : Guikit.Draw.Icon_Command_Vectors.Vector;
      Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Found    : Boolean := False;

      procedure Click (Kind : Files.Events.Input_Action_Kind; X, Y : Natural) is
         Action : constant Files.Events.Input_Action :=
           (case Kind is
               when Files.Events.Settings_Click_Input_Action =>
                 (Kind => Files.Events.Settings_Click_Input_Action, Click_X => X, Click_Y => Y),
               when others =>
                 (Kind => Files.Events.Command_Result_Click_Input_Action, Click_X => X, Click_Y => Y));
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end Click;
   begin
      Files_Suite.Support.Reset_Root;

      --  The settings panel: some control on it takes the click.
      Files.Interaction.Handle_Key
        (Model => Model, Settings => Settings, Settings_Path => Path,
         Key => Guikit.Input.Key_Comma, Modifiers => Ctrl,
         Current_Font_Size => Base_Font, Result => Result);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "Ctrl+, opens the settings panel");
      Files.Overlays.Build_Settings_Frame
        (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
         Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
         Rectangles => Rects, Text => Text, Accessibility => Nodes);
      for Node of Nodes loop
         if Node.Role = Guikit.Draw.Role_Button and then Node.Enabled and then Node.Width > 0 then
            Click (Files.Events.Settings_Click_Input_Action, Node.X + Node.Width / 2, Node.Y + Node.Height / 2);
            if Result.Status /= Files.Controller.Controller_Ignored then
               Found := True;
               exit;
            end if;
         end if;
      end loop;
      Assert (Found, "a click on a settings control is dispatched to the panel");
      Files.Model.Toggle_Settings_Pane (Model);

      --  The palette: a row whose command changes a setting.
      Files.Model.Open_Command_Palette (Model);
      declare
         Typed : constant Files.Controller.Controller_Result := Files.Controller.Append_Focused_Text (Model, "hidden");
         pragma Unreferenced (Typed);
         Hidden_Before : constant Boolean := Settings.Show_Hidden_Files;
         Row_X, Row_Y  : Natural := 0;
      begin
         Rects.Clear;
         Text.Clear;
         Nodes.Clear;
         Files.Overlays.Build_Palette_Frame
           (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
            Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
            Rectangles => Rects, Text => Text, Icons => Icons, Accessibility => Nodes);
         Found := False;
         for Node of Nodes loop
            if Node.Role = Guikit.Draw.Role_List_Item and then Node.Width > 0 then
               declare
                  Hit : constant Boolean :=
                    Files.Model.Palette_Click (Model, Node.X + Node.Width / 2, Node.Y + Node.Height / 2);
               begin
                  if Hit and then Files.Command_Palette.Selected_Command (Model)
                                  = Files.Commands.Toggle_Hidden_Files_Command
                  then
                     Row_X := Node.X + Node.Width / 2;
                     Row_Y := Node.Y + Node.Height / 2;
                     Found := True;
                     exit;
                  end if;
               end;
            end if;
         end loop;
         Assert (Found, "the palette lists the hidden-files toggle for ""hidden""");
         Click (Files.Events.Command_Result_Click_Input_Action, Row_X, Row_Y);
         Assert (Settings.Show_Hidden_Files /= Hidden_Before, "the clicked row's setting is applied");
         Assert (not Files.Model.Command_Palette_Is_Open (Model), "and the palette closes");
         Assert (Ada.Directories.Exists (Path), "and the change is saved to the settings file");
      end;
   end Test_Overlay_Clicks_Dispatch;
