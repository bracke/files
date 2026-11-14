with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Model.Root_Selector;
with Files.Model.Selection;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Rendering.Testing;
with Files.Types;
with Guikit.Draw;
with Files_Suite.Support;

package body Files_Suite.Interaction_Support is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Guikit.Draw.Accessibility_Role;

   --  Center of the cell laid out for visible item Index, derived from the real
   --  item layout (rule a). Returns whether the cell was found.
   procedure Item_Center
     (Model  : Files.Model.Window_Model;
      Index  : Positive;
      X      : out Natural;
      Y      : out Natural;
      Found  : out Boolean)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Files.Settings.Default_Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
   begin
      X := 0;
      Y := 0;
      Found := False;
      for Cell of Items loop
         if Cell.Visible_Index = Index then
            X := Cell.X + Cell.Width / 2;
            Y := Cell.Y + Cell.Height / 2;
            Found := True;
            return;
         end if;
      end loop;
   end Item_Center;

   --  Number of grid-item accessibility nodes currently marked Selected. With no
   --  overlay and the info pane closed these are exactly the main-view items, so
   --  this is a theme-proof proxy for the selection state (rules b and e).
   function Selected_Item_Nodes (Model : Files.Model.Window_Model) return Natural is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Files.Settings.Default_Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      Count    : Natural := 0;
   begin
      for Node of Frame.Accessibility loop
         if (Node.Role = Guikit.Draw.Role_List_Item
             or else Node.Role = Guikit.Draw.Role_Table_Row)
           and then Node.Selected
         then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Selected_Item_Nodes;

   --  Apply the input action a click at (X, Y) translates to, exactly as the
   --  shell does (rule d).
   procedure Click
     (Model     : in out Files.Model.Window_Model;
      Settings  : in out Files.Settings.Settings_Model;
      X         : Natural;
      Y         : Natural;
      Modifiers : Guikit.Input.Modifier_Set;
      Result    : out Files.Interaction.Interaction_Result)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X, Y, Window_W, Window_H,
           Activate => False, Modifiers => Modifiers, Line_Height => Line);
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Modifiers         => Modifiers,
         Result            => Result);
   end Click;

   --  Scroll down (negative GLFW offset) at (X, Y) through the real translator.
   procedure Scroll_Down_At
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      X        : Natural;
      Y        : Natural)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Scroll_At
          (Snapshot, X, Y, Target_W, Target_H, Y_Offset => -1, Line_Height => Line);
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
   end Scroll_Down_At;

   --  The targeted-scroll fixture: detail view, Gamma.md selected, info pane open.
   procedure Open_Targeted_Scroll_Fixture (Model : in out Files.Model.Window_Model) is
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Files_Suite.Support.Select_Name (Model, "Gamma.md");
      Files.Model.Toggle_Info_Pane (Model);
   end Open_Targeted_Scroll_Fixture;

   --  Vertical centre of the main view in the compact targeted-scroll window.
   function Targeted_Main_Y
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Natural
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
   begin
      return Layout.Main_Y + Layout.Main_Height / 2;
   end Targeted_Main_Y;

   --  Reproduce the model state Test_Scroll_Targets_Pane_Under_Cursor leaves
   --  behind: the fixture, one wheel step over the info pane and one over the
   --  main view, then the main view returned to its top.
   procedure Replay_Targeted_Scroll
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model) is
   begin
      Open_Targeted_Scroll_Fixture (Model);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
      begin
         Scroll_Down_At (Model, Settings, Info.X + Info.Width / 2, Info.Y + Info.Height / 2);
         Scroll_Down_At
           (Model, Settings, Layout.Main_X + Layout.Main_Width / 2, Layout.Main_Y + Layout.Main_Height / 2);
      end;
      Files.Model.Set_Main_View_Scroll_Lines (Model, 0);
   end Replay_Targeted_Scroll;

   --  Format a positive index without the leading space Integer'Image inserts.
   function Index_Image (Value : Positive) return String is
      Raw : constant String := Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Index_Image;

   --  Load a real on-disk directory into a fresh window model, exactly as the
   --  controller does when navigating, so disk-backed menu commands operate on
   --  genuine items.
   function Loaded_Model (Directory : String) return Files.Model.Window_Model is
      Load  : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory (Directory, Files.Settings.Default_Settings);
      Model : Files.Model.Window_Model;
   begin
      Files.Model.Initialize (Model, Directory, Load.Items, Files_Suite.Support.Root);
      return Model;
   end Loaded_Model;

   --  Position of Name in the displayed order (1-based), or 0 when absent:
   --  Build_Snapshot is the display-order oracle.
   function Display_Position_Of
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Name     : String)
      return Natural
   is
      Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
   begin
      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         if Ada.Strings.Unbounded.To_String (Snapshot.Items.Element (Index).Name) = Name then
            return Index;
         end if;
      end loop;
      return 0;
   end Display_Position_Of;

   --  Return the first visible item index currently reported Selected, or zero.
   function First_Selected_Visible (Model : Files.Model.Window_Model) return Natural is
   begin
      for Index in 1 .. Files.Model.Visible_Count (Model) loop
         if Files.Model.Selection.Is_Selected (Model, Index) then
            return Index;
         end if;
      end loop;
      return 0;
   end First_Selected_Visible;

   --  Open the item context menu by right-clicking the cell of the first
   --  selected item, deriving the coordinate from the real item layout (rule a)
   --  and driving the real Apply_Right_Click (rule d).
   procedure Open_Item_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Visible  : constant Natural := First_Selected_Visible (Model);
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      X, Y     : Natural := 0;
      In_Main  : Boolean;
      Index    : Natural;
   begin
      Assert (Visible > 0, "a selected item exists to anchor the context menu");
      for Cell of Items loop
         if Cell.Visible_Index = Visible then
            X := Cell.X + Cell.Width / 2;
            Y := Cell.Y + Cell.Height / 2;
         end if;
      end loop;
      In_Main :=
        X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
        and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
      Index := Files.Rendering.Hit.Item_At (Items, X, Y);
      Files.Interaction.Apply_Right_Click (Model, Settings, In_Main, Index, X, Y, Result);
   end Open_Item_Context_Menu;

   --  Open the empty-area context menu by right-clicking the center of the main
   --  view, which is item-free in the directories these tests build.
   procedure Open_Empty_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Layout   : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
      Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      X : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
      Y : constant Natural := Layout.Main_Y + Layout.Main_Height / 2;
      Index : constant Natural := Files.Rendering.Hit.Item_At (Items, X, Y);
   begin
      Files.Interaction.Apply_Right_Click (Model, Settings, True, Index, X, Y, Result);
   end Open_Empty_Context_Menu;

   --  Resolve a command from the live context-menu layout (rule a), assert the
   --  derived coordinate hit-tests back to that row, then dispatch it through the
   --  real Apply_Context_Menu_Command (rule d). Found is false when the open menu
   --  does not offer the command.
   procedure Dispatch_Menu_Command
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Command       : Files.Commands.Command_Id;
      Result        : out Files.Interaction.Interaction_Result;
      Found         : out Boolean)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Menu     : constant Files.Rendering.Context_Menu_Layout :=
        Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
      Target_Row   : Natural := 0;
      Row_X, Row_Y : Natural;
   begin
      Found := False;
      for Row in 1 .. Menu.Row_Count loop
         if Menu.Rows (Row).Command = Command then
            Target_Row := Row;
         end if;
      end loop;
      --  No row for it: Found stays False, and the caller's assertion says so.
      if Target_Row = 0 then
         return;
      end if;
      Row_X := Menu.X + Menu.Width / 2;
      Row_Y :=
        Files.Rendering.Testing.Context_Menu_Row_Top (Menu, Target_Row) + Menu.Row_Height / 2;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Hit.Context_Menu_Row_At (Menu, Row_X, Row_Y),
         Target_Row,
         "the derived coordinate hit-tests back to the resolved menu row");
      Found := True;
      Files.Interaction.Apply_Context_Menu_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Settings_Path,
         Command           => Menu.Rows (Target_Row).Command,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
   end Dispatch_Menu_Command;

   --  Whether the currently open context menu lists Command in its real
   --  Calculate_Context_Menu_Layout rows (rule a: contents come from the live
   --  layout, never a hardcoded row index).
   function Menu_Offers
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id)
      return Boolean
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Menu     : constant Files.Rendering.Context_Menu_Layout :=
        Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
   begin
      for Row in 1 .. Menu.Row_Count loop
         if Menu.Rows (Row).Command = Command then
            return True;
         end if;
      end loop;
      return False;
   end Menu_Offers;

   --  Commit the active focused text (rename / create) through the real key seam
   --  the shell uses -- Enter routed via Files.Controller.Handle_Key (rule d),
   --  not a direct Commit_Rename call.
   procedure Commit_Focused_Text
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Handle_Key
          (Model, Settings, Guikit.Input.Key_Return, Guikit.Input.No_Modifiers);
      pragma Unreferenced (Outcome);
   begin
      null;
   end Commit_Focused_Text;

   --  Dispatch Command through the reducer's command branch -- the same entry the
   --  shell uses for menu-bar and shortcut-less commands (e.g. Undo).
   procedure Dispatch_Command
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id;
      Result   : out Files.Interaction.Interaction_Result)
   is
      Action : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Command);
   begin
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
   end Dispatch_Command;

   --  True when Path is present in the persisted favorites list.
   function Has_Favorite
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Boolean is
   begin
      for P of Settings.Favorite_Paths loop
         if Ada.Strings.Unbounded.To_String (P) = Path then
            return True;
         end if;
      end loop;
      return False;
   end Has_Favorite;

   --  Drive the real Select_Drive command through the reducer so the root
   --  selector opens seeded with the platform roots plus the persisted
   --  favorites (each carrying its star label token).
   procedure Open_Favorites_Selector
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      Action : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Select_Drive_Command);
      Result : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
   end Open_Favorites_Selector;

   --  Click the open selector's row whose root path equals Target_Path, deriving
   --  the coordinate from the real root-path layout (rule a). Found reports
   --  whether such a row existed.
   procedure Click_Root_Row
     (Model       : in out Files.Model.Window_Model;
      Settings    : in out Files.Settings.Settings_Model;
      Target_Path : String;
      Found       : out Boolean;
      Result      : out Files.Interaction.Interaction_Result)
   is
      X, Y : Natural := 0;
   begin
      Found := False;

      --  The selector lays out only the rows that fit, scrolling around the
      --  selected one, so a root can exist and still be off screen. That never
      --  happened on the Linux runner, whose root list is short; a Mac mounts
      --  enough volumes to push the favourites out of view. Select the target
      --  first -- which is what scrolls it in -- exactly as a user reaching for
      --  an off-screen row would, and only then lay the frame out and click it.
      for Index in 1 .. Files.Model.Root_Selector.Count (Model) loop
         if Files.Model.Root_Selector.Path (Model, Index) = Target_Path then
            Files.Model.Root_Selector.Set_Selected_Index (Model, Index);
            exit;
         end if;
      end loop;

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Selector : constant Files.Rendering.Root_Selector_Layout :=
           Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line);
         Rows     : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Selector);
      begin
         for Row of Rows loop
            if Files.Model.Root_Selector.Path (Model, Positive (Row.Root_Index)) = Target_Path then
               X := Row.X + Row.Width / 2;
               Y := Row.Y + Row.Height / 2;
               Found := True;
            end if;
         end loop;

         if not Found then
            Result := (others => <>);
            return;
         end if;

         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
         end;
      end;
   end Click_Root_Row;

end Files_Suite.Interaction_Support;
