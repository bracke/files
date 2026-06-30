with Ada.Directories;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.Interaction;
with Files.Model;
with Files.Rendering;
with Files.Settings;
with Files.Types;

with Files_Suite.Support;

--  Headless coverage for the interaction reducer (Files.Interaction). Each test
--  drives the REAL pipeline the GLFW shell drives -- Sample_Model ->
--  Build_Snapshot -> Build_Frame_Commands -> a layout/hit-test function ->
--  Files.Events.Translate_* -> Files.Interaction.Apply_* -> assert -- so it
--  proves the relocated orchestration behaves as it did inline in
--  application-windows.adb, without any GPU/GLFW dependency.
--
--  Anti-fragility rules (the whole point of this seam):
--
--  a. Derive every coordinate from a layout/hit-test function -- never hardcode
--     a pixel (Item_At, Context_Menu_Row_At, Settings_Hit_At, Calculate_Layout;
--     center = Cell.X + Cell.Width/2, ...).
--  b. Assert semantic outcomes only -- Command_Id identity, Model/Settings
--     fields, menu-open/selection state, Interaction_Result flags; prefer
--     Frame_Commands.Accessibility nodes (Role/Selected/Focused/Enabled) over
--     rectangle/color geometry.
--  c. No framebuffer/pixel-hash, no exact-color, no exact-coordinate assertions
--     (geometry is a hit-test input, never an assertion target).
--  d. Exercise the real dispatch functions (Translate_* ->
--     Files.Interaction.Apply_*); never reimplement dispatch or shortcut to a
--     Controller leaf -- that is what lets tests drift.
--  e. Do not copy Has_Rectangle_Colored (Frame, Selection_Color) (rendering
--     test, color identity); use the accessibility-node boolean instead
--     (theme-proof).
package body Files_Suite.Interaction is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Model.Clipboard_Mode;
   use type Files.Rendering.Accessibility_Role;
   use type Files.Rendering.Settings_Hit_Kind;
   use type Files.Types.View_Mode;

   Window_W   : constant Natural  := 1000;
   Window_H   : constant Natural  := 800;
   Line       : constant Positive := 20;
   Base_Font  : constant Positive := 16;

   Ctrl : constant Files.Types.Modifier_Set :=
     [Files.Types.Control_Key => True, others => False];

   type Interaction_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Interaction_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Interaction_Test_Case);

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Targeted_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Path_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Interaction_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files interaction reducer");
   end Name;

   overriding procedure Register_Tests (T : in out Interaction_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Left_Click_Selects'Access, "left-click selects an item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ctrl_Click_Multi_Selection'Access, "ctrl-click builds and toggles a multi-selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Right_Click_Opens_Menu'Access, "right-click selects and opens the context menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Menu_Row_Dispatch'Access, "context-menu row dispatches its command and closes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Keyboard_Shortcut_Command'Access, "keyboard shortcut routes to its command and model effect");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Targeted_Scroll'Access, "scroll targets the pane under the cursor");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Path_Commands'Access, "settings-path commands flip, persist, and signal the shell");
   end Register_Tests;

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
         if (Node.Role = Files.Rendering.Role_List_Item
             or else Node.Role = Files.Rendering.Role_Table_Row)
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
      Modifiers : Files.Types.Modifier_Set;
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
         Current_Font_Size => Base_Font,
         Modifiers         => Modifiers,
         Result            => Result);
   end Click;

   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
   begin
      Item_Center (Model, 2, X, Y, Found);
      Assert (Found, "a layout cell exists for the target item");
      Click (Model, Settings, X, Y, Files.Types.No_Modifiers, Result);
      Assert (Files.Model.Is_Selected (Model, 2), "the clicked item becomes selected");
      Assert
        (Selected_Item_Nodes (Model) = 1,
         "exactly one item accessibility node reports Selected after a single click");
   end Test_Left_Click_Selects;

   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X1, Y1   : Natural;
      X2, Y2   : Natural;
      Found1   : Boolean;
      Found2   : Boolean;
   begin
      Item_Center (Model, 1, X1, Y1, Found1);
      Item_Center (Model, 3, X2, Y2, Found2);
      Assert (Found1 and then Found2, "layout cells exist for both target items");

      Click (Model, Settings, X1, Y1, Files.Types.No_Modifiers, Result);
      Assert (Selected_Item_Nodes (Model) = 1, "a plain click starts a single-item selection");

      Click (Model, Settings, X2, Y2, Ctrl, Result);
      Assert
        (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 3),
         "ctrl-click adds the second item to the selection");
      Assert (Selected_Item_Nodes (Model) = 2, "two item nodes report Selected after ctrl-click");

      Click (Model, Settings, X1, Y1, Ctrl, Result);
      Assert (not Files.Model.Is_Selected (Model, 1), "ctrl-click toggles the first item back off");
      Assert (Files.Model.Is_Selected (Model, 3), "the other item stays selected");
      Assert (Selected_Item_Nodes (Model) = 1, "the toggled-off item is no longer reported Selected");
   end Test_Ctrl_Click_Multi_Selection;

   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;

      --  Recompute In_Main / Item_Index from the live layout, as the shell does
      --  before calling Apply_Right_Click.
      procedure Right_Click (Target : Positive) is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         In_Main  : Boolean;
         Index    : Natural;
      begin
         Item_Center (Model, Target, X, Y, Found);
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click
           (Model      => Model,
            Settings   => Settings,
            In_Main    => In_Main,
            Item_Index => Index,
            X          => X,
            Y          => Y,
            Result     => Result);
      end Right_Click;
   begin
      Right_Click (2);
      Assert (Found, "a layout cell exists for the right-clicked item");
      Assert (Files.Model.Context_Menu_Is_Open (Model), "right-click opens the context menu");
      Assert (Files.Model.Is_Selected (Model, 2), "right-click selects the unselected item under the cursor");
      Assert (Result.Context_Menu_Changed, "the result reports the context-menu change");

      --  With a modal overlay open the same right-click must be swallowed: the
      --  menu stays closed (the shell suppresses it behind modals).
      Files.Model.Close_Context_Menu (Model);
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings overlay is open for the suppression case");
      Right_Click (2);
      Assert
        (not Files.Model.Context_Menu_Is_Open (Model),
         "right-click behind a modal overlay leaves the context menu closed");
   end Test_Right_Click_Opens_Menu;

   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
      In_Main  : Boolean;
      Index    : Natural;
   begin
      --  Open the item context menu through the real right-click path so the
      --  menu rows come from the live snapshot.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      begin
         Item_Center (Model, 2, X, Y, Found);
         Assert (Found, "a layout cell exists for the menu-anchor item");
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click (Model, Settings, In_Main, Index, X, Y, Result);
      end;
      Assert (Files.Model.Context_Menu_Is_Open (Model), "context menu is open before the row click");

      --  Resolve the Copy row from the real menu layout (rule a) and dispatch it.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Menu     : constant Files.Rendering.Context_Menu_Layout :=
           Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
         Target_Row : Natural := 0;
         Row_X      : Natural;
         Row_Y      : Natural;
      begin
         for Row in 1 .. Menu.Row_Count loop
            if Menu.Commands (Row) = Files.Commands.Copy_Selected_Items_Command then
               Target_Row := Row;
            end if;
         end loop;
         Assert (Target_Row > 0, "the item context menu offers the copy command");

         Row_X := Menu.X + Menu.Width / 2;
         Row_Y := Menu.Y + Menu.Padding + (Target_Row - 1) * Menu.Row_Height + Menu.Row_Height / 2;
         Assert
           (Files.Rendering.Context_Menu_Row_At (Menu, Row_X, Row_Y) = Target_Row,
            "the derived coordinate hit-tests back to the copy row");

         Files.Interaction.Apply_Context_Menu_Command
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Command           => Menu.Commands (Target_Row),
            Current_Font_Size => Base_Font,
            Modifiers         => Files.Types.No_Modifiers,
            Result            => Result);
      end;

      Assert
        (Result.Command = Files.Commands.Copy_Selected_Items_Command,
         "the result echoes the dispatched command id");
      Assert (Result.Context_Menu_Changed, "the result reports the menu closing");
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      Assert
        (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Copy,
         "the copy command records a copy clipboard intent");
      Assert (Files.Model.Clipboard_Has_Items (Model), "the copy command captured the selected item");
   end Test_Menu_Row_Dispatch;

   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      --  Ctrl+3 is the Select_Details shortcut.
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Files.Types.Key_3, Ctrl);
   begin
      Assert
        (Action.Kind = Files.Events.Command_Input_Action,
         "a known shortcut translates to a command input action");
      Assert
        (Action.Command = Files.Commands.Select_Details_Command,
         "Ctrl+3 selects the details-view command");

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Ctrl,
         Result            => Result);

      Assert
        (Result.Command = Files.Commands.Select_Details_Command,
         "the result echoes the dispatched command id");
      Assert
        (Files.Model.View_Mode_Of (Model) = Files.Types.Details,
         "dispatching the shortcut switches the model to the details view");
   end Test_Keyboard_Shortcut_Command;

   procedure Test_Targeted_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      --  Scroll down (negative GLFW offset) at (X, Y) through the real translator.
      procedure Scroll_At (X : Natural; Y : Natural) is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action   : constant Files.Events.Input_Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot, X, Y, Window_W, Window_H, Y_Offset => -1, Line_Height => Line);
      begin
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Files.Types.No_Modifiers,
            Result            => Result);
      end Scroll_At;

      Info_X, Info_Y : Natural;
      Main_X, Main_Y : Natural;
   begin
      Files_Suite.Support.Select_Name (Model, "Gamma.md");
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Info_Pane_Is_Open (Model), "the info pane is open for the scroll-target test");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
      begin
         Assert (Info.Width > 0 and then Info.Height > 0, "the info pane has a hittable region");
         Info_X := Info.X + Info.Width / 2;
         Info_Y := Info.Y + Info.Height / 2;
         Main_X := Layout.Main_X + Layout.Main_Width / 2;
         Main_Y := Layout.Main_Y + Layout.Main_Height / 2;
      end;

      Scroll_At (Info_X, Info_Y);
      Assert
        (Files.Model.Info_Pane_Scroll_Lines (Model) > 0,
         "scrolling over the info pane moves the info-pane offset");
      Assert
        (Files.Model.Main_View_Scroll_Lines (Model) = 0,
         "scrolling over the info pane leaves the main view untouched");

      declare
         Info_Before : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
      begin
         Scroll_At (Main_X, Main_Y);
         Assert
           (Files.Model.Main_View_Scroll_Lines (Model) > 0,
            "scrolling over the main view moves the main-view offset");
         Assert
           (Files.Model.Info_Pane_Scroll_Lines (Model) = Info_Before,
            "scrolling over the main view leaves the info-pane offset unchanged");
      end;
   end Test_Targeted_Scroll;

   --  Find the first settings hit region of the given Kind and Field.
   procedure Find_Settings_Hit
     (Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Kind      : Files.Rendering.Settings_Hit_Kind;
      Field     : Natural;
      X         : out Natural;
      Y         : out Natural;
      Found     : out Boolean)
   is
      Snapshot : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Model, Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
   begin
      X := 0;
      Y := 0;
      Found := False;
      for Region of Frame.Settings_Hits loop
         if Region.Kind = Kind and then Region.Field = Field then
            X := Region.X + Region.Width / 2;
            Y := Region.Y + Region.Height / 2;
            Found := True;
            return;
         end if;
      end loop;
   end Find_Settings_Hit;

   --  Open the settings pane through the real Ctrl+, shortcut so its draft is
   --  initialised exactly as the live app does.
   procedure Open_Settings_Pane
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      Result : Files.Interaction.Interaction_Result;
      Action : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Files.Types.Key_Comma, Ctrl);
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Ctrl,
         Result            => Result);
   end Open_Settings_Pane;

   procedure Test_Settings_Path_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "interaction.conf");
   begin
      Files_Suite.Support.Reset_Root;

      --  (1) Straight command: Toggle_Hidden_Files flips the persisted flag,
      --  reloads the directory, and writes the settings file.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
         Action   : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Toggle_Hidden_Files_Command,
            others  => <>);
         Before   : constant Boolean := Settings.Show_Hidden_Files;
      begin
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Files.Types.No_Modifiers,
            Result            => Result);
         Assert (Settings.Show_Hidden_Files /= Before, "the straight command flips Show_Hidden_Files");
         Assert (Result.Settings_Changed, "the straight command reports a settings change");
         Assert (Result.Directory_Reloaded, "the straight command reports the directory reload");
         Assert (Ada.Directories.Exists (Path), "the straight command persists the settings file");
      end;

      --  (2) Settings-pane hit: clicking the hidden-files toggle routes through
      --  Handle_Settings_Click -> Save_Settings and flips the flag too.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
         Snapshot : Files.Rendering.View_Snapshot;
         Frame    : Files.Rendering.Frame_Commands;
         Action   : Files.Events.Input_Action;
         X, Y     : Natural;
         Found    : Boolean;
         Before   : Boolean;
      begin
         Open_Settings_Pane (Model, Settings);
         Assert (Files.Model.Settings_Pane_Is_Open (Model), "the settings pane is open for the hit-test path");
         Before := Settings.Show_Hidden_Files;

         Find_Settings_Hit (Model, Settings, Files.Rendering.Settings_Hit_Toggle, 2, X, Y, Found);
         Assert (Found, "the hidden-files toggle hit region is laid out");

         Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    := Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Settings_Click_Input_Action,
            "the toggle coordinate translates to a settings click");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Files.Types.No_Modifiers,
            Result            => Result);
         Assert (Settings.Show_Hidden_Files /= Before, "the settings-pane hit flips Show_Hidden_Files");
         Assert (Result.Settings_Changed, "the settings-pane save reports a settings change");
         Assert (Result.Clear_Pending_Text, "the settings-pane save asks the shell to drop pending text");
      end;

      --  (3) Font-size case: stepping the font field up via the settings pane
      --  changes the live font size and asks the shell to rebuild glyphs.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
         Snapshot : Files.Rendering.View_Snapshot;
         Frame    : Files.Rendering.Frame_Commands;
         Action   : Files.Events.Input_Action;
         X, Y     : Natural;
         Found    : Boolean;
      begin
         Open_Settings_Pane (Model, Settings);
         Find_Settings_Hit (Model, Settings, Files.Rendering.Settings_Hit_Stepper_Up, 7, X, Y, Found);
         Assert (Found, "the font-size stepper-up hit region is laid out");

         Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    := Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Action   :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Assert
           (Action.Kind = Files.Events.Settings_Click_Input_Action,
            "the stepper coordinate translates to a settings click");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Action            => Action,
            Current_Font_Size => Base_Font,
            Modifiers         => Files.Types.No_Modifiers,
            Result            => Result);
         Assert
           (Settings.Font_Pixel_Size /= Base_Font,
            "stepping the font field changes the saved font pixel size");
         Assert (Result.Font_Size_Changed, "the save signals a live font-size change to the shell");
         Assert (Result.Needs_Glyph_Rebuild, "the save asks the shell to invalidate its glyph cache");
      end;
   end Test_Settings_Path_Commands;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Interaction_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Interaction;
