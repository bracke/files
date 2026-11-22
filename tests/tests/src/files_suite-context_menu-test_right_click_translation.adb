with Files.Item_Lists;
with Files.Rendering.Layouts.Menus;
with Files.Preference_Types;
with Files.Input_Actions;
with Files.Model.Context_Menu;
with Files.Rendering.Layouts;
with Files_Suite.Support.Disk;
with Files.Text_Basics;

separate (Files_Suite.Context_Menu)
   --  Files.Events translates a right click as the window delivers it: what
   --  lies under the pointer in the snapshot on screen, then applied through
   --  Interaction as any other click.
   procedure Test_Right_Click_Translation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Input_Actions.Input_Action_Kind;
      use type Files.Input_Actions.Right_Click_Target;
      use type Files.Model.Context_Menu_Target;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;

      function Right_Click (X, Y : Natural) return Files.Input_Actions.Input_Action is
        (Files.Events.Translate_Right_Click
           (Files.Rendering.Build_Snapshot (Model, Settings), X, Y, Window_W, Window_H, Line));

      procedure Apply (Action : Files.Input_Actions.Input_Action) is
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
      end Apply;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      for Index in 1 .. 6 loop
         Items.Append
           (Files.Item_Lists.Make_Item
              (Files_Suite.Support.Disk.Root, "item-" & Files.Text_Basics.Natural_Text (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Disk.Root, Items, Files_Suite.Support.Disk.Root,
         Default_View_Mode => Files.Preference_Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Layouts.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Layouts.Item_Layout_Vectors.Vector :=
           Files.Rendering.Layouts.Calculate_Item_Layout (Snapshot, Layout, Line);
         Second   : Files.Rendering.Layouts.Item_Layout;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 2 then
               Second := Cell;
            end if;
         end loop;

         declare
            Item_X : constant Natural := Second.Name_X + Second.Name_Width / 2;
            Item_Y : constant Natural := Second.Y + Second.Height / 2;
            On_Item : constant Files.Input_Actions.Input_Action := Right_Click (Item_X, Item_Y);
            On_Header : constant Files.Input_Actions.Input_Action :=
              Right_Click (Item_X, (Layout.Main_Y + Rows.First_Element.Y) / 2);
            Below_Rows : constant Files.Input_Actions.Input_Action :=
              Right_Click (Item_X, Layout.Main_Y + Layout.Main_Height - 2);
            On_Toolbar : constant Files.Input_Actions.Input_Action := Right_Click (1, 1);
         begin
            Assert
              (On_Item.Kind = Files.Input_Actions.Right_Click_Input_Action, "a right click on an item is translated");
            Assert (On_Item.Clicked_On = Files.Input_Actions.On_Main_View and then On_Item.Target_Item = 2,
                    "it names the item drawn under the pointer");
            Assert (On_Item.Clicked_On /= Files.Input_Actions.On_Details_Header, "and not the header");
            Assert (On_Item.Menu_X = Item_X and then On_Item.Menu_Y = Item_Y, "the menu opens where it was clicked");
            Assert (On_Header.Clicked_On = Files.Input_Actions.On_Details_Header, "the details header is told apart");
            Assert (Below_Rows.Clicked_On = Files.Input_Actions.On_Main_View and then Below_Rows.Target_Item = 0,
                    "empty view space names no item");
            Assert (On_Toolbar.Kind = Files.Input_Actions.Right_Click_Input_Action
                    and then On_Toolbar.Clicked_On = Files.Input_Actions.Elsewhere
                    and then On_Toolbar.Target_Item = 0,
                    "the toolbar is not the view");
            Assert (Right_Click (Window_W, Item_Y).Kind = Files.Input_Actions.No_Input_Action,
                    "the window's right edge names no pixel");
            Assert (Right_Click (Item_X, Window_H).Kind = Files.Input_Actions.No_Input_Action,
                    "nor does its bottom edge");

            Apply (On_Item);
            Assert (Files.Model.Context_Menu.Is_Open (Model), "applied, the item's menu opens");
            Assert (Files.Model.Context_Menu.Target_Of (Model) = Files.UI_Types.Context_Menu_Item,
                    "for the item");
            Assert (Files.Model.Selection.Is_Selected (Model, 2), "and the item right-clicked is selected");

            declare
               Menu_Snapshot : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot (Model, Settings);
               Menu : constant Files.Rendering.Layouts.Menus.Context_Menu_Layout :=
                 Files.Rendering.Layouts.Menus.Calculate_Context_Menu_Layout (Menu_Snapshot, Window_W, Window_H, Line);
               On_Menu : constant Files.Input_Actions.Input_Action :=
                 Right_Click (Menu.X + Menu.Width / 2, Menu.Y + Menu.Height / 2);
            begin
               Assert (Menu.Visible, "the menu is laid out");
               Assert (On_Menu.Clicked_On = Files.Input_Actions.On_Context_Menu and then On_Menu.Target_Item = 0,
                       "a right click on the open menu is on the menu, not the item beneath it");
               Apply (On_Menu);
               Assert (Files.Model.Context_Menu.Is_Open (Model)
                       and then Files.Model.Context_Menu.Target_Of (Model) = Files.UI_Types.Context_Menu_Item,
                       "and leaves the menu as it is");
            end;
         end;
      end;
   end Test_Right_Click_Translation;
