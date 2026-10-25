separate (Files_Suite.Interaction)
   procedure Test_Text_Input_Click_Focuses (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Toolbar  : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Window_W);
      Center_Y : constant Natural :=
        Guikit.Layout.Toolbar_Input_Y (Line) + Guikit.Layout.Toolbar_Input_Height (Line) / 2;
      Left_X   : constant Natural := Toolbar.Middle_X + Guikit.Layout.Input_Field_Padding;
      Right_X  : constant Natural := Toolbar.Middle_X + Toolbar.Middle_Width - 1;
   begin
      Files.Model.Set_Path_Input_Text (Model, "abcdef");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Left_X, Center_Y, Window_W, Window_H, Line_Height => Line);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Text_Click_Input_Action,
            "the path-input region translates to a text click");
         Files_Suite.Support.Assert_Equal
           (Action.Focus_Target,
            Files.Types.Focus_Path_Input,
            "the text click targets the path input");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      Files_Suite.Support.Assert_Equal

        (Files.Model.Focus (Model),

         Files.Types.Focus_Path_Input,

         "applying the text click moves focus to the path input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         0,
         "clicking the field's left edge places the cursor at the start of the text");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Right_X, Center_Y, Window_W, Window_H, Line_Height => Line);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;

      --  Focusing the path input loads the current directory path for editing,
      --  so the exact end offset is path-dependent; asserting the cursor moved
      --  off the start proves the click set a concrete cursor position.
      Assert
        (Files.Model.Text_Cursor_Position (Model) > 0,
         "clicking deeper into the field advances the cursor into the path text");
   end Test_Text_Input_Click_Focuses;
