with Files.Overlays;
separate (Files_Suite.Interaction)
   --  Ctrl+Tab / Ctrl+Shift+Tab move between the settings section tabs through the
   --  key seam -- the only keyboard route across sections -- and wrap at the ends.
   procedure Test_Settings_Tab_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "tabs.conf");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text     : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Hit_X    : Natural := 0;
      Hit_Y    : Natural := 0;
      Found_Hit : Boolean := False;
      Revision_Before : Natural;

      procedure Tab (Mods : Guikit.Input.Modifier_Set) is
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Guikit.Input.Key_Tab, Modifiers => Mods,
            Current_Font_Size => Base_Font, Result => Result);
      end Tab;
   begin
      Files_Suite.Support.Reset_Root;

      --  Open the pane and lay it out so the sections exist.
      Files.Interaction.Handle_Key
        (Model => Model, Settings => Settings, Settings_Path => Path,
         Key => Guikit.Input.Key_Comma, Modifiers => Ctrl,
         Current_Font_Size => Base_Font, Result => Result);
      Revision_Before := Files.Model.Revision (Model);
      Files.Overlays.Build_Settings_Frame
        (Model => Model, Region_X => 0, Region_Y => 0, Region_Width => 600, Region_Height => 500,
         Clip_Width => 600, Clip_Height => 500, Line_Height => 20, Focused => True,
         Rectangles => Rects, Text => Text, Accessibility => Nodes);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Revision (Model),
         Revision_Before,
         "building a settings frame does not manufacture a semantic model revision");

      --  Resolve a genuine settings control from the component's accessibility
      --  output and prove a newer top-most overlay owns that same click.
      for Node of Nodes loop
         if Node.Role = Guikit.Draw.Role_Button
           and then Node.Enabled
           and then Node.Width > 0
           and then Node.Height > 0
         then
            Hit_X := Node.X + Node.Width / 2;
            Hit_Y := Node.Y + Node.Height / 2;
            declare
               Outcome : constant Files.Controller.Controller_Result :=
                 Files.Controller.Handle_Settings_Click
                   (Model, Integer (Hit_X), Integer (Hit_Y));
            begin
               if Outcome.Status /= Files.Controller.Controller_Ignored then
                  Found_Hit := True;
                  exit;
               end if;
            end;
         end if;
      end loop;
      Assert (Found_Hit, "the live settings component exposes a clickable button");

      Files.Model.Open_Label_Picker (Model);
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
         Outcome  : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Settings_Click
             (Model, Integer (Hit_X), Integer (Hit_Y));
      begin
         Assert
           (Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Revision (Model) = Revision,
            "a delayed settings click is contained by the label picker");
      end;
      Files.Model.Close_Label_Picker (Model);

      declare
         Revision : constant Natural := Files.Model.Revision (Model);
         Clicked  : constant Boolean := Files.Model.Settings_Click (Model, -1, -1);
      begin
         Assert
           (not Clicked and then Files.Model.Revision (Model) = Revision,
            "a settings-panel miss does not advance the model revision");
      end;

      declare
         Count : constant Natural := Files.Model.Settings_Section_Count (Model);
      begin
         Assert (Count > 1, "the settings form has multiple section tabs");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Active_Section (Model),
            1,
            "the first section is active initially");

         Tab (Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Active_Section (Model),
            2,
            "Ctrl+Tab advances to the next section");

         Tab (Ctrl_Shift);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Active_Section (Model),
            1,
            "Ctrl+Shift+Tab returns to the previous section");

         --  Wrap backward from the first section to the last.
         Tab (Ctrl_Shift);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Active_Section (Model),
            Count,
            "Ctrl+Shift+Tab wraps from the first section to the last");

         --  Wrap forward from the last section back to the first.
         Tab (Ctrl);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Active_Section (Model),
            1,
            "Ctrl+Tab wraps from the last section to the first");
      end;

      --  Plain Tab / Shift+Tab walk the fields like Down / Up.
      declare
         First : constant String := Files.Model.Settings_Focused_Key (Model);
      begin
         Tab (Guikit.Input.No_Modifiers);
         Assert (Files.Model.Settings_Focused_Key (Model) /= First, "Tab moves focus to the next field");
         Tab (Shift);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Focused_Key (Model),
            First,
            "Shift+Tab moves focus back");
      end;

      --  Space flips a focused toggle and drops its own character.
      for Step in 1 .. 50 loop
         exit when Files.Model.Settings_Focused_Kind (Model) = Guikit.Settings_Panel.Toggle;
         Tab (Guikit.Input.No_Modifiers);
      end loop;
      Assert (Files.Model.Settings_Focused_Kind (Model) = Guikit.Settings_Panel.Toggle,
              "the first section has a toggle to focus");
      declare
         Before : constant String := Files.Model.Settings_Focused_Value (Model);
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => Path,
            Key => Guikit.Input.Key_Space, Modifiers => Guikit.Input.No_Modifiers,
            Current_Font_Size => Base_Font, Result => Result);
         Assert (Files.Model.Settings_Focused_Value (Model) /= Before, "Space flips the focused toggle");
         Assert (Result.Clear_Pending_Text, "the flipping space is not also typed");
      end;
   end Test_Settings_Tab_Keys;
