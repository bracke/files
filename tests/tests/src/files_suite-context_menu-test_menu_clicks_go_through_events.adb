with Files.Rendering.Layouts.Menus;
with Files.Input_Actions;
with Files.Model.Clipboard;
with Guikit.Draw;
with Files.Model.Context_Menu;
with Files.Rendering.Layouts;
with Files.Application.Window_Policy;
with Files_Suite.Support.Models;
separate (Files_Suite.Context_Menu)
   --  A press on the open context menu is translated by Files.Events like any
   --  other click: a row runs its command, a separator is swallowed, a click
   --  outside closes the menu. So a screen reader's Activate on a menu row --
   --  a click on its node's centre -- runs that row's command.
   procedure Test_Menu_Clicks_Go_Through_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Input_Actions.Input_Action_Kind;
      use type Guikit.Draw.Accessibility_Role;
      use type Files.Commands.Context_Menu_Row_Kind;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Open_Menu is
         X, Y  : Natural;
         Found : Boolean;
      begin
         Item_Center (Model, 2, X, Y, Found);
         Assert (Found, "a layout cell exists for the menu-anchor item");
         Dispatch_Right_Click (Model, Settings, Files.Input_Actions.On_Main_View, 2, X, Y, Result);
         Assert (Files.Model.Context_Menu.Is_Open (Model), "the context menu opens");
      end Open_Menu;

      function Click (X, Y : Natural) return Files.Input_Actions.Input_Action is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         return
           Files.Events.Translate_Click
             (Snapshot => Snapshot,
              Frame    => Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line),
              X        => X, Y => Y, Width => Window_W, Height => Window_H, Line_Height => Line);
      end Click;

      Copy_Action : Files.Input_Actions.Input_Action;
      Buttons     : Natural := 0;
   begin
      Open_Menu;
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Menu     : constant Files.Rendering.Layouts.Menus.Context_Menu_Layout :=
           Files.Rendering.Layouts.Menus.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
      begin
         --  Every row a screen reader is offered resolves, at its node's
         --  centre, to that row's command.
         for Node of Frame.Accessibility loop
            if Node.Role = Guikit.Draw.Role_Button and then Node.Enabled then
               declare
                  Action : constant Files.Input_Actions.Input_Action :=
                    Files.Application.Window_Policy.Accessibility_Action
                      (Click (Node.X + Node.Width / 2, Node.Y + Node.Height / 2), Activate => True);
               begin
                  Assert
                    (Action.Kind = Files.Input_Actions.Context_Menu_Command_Input_Action,
                     Ada.Strings.Unbounded.To_String (Node.Name) & " is a menu row to a click on its centre");
                  Buttons := Buttons + 1;
                  if Action.Menu_Command = Files.Commands.Copy_Selected_Items_Command then
                     Copy_Action := Action;
                  end if;
               end;
            end if;
         end loop;
         Assert (Buttons >= 2, "the menu's rows are offered as buttons:" & Buttons'Image);
         Assert
           (Copy_Action.Kind = Files.Input_Actions.Context_Menu_Command_Input_Action,
            "the item menu offers Copy to a screen reader");
         --  A separator is part of the menu, not a choice: swallowed.
         for Row in 1 .. Menu.Row_Count loop
            if Menu.Rows (Row).Kind = Files.Commands.Menu_Separator then
               Assert
                 (Click (Menu.X + Menu.Width / 2,
                         Files.Rendering.Layouts.Menus.Context_Menu_Row_Top (Menu, Row)).Kind
                  = Files.Input_Actions.No_Input_Action,
                  "a click on a separator is swallowed");
               exit;
            end if;
         end loop;
      end;

      --  Activating the row runs its command and closes the menu.
      Files.Interaction.Apply_Input_Action (Model, Settings, "", Copy_Action, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Context_Menu.Is_Open (Model), "the row's activation closes the menu");
      Assert
        (Files.Model.Clipboard.Mode_Of (Model) = Files.Model.Clipboard_Copy,
         "and runs the row's command: the selection is copied");

      --  A click beside the menu closes it, and runs nothing behind it.
      Open_Menu;
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Menu     : constant Files.Rendering.Layouts.Menus.Context_Menu_Layout :=
           Files.Rendering.Layouts.Menus.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
         Outside  : constant Natural :=
           (if Menu.X >= 10 then Menu.X - 5 else Menu.X + Menu.Width + 5);
         Action   : constant Files.Input_Actions.Input_Action := Click (Outside, Menu.Y + Menu.Height / 2);
      begin
         Assert
           (Action.Kind = Files.Input_Actions.Command_Input_Action
            and then Action.Command = Files.Commands.Close_Overlay_Command,
            "a click beside the open menu closes it");
         Files.Interaction.Apply_Input_Action (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
         Assert (not Files.Model.Context_Menu.Is_Open (Model), "and the menu is closed");
      end;
   end Test_Menu_Clicks_Go_Through_Events;
