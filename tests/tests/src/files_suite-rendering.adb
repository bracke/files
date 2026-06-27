with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Interfaces.C.Strings;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Features;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Files.Rendering;
with Files.Rendering.Vulkan;
with Files.Settings;
with Files.Types;
with Files.UTF8;
with Files.UI;
with Files_Suite.Support;

package body Files_Suite.Rendering is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_32;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Command_Placement;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Application.Run_Mode;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Files.Rendering.Accessibility_Role;
   use type Files.Rendering.Icon_Asset_Color_Role;
   use type Files.Rendering.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Rendering.Vulkan.Atlas_Texture_Format;
   use type Files.Rendering.Vulkan.Texture_Source;
   use type Files.Rendering.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.Key_Code;
   use type Files.Types.Modifier_Set;
   use type Files.Types.Navigation_Direction;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;
   use Files_Suite.Support;

   type Rendering_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Rendering_Test_Case);

   procedure Test_Render_Snapshot_And_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Sort_Menu_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Loaded_UTF8_Item_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Event_Translation (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files rendering and events");
   end Name;

   overriding procedure Register_Tests (T : in out Rendering_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Render_Snapshot_And_Layout'Access, "render snapshot and layout");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Sort_Menu_Rendering'Access, "bottom bar sort menu rendering");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Loaded_UTF8_Item_Rendering'Access, "directory-loaded UTF-8 item rendering");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Event_Translation'Access, "event translation");
   end Register_Tests;

   procedure Test_Render_Snapshot_And_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model          : Files.Model.Window_Model := Sample_Model;
      Settings       : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Snapshot       : Files.Rendering.View_Snapshot;
      Layout         : Files.Rendering.Layout_Metrics;
      Small_Layout    : Files.Rendering.Item_Layout_Vectors.Vector;
      Large_Layout    : Files.Rendering.Item_Layout_Vectors.Vector;
      Details_Layout  : Files.Rendering.Item_Layout_Vectors.Vector;
      Palette_Layout  : Files.Rendering.Command_Palette_Layout;
      Palette_Rows    : Files.Rendering.Command_Result_Layout_Vectors.Vector;
      Root_Layout     : Files.Rendering.Root_Selector_Layout;
      Root_Rows       : Files.Rendering.Root_Path_Layout_Vectors.Vector;
      Info_Layout     : Files.Rendering.Info_Pane_Layout;
      Roots           : Files.Types.String_Vectors.Vector;
      Empty_Items     : Files.File_System.Item_Vectors.Vector;
      Toolbar         : Files.UI.Toolbar_Layout;
      Bottom_Bar      : Files.UI.Bottom_Bar_Layout;
      Frame           : Files.Rendering.Frame_Commands;
      Text_Renderer   : Files.Rendering.Text_Renderer;
      Text_Result     : Files.Rendering.Text_Render_Result;
      Vulkan_Renderer : Files.Rendering.Vulkan.Vulkan_Renderer;
      Vulkan_Status   : Files.Rendering.Vulkan.Vulkan_Status;
      Vulkan_Batch    : Files.Rendering.Vulkan.Submission_Batch;

      function Vulkan_Drawable_Icon_Count
        (Commands : Files.Rendering.Frame_Commands)
         return Natural
      is
         Count : Natural := 0;
         Name  : Unbounded_String;
      begin
         for Command of Commands.Icons loop
            Name := Command.Icon_Id;
            if Length (Name) < 8
              or else Slice (Name, 1, 8) /= "toolbar-"
            then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end Vulkan_Drawable_Icon_Count;
   begin
      Assert
        (not Files.Rendering.Default_Theme.High_Contrast,
         "default render theme is not high contrast");
      Assert
        (Files.Rendering.High_Contrast_Theme.High_Contrast,
         "high-contrast render theme advertises accessibility mode");
      Assert
        (Files.Rendering.High_Contrast_Theme.Selection_Strong,
         "high-contrast render theme strengthens selection");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Focus_Path_Input (Model);
      Files.Model.Set_Path_Input_Text (Model, "/missing");
      Files.Model.Commit_Path_Input
        (Model,
         Files.File_System.Path_Result'
           (Status         => Files.File_System.Path_Missing,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.missing")),
         Empty_Items);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (To_String (Snapshot.Current_Path) = Root, "snapshot captures current path");
      Assert (Snapshot.View_Mode = Files.Types.Small_Icons, "snapshot captures current view mode");
      Assert (Snapshot.Focus = Files.Types.Focus_Path_Input, "snapshot captures focused path input");
      Assert (Snapshot.Text_Cursor_Position = 8, "snapshot captures focused text cursor position");
      Assert (To_String (Snapshot.Path_Input_Text) = "/missing", "snapshot captures path input text");
      Assert (not Snapshot.Path_Input_Valid, "snapshot captures path input validation state");
      Assert
        (To_String (Snapshot.Path_Input_Error_Key) = "error.path.missing",
         "snapshot captures path input error key");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      declare
         Drag_Frame         : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot,
              Width           => 1000,
              Height          => 800,
              Line_Height     => 20,
              Drag_Item_Index => 1,
              Drag_X          => 250,
              Drag_Y          => 200,
              Has_Drag        => True);
         Found_Drag_Panel   : Boolean := False;
         Found_Drag_Icon    : Boolean := False;
         Found_Drag_Name    : Boolean := False;
      begin
         for Command of Drag_Frame.Rectangles loop
            if Command.X = 264
              and then Command.Y = 214
              and then Command.Color = Files.Rendering.Hover_Color
            then
               Found_Drag_Panel := True;
            end if;
         end loop;

         for Command of Drag_Frame.Icons loop
            if Command.X = 272
              and then Command.Y = 222
              and then Command.Size = 28
            then
               Found_Drag_Icon := True;
            end if;
         end loop;

         for Command of Drag_Frame.Text loop
            if Command.X > 272
              and then Command.Y >= 214
              and then To_String (Command.Text) = To_String (Snapshot.Items.Element (1).Name)
            then
               Found_Drag_Name := True;
            end if;
         end loop;

         Assert (Found_Drag_Panel, "drag preview renders a visible panel near the cursor");
         Assert (Found_Drag_Icon, "drag preview renders the dragged item icon");
         Assert (Found_Drag_Name, "drag preview renders the dragged item name");
      end;
      declare
         Drag_Items  : Files.File_System.Item_Vectors.Vector;
         Drag_Model  : Files.Model.Window_Model;
         Drag_Snapshot : Files.Rendering.View_Snapshot;
         Drag_Layout : Files.Rendering.Layout_Metrics;
         Drag_Item_Layout : Files.Rendering.Item_Layout_Vectors.Vector;
         Target_Rect : Files.Rendering.Item_Layout;
         Target_Frame : Files.Rendering.Frame_Commands;
         Found_Target_Accent : Boolean := False;
      begin
         Drag_Items.Append
           (Files.File_System.Make_Item (Root, "drag-source.txt", Files.Types.Regular_File_Item, "text/plain"));
         Drag_Items.Append
           (Files.File_System.Make_Item (Root, "drop-target", Files.Types.Directory_Item, "inode/directory"));
         Files.Model.Initialize (Drag_Model, Root, Drag_Items, "/home/test");
         Files.Model.Select_Visible (Drag_Model, 1);
         Drag_Snapshot := Files.Rendering.Build_Snapshot (Drag_Model, Settings);
         Drag_Layout :=
           Files.Rendering.Calculate_Layout (Drag_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Drag_Item_Layout := Files.Rendering.Calculate_Item_Layout (Drag_Snapshot, Drag_Layout, Line_Height => 20);
         Target_Rect := Drag_Item_Layout.Element (2);
         Target_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Drag_Snapshot,
              Width           => 1000,
              Height          => 800,
              Line_Height     => 20,
              Hover_X         => Target_Rect.X + 1,
              Hover_Y         => Target_Rect.Y + 1,
              Has_Hover       => True,
              Drag_Item_Index => 1,
              Drag_X          => Target_Rect.X + 1,
              Drag_Y          => Target_Rect.Y + 1,
              Has_Drag        => True);

         for Command of Target_Frame.Rectangles loop
            if Command.X = Target_Rect.X
              and then Command.Y = Target_Rect.Y
              and then Command.Width = Natural'Min (4, Target_Rect.Width)
              and then Command.Height = Target_Rect.Height
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Target_Accent := True;
            end if;
         end loop;

         Assert (Found_Target_Accent, "drag rendering marks a valid directory drop target");
      end;
      declare
         Found_A11y_Path_Input_Error : Boolean := False;
      begin
         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_Text_Input
              and then To_String (Node.Name) = Files.Localization.Text ("command.path.focus")
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("error.path.missing")) > 0
            then
               Found_A11y_Path_Input_Error := True;
            end if;
         end loop;

         Assert
           (Found_A11y_Path_Input_Error,
            "frame exposes path input validation error to accessibility");
      end;
      declare
         Narrow_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 80, Height => 120, Line_Height => 20);
         Found_Truncated_Text : Boolean := False;
      begin
         for Command of Narrow_Frame.Text loop
            if Command.Truncated then
               Found_Truncated_Text := True;
               Assert
                 (Length (Command.Text) > 0,
                  "truncated text command keeps visible fitted text");
            end if;
         end loop;

         Assert (Found_Truncated_Text, "narrow frame records truncated text commands");
         for Command of Narrow_Frame.Rectangles loop
            Assert
              (Command.X < Narrow_Frame.Layout.Width
               and then Command.Width <= Narrow_Frame.Layout.Width - Command.X,
               "narrow frame clips rectangle width to layout bounds");
            Assert
              (Command.Y < Narrow_Frame.Layout.Height
               and then Command.Height <= Narrow_Frame.Layout.Height - Command.Y,
               "narrow frame clips rectangle height to layout bounds");
         end loop;
         for Command of Narrow_Frame.Text loop
            Assert
              (Command.X < Narrow_Frame.Layout.Width
               and then Command.Width <= Narrow_Frame.Layout.Width - Command.X,
               "narrow frame clips text width to layout bounds");
            Assert
              (Command.Y < Narrow_Frame.Layout.Height
               and then Command.Height <= Narrow_Frame.Layout.Height - Command.Y,
               "narrow frame clips text height to layout bounds");
         end loop;
         for Command of Narrow_Frame.Icons loop
            Assert
              (Command.X < Narrow_Frame.Layout.Width
               and then Command.Size <= Narrow_Frame.Layout.Width - Command.X,
               "narrow frame clips icon width to layout bounds");
            Assert
              (Command.Y < Narrow_Frame.Layout.Height
               and then Command.Size <= Narrow_Frame.Layout.Height - Command.Y,
               "narrow frame clips icon height to layout bounds");
         end loop;
         for Command of Narrow_Frame.Accessibility loop
            Assert
              (Command.X < Narrow_Frame.Layout.Width
               and then Command.Width <= Narrow_Frame.Layout.Width - Command.X,
               "narrow frame clips accessibility width to layout bounds");
            Assert
              (Command.Y < Narrow_Frame.Layout.Height
               and then Command.Height <= Narrow_Frame.Layout.Height - Command.Y,
               "narrow frame clips accessibility height to layout bounds");
         end loop;
      end;
      declare
         Zero_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 0, Height => 0, Line_Height => 20);
      begin
         Assert (Zero_Frame.Layout.Width = 0, "zero frame preserves zero width");
         Assert (Zero_Frame.Layout.Height = 0, "zero frame preserves zero height");
         Assert (Zero_Frame.Rectangles.Is_Empty, "zero frame emits no rectangle commands");
         Assert (Zero_Frame.Text.Is_Empty, "zero frame emits no text commands");
         Assert (Zero_Frame.Icons.Is_Empty, "zero frame emits no icon commands");
         Assert (Zero_Frame.Tooltips.Is_Empty, "zero frame emits no tooltip commands");
         Assert (Zero_Frame.Accessibility.Is_Empty, "zero frame emits no accessibility nodes");
      end;
      declare
         Rename_Model : Files.Model.Window_Model := Sample_Model;
         Rename_Frame : Files.Rendering.Frame_Commands;
      begin
         Files.Model.Select_Visible (Rename_Model, 1);
         Files.Model.Toggle_Rename (Rename_Model);
         Rename_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Files.Rendering.Build_Snapshot (Rename_Model),
              Width       => 2,
              Height      => 80,
              Line_Height => 20);
         Assert (Rename_Frame.Layout.Width = 2, "narrow rename frame preserves width");
         for Command of Rename_Frame.Rectangles loop
            Assert
              (Command.X < Rename_Frame.Layout.Width
               and then Command.Width <= Rename_Frame.Layout.Width - Command.X,
               "narrow rename frame clips rectangle width");
         end loop;
      end;
      Toolbar := Files.UI.Calculate_Toolbar_Layout (1000);
      declare
         Found_Path_Error_Border : Boolean := False;
         Found_Path_Caret        : Boolean := False;
         Found_Path_Text_Padding : Boolean := False;
      begin
         for Command of Frame.Rectangles loop
            if Command.X = Toolbar.Middle_X
              and then Command.Y = Files.UI.Toolbar_Input_Y (20)
              and then Command.Width = Toolbar.Middle_Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Input_Error_Color
            then
               Found_Path_Error_Border := True;
            elsif Command.X =
              Toolbar.Middle_X + Files.UI.Input_Field_Padding + 8 * (20 / 2)
              and then Command.Y = 12
              and then Command.Width = 2
              and then Command.Height = 16
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Path_Caret := True;
            end if;
         end loop;
         for Command of Frame.Text loop
            if To_String (Command.Text) = To_String (Snapshot.Path_Input_Text)
              and then Command.X = Toolbar.Middle_X + Files.UI.Input_Field_Padding
              and then Command.Width =
                Toolbar.Middle_Width - 2 * Files.UI.Input_Field_Padding
            then
               Found_Path_Text_Padding := True;
            end if;
         end loop;

         Assert (Found_Path_Error_Border, "frame renders focused invalid path input border");
         Assert (Found_Path_Caret, "frame renders focused path input caret");
         Assert (Found_Path_Text_Padding, "frame renders path input with inner padding");
      end;
      Files.Model.Cancel_Focus_Or_Edit (Model);

      Files.Model.Focus_Filter_Input (Model);
      Files.Model.Set_Filter (Model, "beta");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Focus = Files.Types.Focus_Filter_Input, "snapshot captures focused filter input");
      Assert (To_String (Snapshot.Filter_Text) = "beta", "snapshot captures focused filter text");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Toolbar := Files.UI.Calculate_Toolbar_Layout (1000);
      declare
         Found_Filter_Border : Boolean := False;
         Found_Filter_Text_Padding : Boolean := False;
      begin
         for Command of Frame.Rectangles loop
            if Command.X = Toolbar.Right_X
              and then Command.Y = Files.UI.Toolbar_Input_Y (20)
              and then Command.Width = Toolbar.Right_Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Filter_Border := True;
            end if;
         end loop;
         for Command of Frame.Text loop
            if To_String (Command.Text) = To_String (Snapshot.Filter_Text)
              and then Command.X = Toolbar.Right_X + Files.UI.Input_Field_Padding
              and then Command.Width =
                Toolbar.Right_Width - 2 * Files.UI.Input_Field_Padding
            then
               Found_Filter_Text_Padding := True;
            end if;
         end loop;

         Assert (Found_Filter_Border, "frame renders focused filter input border");
         Assert (Found_Filter_Text_Padding, "frame renders filter input with inner padding");
      end;
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Clear_Filter (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      declare
         Found_Filter_Placeholder : Boolean := False;
      begin
         for Command of Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("filter.placeholder")
              and then Command.X = Toolbar.Right_X + Files.UI.Input_Field_Padding
              and then Command.Color = Files.Rendering.Muted_Text_Color
            then
               Found_Filter_Placeholder := True;
            end if;
         end loop;

         Assert (Found_Filter_Placeholder, "empty filter input renders localized placeholder text");
         Assert
           (Ada.Strings.Fixed.Index (Files.Localization.Text ("filter.placeholder"), "...") = 0,
            "filter placeholder uses a real ellipsis");
      end;

      Files.Model.Begin_Create_File (Model, "draft.txt");
      Files.Model.Select_Visible (Model, 4);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Rename_Active, "snapshot captures active rename state");
      Assert (To_String (Snapshot.Rename_Text) = "draft.txt", "snapshot captures rename text");
      Assert (Snapshot.Temporary_Item_Active, "snapshot captures temporary item state");
      Assert (To_String (Snapshot.Temporary_Item_Name) = "draft.txt", "snapshot captures temporary item name");
      Assert (Natural (Snapshot.Items.Length) = 4, "snapshot includes existing items and temporary item");
      declare
         Found_Temporary : Boolean := False;
      begin
         for Item of Snapshot.Items loop
            if To_String (Item.Name) = "draft.txt" then
               Found_Temporary := True;
               Assert (Item.Selected, "snapshot captures selected temporary item");
            end if;
         end loop;

         Assert (Found_Temporary, "snapshot includes visible temporary item in sorted projection");
      end;
      Assert (Snapshot.Selected_Info.Is_Empty, "snapshot skips closed info-pane selected metadata");
      Files.Model.Toggle_Info_Pane (Model);
      declare
         Info_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         Assert (Natural (Info_Snapshot.Selected_Info.Length) = 1, "snapshot includes temporary item info");
         Assert
           (To_String (Info_Snapshot.Selected_Info.Element (1).Name) = "draft.txt",
            "snapshot temporary item info uses pending name");
      end;
      declare
         Wrapped_Snapshot : Files.Rendering.View_Snapshot;
         Wrapped_Frame    : Files.Rendering.Frame_Commands;
         Found_First_Wrap : Boolean := False;
         Found_Second_Wrap : Boolean := False;
      begin
         Wrapped_Snapshot.Info_Pane_Open := True;
         Wrapped_Snapshot.Selected_Info.Append
           (Files.Rendering.Info_Snapshot'
              (Name            => To_Unbounded_String ("wrapped.txt"),
               Filetype        => To_Unbounded_String ("application/octet-stream"),
               Filetype_Detail => To_Unbounded_String ("abcdefghijklmnopqrstuvwxyz"),
               Filetype_Extra  => To_Unbounded_String (""),
               others          => <>));
         Wrapped_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Wrapped_Snapshot, Width => 360, Height => 500, Line_Height => 20);
         for Text of Wrapped_Frame.Text loop
            Assert
              (Ada.Strings.Fixed.Index (To_String (Text.Text), "...") = 0,
               "info pane wrapped values do not use three-dot abbreviation");
            if To_String (Text.Text) = "abcdef"
              and then not Text.Truncated
              and then Text.Color = Files.Rendering.Muted_Text_Color
            then
               Found_First_Wrap := True;
            elsif To_String (Text.Text) = "ghijkl"
              and then not Text.Truncated
              and then Text.Color = Files.Rendering.Muted_Text_Color
            then
               Found_Second_Wrap := True;
            end if;
         end loop;

         Assert (Found_First_Wrap, "info pane wraps long data rows without abbreviation");
         Assert (Found_Second_Wrap, "info pane continues wrapped data on the next row");
      end;
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Small_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      declare
         Rename_Rect         : Files.Rendering.Item_Layout;
         Found_Rename_Border : Boolean := False;
      begin
         for Item_Rect of Small_Layout loop
            if Item_Rect.Visible_Index = 4 then
               Rename_Rect := Item_Rect;
            end if;
         end loop;

         for Command of Frame.Rectangles loop
            if Command.X = Rename_Rect.X
              and then Command.Y = Rename_Rect.Y
              and then Command.Width = Rename_Rect.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Rename_Border := True;
            end if;
         end loop;

         Assert (Found_Rename_Border, "frame renders focused rename item border");
      end;
      Files.Model.Cancel_Focus_Or_Edit (Model);

      Files.Model.Set_Error (Model, "error.directory.load");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (To_String (Snapshot.Last_Error_Key) = "error.directory.load", "snapshot captures last error key");
      Assert (Snapshot.Item_Count = 3, "snapshot captures loaded item count");
      Assert (Snapshot.Selected_Count = 1, "snapshot captures selected count");
      Assert (Snapshot.Items.Element (1).Selected, "snapshot captures selected item state");
      Files.Model.Set_Filter (Model, "beta");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Item_Count = 3, "filtered snapshot preserves loaded item count");
      Assert (Snapshot.Visible_Count = 1, "filtered snapshot captures visible item count");
      Assert (Snapshot.Selected_Count = 1, "filtered snapshot captures reconciled selection count");
      Assert (Natural (Snapshot.Items.Length) = 1, "filtered snapshot only includes visible items");
      Assert (To_String (Snapshot.Filter_Text) = "beta", "filtered snapshot captures filter text");
      Assert (To_String (Snapshot.Items.Element (1).Name) = "Beta.txt", "filtered snapshot contains visible item");
      Files.Model.Clear_Filter (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Items.Element (1).Permissions) =
         To_String (Files.Model.Visible_Item (Model, 1).Permissions),
         "item snapshot captures permissions");
      Assert
        (Snapshot.Items.Element (1).Creation_Available =
         Files.Model.Visible_Item (Model, 1).Creation_Available,
         "item snapshot captures creation metadata availability");

      declare
         Scrolled_Model : Files.Model.Window_Model := Sample_Model;
         Scrolled       : Files.Rendering.View_Snapshot;
         Scrolled_Items : Files.Rendering.Item_Layout_Vectors.Vector;
         Main_View      : Files.Rendering.Main_View_Layout;
      begin
         Files.Model.Set_View_Mode (Scrolled_Model, Files.Types.Details);
         Files.Model.Scroll_Main_View (Scrolled_Model, 1);
         Scrolled := Files.Rendering.Build_Snapshot (Scrolled_Model);
         Layout := Files.Rendering.Calculate_Layout (Scrolled, Width => 1000, Height => 800, Line_Height => 20);
         Scrolled_Items := Files.Rendering.Calculate_Item_Layout (Scrolled, Layout, Line_Height => 20);
         Main_View := Files.Rendering.Calculate_Main_View_Layout (Scrolled, Layout, Line_Height => 20);
         Assert (Scrolled.Main_View_Scroll_Lines = 1, "snapshot captures main view scroll lines");
         Assert (Main_View.Content_Height = 124, "main view layout tracks details header and row content height");
         Assert (not Main_View.Scrollbar_Visible, "short main view does not render scrollbar");
         Assert (Main_View.Scroll_Lines = 0, "short main view clamps effective scroll lines");
         Assert (Scrolled_Items.Element (1).Y = Layout.Main_Y + 36, "details layout reserves padded header line");
         Assert (Scrolled_Items.Element (1).Height = 28, "short item layout keeps first padded row visible");
         Assert (Scrolled_Items.Element (2).Y = Layout.Main_Y + 68, "short item layout keeps second row below first");
         Assert
           (Files.Rendering.Item_At (Scrolled_Items, X => Layout.Main_X + 9, Y => Layout.Main_Y + 9) = 0,
            "details header does not hit-test as an item");
         Assert
          (Files.Rendering.Item_At (Scrolled_Items, X => Layout.Main_X + 9, Y => Layout.Main_Y + 37) = 1,
           "short item hit test returns first visible item below header");

         Frame := Files.Rendering.Build_Frame_Commands (Scrolled, Width => 1000, Height => 800, Line_Height => 20);
         declare
            Alternate_Row       : constant Files.Rendering.Item_Layout := Scrolled_Items.Element (2);
            Found_Alternate_Row : Boolean := False;
         begin
            for Command of Frame.Rectangles loop
               if Command.X = Alternate_Row.X
                 and then Command.Y = Alternate_Row.Y
                 and then Command.Width = Alternate_Row.Width
                 and then Command.Height = Alternate_Row.Height
                 and then Command.Color = Files.Rendering.Detail_Alternate_Color
               then
                  Found_Alternate_Row := True;
               end if;
            end loop;

            Assert (Found_Alternate_Row, "details view renders alternating row background");
         end;

         declare
            Overflow : Files.Rendering.View_Snapshot := Scrolled;
            Frame    : Files.Rendering.Frame_Commands;
            Excessive_Items : Files.Rendering.Item_Layout_Vectors.Vector;
            Found_Track : Boolean := False;
            Found_Thumb : Boolean := False;
            Found_Grip  : Boolean := False;
         begin
            Overflow.Items.Clear;
            for Index in 1 .. 12 loop
               Overflow.Items.Append
                 (Files.Rendering.Item_Snapshot'
                    (Name          => To_Unbounded_String ("item" & Natural'Image (Index)),
                     Filetype      => To_Unbounded_String ("text/plain"),
                     Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
                     Icon_Id       => To_Unbounded_String ("text"),
                     Kind          => Files.Types.Regular_File_Item,
                     Selected      => False,
                     Visible_Index => Index,
                     others        => <>));
            end loop;
            Overflow.Main_View_Scroll_Lines := 2;
            Layout := Files.Rendering.Calculate_Layout (Overflow, Width => 240, Height => 120, Line_Height => 20);
            Main_View := Files.Rendering.Calculate_Main_View_Layout (Overflow, Layout, Line_Height => 20);
            Assert (Main_View.Scrollbar_Visible, "overflow main view exposes scrollbar");
            Assert (Main_View.Scrollbar_Y = Layout.Main_Y + 8, "main view scrollbar track follows content padding");
            Assert
              (Main_View.Scrollbar_Track_Height = Layout.Main_Height - 16,
               "main view scrollbar track height follows content padding");
            Assert (Main_View.Scrollbar_Thumb_Y > Main_View.Scrollbar_Y, "main view scrollbar thumb moves");
            Frame := Files.Rendering.Build_Frame_Commands (Overflow, Width => 240, Height => 120, Line_Height => 20);
            for Command of Frame.Rectangles loop
               if Command.X = Main_View.Scrollbar_X
                 and then Command.Y = Main_View.Scrollbar_Y
                 and then Command.Width = Main_View.Scrollbar_Width
                 and then Command.Height = Main_View.Scrollbar_Track_Height
                 and then Command.Color = Files.Rendering.Border_Color
               then
                  Found_Track := True;
               elsif Command.X = Main_View.Scrollbar_X
                 and then Command.Y = Main_View.Scrollbar_Thumb_Y
                 and then Command.Width = Main_View.Scrollbar_Width
                 and then Command.Height = Main_View.Scrollbar_Height
                 and then Command.Color = Files.Rendering.Selection_Color
               then
                  Found_Thumb := True;
               elsif Command.X = Main_View.Scrollbar_X + 1
                 and then Command.Width = Main_View.Scrollbar_Width - 2
                 and then Command.Color = Files.Rendering.Muted_Text_Color
               then
                  Found_Grip := True;
               end if;
            end loop;

            Assert (Found_Track, "frame includes main-view scrollbar track");
            Assert (Found_Thumb, "frame includes main-view scrollbar thumb");
            Assert (Found_Grip, "frame includes main-view scrollbar grip");
            Assert (Found_Grip, "frame includes overflow-safe scrollbar grip");

            Overflow.Main_View_Scroll_Lines := 1;
            Layout := Files.Rendering.Calculate_Layout (Overflow, Width => 240, Height => 220, Line_Height => 20);
            Excessive_Items := Files.Rendering.Calculate_Item_Layout (Overflow, Layout, Line_Height => 20);
            Assert
              (Excessive_Items.Element (1).Height = 0,
               "partially scrolled details row is hidden instead of clipped");
            Assert
              (Excessive_Items.Element (1).Icon_Size = 0,
               "partially scrolled details icon does not shrink");
            Assert
              (Excessive_Items.Element (2).Icon_Size = 20,
               "next complete details row keeps stable icon size while scrolling");

            Layout := Files.Rendering.Calculate_Layout (Overflow, Width => 0, Height => 120, Line_Height => 20);
            Main_View := Files.Rendering.Calculate_Main_View_Layout (Overflow, Layout, Line_Height => 20);
            Assert (Main_View.Content_Height > Layout.Main_Height, "zero-width main view still tracks overflow");
            Assert (not Main_View.Scrollbar_Visible, "zero-width main view does not expose scrollbar");
            Assert (Main_View.Scrollbar_Width = 0, "zero-width main view reports no scrollbar width");

            Overflow.Main_View_Scroll_Lines := 999;
            Layout := Files.Rendering.Calculate_Layout (Overflow, Width => 240, Height => 220, Line_Height => 20);
            Main_View := Files.Rendering.Calculate_Main_View_Layout (Overflow, Layout, Line_Height => 20);
            Excessive_Items := Files.Rendering.Calculate_Item_Layout (Overflow, Layout, Line_Height => 20);
            Assert (Main_View.Scroll_Lines = 13, "main view layout clamps excessive scroll lines");
            Assert
              (Overflow.Main_View_Scroll_Lines = 999,
               "main view layout clamp does not mutate snapshot scroll request");
            Assert
              (Files.Rendering.Item_At (Excessive_Items, X => Layout.Main_X + 9, Y => Layout.Main_Y + 49) = 10,
               "item layout uses clamped details scroll offset to reveal final rows");
         end;
      end;

      declare
         Empty_Model : Files.Model.Window_Model;
         Empty_Frame : Files.Rendering.Frame_Commands;
         Found_Empty : Boolean := False;
         Found_Empty_Panel : Boolean := False;
         Found_Empty_Icon  : Boolean := False;
      begin
         Files.Model.Initialize
           (Empty_Model,
            Directory_Path => Root,
            Items          => Empty_Items,
            Home_Path      => "/home/test");
         Snapshot := Files.Rendering.Build_Snapshot (Empty_Model);
         Empty_Frame :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         for Command of Empty_Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("status.empty_directory") then
               Found_Empty := True;
            end if;
         end loop;
         for Command of Empty_Frame.Rectangles loop
            if Command.Width >= 240
              and then Command.Height = 60
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Empty_Panel := True;
            elsif Command.Width = 20
              and then Command.Height = 20
              and then Command.Color = Files.Rendering.Muted_Text_Color
            then
               Found_Empty_Icon := True;
            end if;
         end loop;

         Assert (Found_Empty, "empty directory renders localized empty-state text");
         Assert (Found_Empty_Panel, "empty directory renders framed empty-state panel");
         Assert (Found_Empty_Icon, "empty directory renders empty-state icon mark");
      end;

      declare
         Filtered_Model : Files.Model.Window_Model := Sample_Model;
         Filtered_Frame : Files.Rendering.Frame_Commands;
         Found_Filtered : Boolean := False;
         Found_Filtered_Panel : Boolean := False;
      begin
         Files.Model.Set_Filter (Filtered_Model, "no-visible-items");
         Snapshot := Files.Rendering.Build_Snapshot (Filtered_Model);
         Filtered_Frame :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         for Command of Filtered_Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("status.empty_filter") then
               Found_Filtered := True;
            end if;
         end loop;
         for Command of Filtered_Frame.Rectangles loop
            if Command.Width >= 240
              and then Command.Height = 60
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Filtered_Panel := True;
            end if;
         end loop;

         Assert (Found_Filtered, "filtered-empty view renders localized empty-state text");
         Assert (Found_Filtered_Panel, "filtered-empty view renders framed empty-state panel");
      end;

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 99);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Command_Palette_Open, "snapshot captures open command palette");
      Assert (To_String (Snapshot.Command_Palette_Query) = "navigate.back", "snapshot captures palette query");
      Assert (Snapshot.Command_Palette_Selected_Index = 1, "snapshot clamps stale palette selection");
      Assert
        (Files.Model.Command_Palette_Selected_Index (Model) = 99,
         "snapshot construction does not mutate stale palette selection");
      Assert (Natural (Snapshot.Command_Palette_Results.Length) = 1, "snapshot captures matching palette results");
      Assert
        (To_String (Snapshot.Command_Palette_Results.Element (1).Identifier) = "navigate.back",
         "snapshot captures palette result identifier");
      Assert
        (To_String (Snapshot.Command_Palette_Results.Element (1).Description) =
           Files.Localization.Text ("command.navigate.back.description"),
         "snapshot captures palette result description");
      Assert
        (To_String (Snapshot.Command_Palette_Results.Element (1).Shortcut_Text) = "alt+left",
         "snapshot captures palette result shortcut text");
      Assert
        (not Snapshot.Command_Palette_Results.Element (1).Enabled,
         "snapshot captures disabled palette result");
      Assert
        (Snapshot.Command_Palette_Results.Element (1).Selected,
         "snapshot marks effective selected palette result");
      Assert
        (To_String (Snapshot.Items.Element (1).Filetype_Detail) = Files.Localization.Text ("info.kind.text"),
         "snapshot captures localized item filetype detail");

      declare
         Unmapped_Items          : Files.File_System.Item_Vectors.Vector;
         Unmapped_Model          : Files.Model.Window_Model;
         Unmapped_Snapshot       : Files.Rendering.View_Snapshot;
         Found_Extension_Label   : Boolean := False;
         Found_Extensionless_Label : Boolean := False;
      begin
         Unmapped_Items.Append
           (Files.File_System.Make_Item
              (Root,
               "custom.asset",
               Files.Types.Regular_File_Item,
               "application/octet-stream"));
         Unmapped_Items.Append
           (Files.File_System.Make_Item
              (Root,
               "README",
               Files.Types.Regular_File_Item,
               "application/octet-stream"));
         Files.Model.Initialize
           (Unmapped_Model,
            Directory_Path => Root,
            Items          => Unmapped_Items,
            Home_Path      => "/home/test");
         Unmapped_Snapshot := Files.Rendering.Build_Snapshot (Unmapped_Model);

         for Item of Unmapped_Snapshot.Items loop
            if To_String (Item.Name) = "custom.asset" then
               Found_Extension_Label :=
                 To_String (Item.Filetype_Detail) = "ASSET";
            elsif To_String (Item.Name) = "README" then
               Found_Extensionless_Label :=
                 To_String (Item.Filetype_Detail) = Files.Localization.Text ("info.kind.file");
            end if;
         end loop;

         Assert (Found_Extension_Label, "snapshot labels unknown extension files by extension");
         Assert (Found_Extensionless_Label, "snapshot labels unknown extensionless files as generic files");
      end;

      Files.Model.Set_Command_Palette_Query (Model, "file.delete_selected");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (Natural (Snapshot.Command_Palette_Results.Length) = 1,
         "snapshot captures delete palette result");
      Assert
        (To_String (Snapshot.Command_Palette_Results.Element (1).Shortcut_Text) = "delete / backspace",
         "snapshot displays canonical primary and secondary shortcuts without aliases");

      Files.Model.Set_Command_Palette_Query (Model, "no-such-command-token");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 99);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Command_Palette_Selected_Index = 0, "empty palette snapshot clears stale selection");
      Assert
        (Files.Model.Command_Palette_Selected_Index (Model) = 99,
         "empty palette snapshot does not mutate stale model selection");
      Assert
        (Natural (Snapshot.Command_Palette_Results.Length) = 0,
         "empty palette snapshot has no result rows");

      Files.Model.Set_Command_Palette_Query (Model, "view.");
      Files.Model.Set_Command_Palette_Result_Offset (Model, 1);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Command_Palette_Result_Offset = 1, "snapshot captures palette result offset");
      Assert
        (Files.Model.Command_Palette_Result_Offset (Model) = 1,
         "snapshot construction does not mutate palette result offset");
      declare
         Tiny_Palette : constant Files.Rendering.Command_Palette_Layout :=
           (X              => 0,
            Y              => 0,
            Width          => 300,
            Height         => 60,
            Search_X       => 0,
            Search_Y       => 0,
            Search_Width   => 300,
            Search_Height  => 20,
            Results_X      => 0,
            Results_Y      => 20,
            Results_Width  => 300,
            Results_Height => 40,
            Row_Height     => 20);
         Tiny_Rows    : constant Files.Rendering.Command_Result_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Tiny_Palette);
      begin
         Assert (Natural (Tiny_Rows.Length) = 2, "scrolled palette layout only emits visible rows");
         Assert (Tiny_Rows.Element (1).Result_Index = 2, "scrolled palette starts at offset result");
         Assert (Tiny_Rows.Element (1).Y = 20, "scrolled palette first visible row starts at result top");
         Assert (Tiny_Rows.Element (2).Result_Index = 3, "scrolled palette includes following result");

         Snapshot.Command_Palette_Result_Offset := 99;
         declare
            Stale_Rows : constant Files.Rendering.Command_Result_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Tiny_Palette);
         begin
            Assert (Natural (Stale_Rows.Length) = 2, "stale palette offset still emits a full visible page");
            Assert (Stale_Rows.Element (1).Result_Index = 2, "stale palette offset clamps to last page start");
            Assert (Stale_Rows.Element (2).Result_Index = 3, "stale palette offset keeps final result visible");
         end;
      end;

      declare
         Palette_Viewport : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 160, Line_Height => 20);
         Palette_Layout   : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Palette_Viewport, Line_Height => 20);
         Bar_X            : constant Natural :=
           Palette_Layout.Results_X + Palette_Layout.Results_Width - 6;
         Palette_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 160, Line_Height => 20);
         Found_Track   : Boolean := False;
         Found_Thumb   : Boolean := False;
         Found_Grip    : Boolean := False;
      begin
         for Command of Palette_Frame.Rectangles loop
            if Command.X = Bar_X
              and then Command.Y = Palette_Layout.Results_Y
              and then Command.Width = 6
              and then Command.Height = Palette_Layout.Results_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Track := True;
            elsif Command.X = Bar_X
              and then Command.Y >= Palette_Layout.Results_Y
              and then Command.Width = 6
              and then Command.Height < Palette_Layout.Results_Height
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Thumb := True;
            elsif Command.X = Bar_X + 1
              and then Command.Width = 4
              and then Command.Color = Files.Rendering.Muted_Text_Color
            then
               Found_Grip := True;
            end if;
         end loop;

         Assert (Found_Track, "frame includes command-palette scrollbar track");
         Assert (Found_Thumb, "frame includes command-palette scrollbar thumb");
         Assert (Found_Grip, "frame includes command-palette scrollbar grip");
      end;

      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      Files.Model.Set_Command_Palette_Selected_Index (Model, 99);
      Files.Model.Set_Command_Palette_Result_Offset (Model, 99);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Assert (Snapshot.Command_Palette_Result_Offset = 0, "snapshot clamps stale palette result offset");
      Assert
        (Files.Model.Command_Palette_Result_Offset (Model) = 99,
         "snapshot offset clamp does not mutate the model");
      Assert (Layout.Width = 1000 and then Layout.Height = 800, "layout captures window dimensions");
      Assert (Layout.Toolbar_Height = 40, "toolbar height uses two text lines");
      Assert (Layout.Bottom_Bar_Height = 28, "bottom bar includes vertical padding around text");
      Assert (Layout.Main_X = 0 and then Layout.Main_Y = 40, "main content starts below toolbar");
      Assert (Layout.Main_Width = 750, "main content leaves room for info pane");
      Assert (Layout.Main_Height = 732, "main content leaves room for toolbar and padded bottom bar");
      Assert (Layout.Info_Pane_Width = 250, "info pane uses stable right-side width");
      Assert (Layout.Command_Width = 800, "command palette width is 80 percent");
      Assert (Layout.Command_Height = 640, "command palette height is 80 percent");

      Info_Layout := Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Info_Layout.X = 750, "info pane layout starts after main content");
      Assert (Info_Layout.Y = Layout.Main_Y, "info pane layout starts at main content y");
      Assert (Info_Layout.Width = Layout.Info_Pane_Width, "info pane layout uses pane width");
      Assert (Info_Layout.Height = Layout.Main_Height, "info pane layout uses main height");
      Assert (Info_Layout.Content_Height = 560, "single selected item contributes padded metadata rows");
      Assert (not Info_Layout.Scrollbar_Visible, "single selected item does not need scrollbar");

      declare
         Overflow : Files.Rendering.View_Snapshot := Snapshot;
      begin
         for Index in 1 .. 5 loop
            Overflow.Selected_Info.Append (Overflow.Selected_Info.Element (1));
         end loop;

         Info_Layout := Files.Rendering.Calculate_Info_Pane_Layout (Overflow, Layout, Line_Height => 20);
         Assert (Info_Layout.Content_Height = 3260, "overflow info pane tracks full padded content height");
         Assert (Info_Layout.Scroll_Lines = 0, "overflow info pane starts unscrolled");
         Assert (Info_Layout.Scroll_Pixels = 0, "overflow info pane starts at top pixel");
         Assert (Info_Layout.Scrollbar_Visible, "overflow info pane exposes scrollbar");
         Assert (Info_Layout.Scrollbar_X = 994, "info pane scrollbar is right aligned");
         Assert (Info_Layout.Scrollbar_Y = Layout.Main_Y, "info pane scrollbar starts at pane top");
         Assert (Info_Layout.Scrollbar_Thumb_Y = Layout.Main_Y, "info pane scrollbar thumb starts at pane top");
         Assert (Info_Layout.Scrollbar_Width = 6, "info pane scrollbar has stable width");
         Assert (Info_Layout.Scrollbar_Height < Info_Layout.Height, "overflow scrollbar thumb is shortened");
         Frame := Files.Rendering.Build_Frame_Commands (Overflow, Width => 1000, Height => 800, Line_Height => 20);
         declare
            Found_Track : Boolean := False;
            Found_Thumb : Boolean := False;
            Found_Grip  : Boolean := False;
         begin
            for Command of Frame.Rectangles loop
               if Command.X = Info_Layout.Scrollbar_X
                 and then Command.Y = Info_Layout.Scrollbar_Y
                 and then Command.Width = Info_Layout.Scrollbar_Width
                 and then Command.Height = Info_Layout.Height
                 and then Command.Color = Files.Rendering.Border_Color
               then
                  Found_Track := True;
               elsif Command.X = Info_Layout.Scrollbar_X
                 and then Command.Y = Info_Layout.Scrollbar_Thumb_Y
                 and then Command.Width = Info_Layout.Scrollbar_Width
                 and then Command.Height = Info_Layout.Scrollbar_Height
                 and then Command.Color = Files.Rendering.Selection_Color
               then
                  Found_Thumb := True;
               elsif Command.X = Info_Layout.Scrollbar_X + 1
                 and then Command.Width = Info_Layout.Scrollbar_Width - 2
                 and then Command.Color = Files.Rendering.Muted_Text_Color
               then
                  Found_Grip := True;
               end if;
            end loop;

            Assert (Found_Track, "frame includes info pane scrollbar track");
            Assert (Found_Thumb, "frame includes info pane scrollbar thumb");
            Assert (Found_Grip, "frame includes info pane scrollbar grip");
         end;

         Files.Model.Scroll_Info_Pane (Model, Lines => 3);
         Overflow := Files.Rendering.Build_Snapshot (Model);
         for Index in 1 .. 5 loop
            Overflow.Selected_Info.Append (Overflow.Selected_Info.Element (1));
         end loop;

         Info_Layout := Files.Rendering.Calculate_Info_Pane_Layout (Overflow, Layout, Line_Height => 20);
         Assert (Overflow.Info_Pane_Scroll_Lines = 3, "snapshot captures info pane scroll lines");
         Assert (Info_Layout.Scroll_Lines = 3, "info pane layout applies scroll lines");
         Assert (Info_Layout.Scroll_Pixels = 60, "info pane layout converts scroll lines to pixels");
         Assert (Info_Layout.Scrollbar_Thumb_Y > Info_Layout.Scrollbar_Y, "scroll moves scrollbar thumb down");
         Frame := Files.Rendering.Build_Frame_Commands (Overflow, Width => 1000, Height => 800, Line_Height => 20);
         declare
            Found_Visible_Row : Boolean := False;
         begin
            for Command of Frame.Text loop
               if Command.X = Layout.Main_Width + 10
                 and then Command.Y > Info_Layout.Y
                 and then Command.Y < Info_Layout.Y + Info_Layout.Height
               then
                  Found_Visible_Row := True;
               end if;
            end loop;

            Assert (Found_Visible_Row, "frame still renders visible scrolled info rows");
         end;

         Overflow.Info_Pane_Scroll_Lines := 999;
         Info_Layout := Files.Rendering.Calculate_Info_Pane_Layout (Overflow, Layout, Line_Height => 20);
         Assert (Info_Layout.Scroll_Lines = 126, "info pane layout clamps excessive scroll lines");
         Assert
           (Overflow.Info_Pane_Scroll_Lines = 999,
            "info pane layout clamp does not mutate snapshot scroll request");
         Assert
           (Files.Model.Info_Pane_Scroll_Lines (Model) = 3,
            "info pane layout clamp does not mutate model scroll request");

         declare
            Zero_Width_Layout : constant Files.Rendering.Layout_Metrics :=
              (Width             => 0,
               Height            => 120,
               Toolbar_Height    => 0,
               Bottom_Bar_Height => 0,
               Main_X            => 0,
               Main_Y            => 0,
               Main_Width        => 0,
               Main_Height       => 120,
               Info_Pane_Width   => 0,
               Command_X         => 0,
               Command_Y         => 0,
               Command_Width     => 0,
               Command_Height    => 0);
            Zero_Width_Info : constant Files.Rendering.Info_Pane_Layout :=
              Files.Rendering.Calculate_Info_Pane_Layout
                (Overflow, Zero_Width_Layout, Line_Height => 20);
         begin
            Assert (Zero_Width_Info.X = 0, "zero-width info pane returns empty layout");
            Assert (not Zero_Width_Info.Scrollbar_Visible, "zero-width info pane does not expose scrollbar");
            Assert (Zero_Width_Info.Scrollbar_Width = 0, "zero-width info pane reports no scrollbar width");
         end;
      end;

      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Assert (Palette_Layout.X = 100 and then Palette_Layout.Y = 20, "palette layout uses centered rectangle");
      Assert (Palette_Layout.Search_X = 108, "palette search input is padded from panel edge");
      Assert (Palette_Layout.Search_Y = 28, "palette search input has top panel padding");
      Assert (Palette_Layout.Search_Width = 784, "palette search input leaves horizontal panel padding");
      Assert (Palette_Layout.Search_Height = 36, "palette search input includes vertical padding");
      Assert (Palette_Layout.Results_X = 108, "palette results are padded from panel edge");
      Assert (Palette_Layout.Results_Y = 72, "palette results follow padded search input with a gap");
      Assert (Palette_Layout.Results_Width = 784, "palette results leave horizontal panel padding");
      Assert (Palette_Layout.Results_Height = 580, "palette results fill remaining padded palette height");
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (Natural (Palette_Rows.Length) = 1, "palette result layout includes matching result");
      Assert (Palette_Rows.Element (1).X = 108, "palette result row uses padded palette x position");
      Assert (Palette_Rows.Element (1).Y = 72, "palette first result row follows padded search input");
      Assert (Palette_Rows.Element (1).Width = 784, "palette result row fills padded palette width");
      Assert (Palette_Rows.Element (1).Height = 48, "palette result row includes vertical padding");
      Assert (Palette_Rows.Element (1).Selected, "palette result row captures selection state");
      Assert (not Palette_Rows.Element (1).Enabled, "palette result row captures disabled state");
      declare
         Huge_Layout  : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Width => Natural'Last, Height => Natural'Last, Line_Height => Positive'Last);
         Huge_Palette : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Huge_Layout, Line_Height => Positive'Last);
         Extreme_Layout : constant Files.Rendering.Layout_Metrics :=
           (Width             => Natural'Last,
            Height            => Natural'Last,
            Toolbar_Height    => 0,
            Bottom_Bar_Height => 0,
            Main_X            => Natural'Last / 2,
            Main_Y            => Natural'Last / 2,
            Main_Width        => Natural'Last / 2,
            Main_Height       => Natural'Last / 2,
            Info_Pane_Width   => Natural'Last / 2,
            Command_X         => 0,
            Command_Y         => 0,
            Command_Width     => 0,
            Command_Height    => 0);
         Extreme_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
         Extreme_Main     : Files.Rendering.Main_View_Layout;
         Extreme_Info     : Files.Rendering.Info_Pane_Layout;
      begin
         Assert (Huge_Layout.Toolbar_Height = Natural'Last, "layout saturates huge toolbar line height");
         Assert (Huge_Layout.Main_Height = 0, "layout clamps main height after saturated chrome");
         Assert (Huge_Palette.Results_Y = Natural'Last, "palette layout saturates huge result origin");
         Assert (Huge_Palette.Row_Height = Natural'Last, "palette row height saturates huge line height");
         Extreme_Snapshot.Main_View_Scroll_Lines := Natural'Last;
         Extreme_Snapshot.Info_Pane_Open := True;
         Extreme_Snapshot.Info_Pane_Scroll_Lines := Natural'Last;
         Extreme_Snapshot.Selected_Info.Append (Files.Rendering.Info_Snapshot'(others => <>));
         Extreme_Main :=
           Files.Rendering.Calculate_Main_View_Layout
             (Extreme_Snapshot, Extreme_Layout, Line_Height => Positive'Last);
         Extreme_Info :=
           Files.Rendering.Calculate_Info_Pane_Layout
             (Extreme_Snapshot, Extreme_Layout, Line_Height => Positive'Last);
         Assert (Extreme_Main.Content_Height = Natural'Last, "main-view content height saturates");
         Assert
           (Extreme_Main.Scroll_Pixels =
            Extreme_Main.Content_Height - (Extreme_Layout.Main_Height - 16),
            "main-view scroll pixels clamp to maximum scroll");
         Assert
           (Extreme_Main.Scrollbar_Track_Height = Extreme_Layout.Main_Height - 16,
            "extreme main-view scrollbar track follows padded content height");
         Assert (Extreme_Main.Scrollbar_Visible, "main-view scrollbar stays visible at extreme size");
         Assert
           (Extreme_Main.Scrollbar_Thumb_Y >= Extreme_Layout.Main_Y,
            "main-view thumb y stays inside track start");
         Assert
           (Extreme_Main.Scrollbar_Thumb_Y
            <= Extreme_Layout.Main_Y + Extreme_Layout.Main_Height - Extreme_Main.Scrollbar_Height,
            "main-view thumb y stays inside track end");
         Assert (Extreme_Info.Content_Height = Natural'Last, "info-pane content height saturates");
         Assert
           (Extreme_Info.Scroll_Pixels = Extreme_Info.Content_Height - Extreme_Layout.Main_Height,
            "info-pane scroll pixels clamp to maximum scroll");
         Assert (Extreme_Info.Scrollbar_Visible, "info-pane scrollbar stays visible at extreme size");
         Assert
           (Extreme_Info.Scrollbar_Thumb_Y >= Extreme_Layout.Main_Y,
            "info-pane thumb y stays inside track start");
         Assert
           (Extreme_Info.Scrollbar_Thumb_Y
            <= Extreme_Layout.Main_Y + Extreme_Layout.Main_Height - Extreme_Info.Scrollbar_Height,
            "info-pane thumb y stays inside track end");
         declare
            Extreme_Frame : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Extreme_Snapshot,
                 Width       => Natural'Last,
                 Height      => Natural'Last,
                 Line_Height => Positive'Last);
            Details_Extreme : Files.Rendering.View_Snapshot := Extreme_Snapshot;
            Details_Frame   : Files.Rendering.Frame_Commands;
            Settings_Extreme : Files.Rendering.View_Snapshot := Extreme_Snapshot;
            Settings_Frame   : Files.Rendering.Frame_Commands;
         begin
            Assert
              (Extreme_Frame.Layout.Toolbar_Height = Natural'Last,
               "frame construction saturates huge line height");
            Details_Extreme.View_Mode := Files.Types.Details;
            Details_Frame :=
              Files.Rendering.Build_Frame_Commands
                (Details_Extreme,
                 Width       => Natural'Last,
                 Height      => Natural'Last,
                 Line_Height => Positive'Last);
            Assert
              (Details_Frame.Layout.Toolbar_Height = Natural'Last,
               "details frame construction saturates huge line height");
            Settings_Extreme.Settings_Pane_Open := True;
            Settings_Extreme.Settings_Field_Index := 1;
            Settings_Extreme.Settings_Field_Help := To_Unbounded_String ("field help");
            Settings_Extreme.Settings_Control_Options := To_Unbounded_String ("field options");
            Settings_Frame :=
              Files.Rendering.Build_Frame_Commands
                (Settings_Extreme,
                 Width       => Natural'Last,
                 Height      => Natural'Last,
                 Line_Height => Positive'Last);
            Assert
              (Settings_Frame.Layout.Toolbar_Height = Natural'Last,
               "settings frame construction saturates huge line height");
         end;
      end;
      Assert
        (Files.Rendering.Command_Result_At
           (Palette_Rows, X => Palette_Layout.Results_X + 1, Y => Palette_Layout.Results_Y + 1) = 1,
         "palette hit test returns result index");
      Assert
        (Files.Rendering.Command_Result_At
           (Palette_Rows, X => Palette_Layout.Results_X - 1, Y => Palette_Layout.Results_Y + 1) = 0,
         "palette hit test rejects x before result row");
      Assert
        (Files.Rendering.Command_Result_At
           (Palette_Rows,
            X => Palette_Layout.Results_X + 1,
            Y => Palette_Layout.Results_Y + Palette_Layout.Row_Height + 1) = 0,
         "palette hit test rejects y below result row");
      Files.Model.Close_Command_Palette (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (Natural (Palette_Rows.Length) = 0, "closed palette has no result row layout");
      Assert
        (Files.Rendering.Command_Result_At (Palette_Rows, X => 104, Y => 45) = 0,
         "closed palette hit test returns no result");

      Roots.Append (To_Unbounded_String ("/"));
      Roots.Append (To_Unbounded_String ("/mnt/data"));
      Roots.Append (To_Unbounded_String ("/tmp"));
      Files.Model.Open_Root_Selector (Model, Roots);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Root_Layout := Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Root_Layout.X = 0, "root selector starts at left edge");
      Assert (Root_Layout.Y = Layout.Toolbar_Height, "root selector appears below toolbar");
      Assert (Root_Layout.Width = 360, "root selector has deterministic dropdown width");
      Assert (Root_Layout.Height = 172, "root selector height follows padded root count");
      Assert (Root_Layout.Row_Height = 52, "root selector row height fits toolbar-sized icons");
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Natural (Root_Rows.Length) = 3, "root selector lays out each visible root");
      Assert (Snapshot.Root_Selected_Index = 1, "root snapshot captures first selected row");
      Assert (Root_Rows.Element (1).Root_Index = 1, "root selector row preserves root index");
      Assert (Root_Rows.Element (1).Selected, "root selector layout marks selected row");
      Assert (not Root_Rows.Element (2).Selected, "root selector layout leaves unselected row normal");
      Assert (Root_Rows.Element (1).X = Root_Layout.X + 8, "root selector row starts after menu padding");
      Assert (Root_Rows.Element (1).Y = Root_Layout.Y + 8, "root selector first row starts after menu padding");
      Assert (Root_Rows.Element (2).Y = Root_Layout.Y + 60, "root selector rows advance by padded row height");
      Assert (Root_Rows.Element (3).Width = Root_Layout.Width - 16, "root selector rows respect menu padding");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => 10, Y => Root_Layout.Y + 10) = 1,
         "root selector hit test returns first root index");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => 10, Y => Root_Layout.Y + 62) = 2,
         "root selector hit test returns second root index");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => Root_Layout.Width, Y => Root_Layout.Y + 5) = 0,
         "root selector hit test rejects x after row");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => 4, Y => Root_Layout.Y + Root_Layout.Height) = 0,
         "root selector hit test rejects y after dropdown");

      Roots.Append (To_Unbounded_String ("/var"));
      Roots.Append (To_Unbounded_String ("/opt"));
      Roots.Append (To_Unbounded_String ("/srv"));
      Files.Model.Open_Root_Selector (Model, Roots);
      Files.Model.Set_Root_Selected_Index (Model, 5);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Root_Layout.Height := 172;
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Natural (Root_Rows.Length) = 3, "root selector clips long root lists to visible rows");
      Assert (Root_Rows.Element (1).Root_Index = 3, "root selector scrolls selected root into view");
      Assert (Root_Rows.Element (3).Root_Index = 5, "root selector includes selected row on last visible slot");
      Assert (Root_Rows.Element (3).Selected, "root selector marks selected paged row");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => 10, Y => Root_Layout.Y + 114) = 5,
         "paged root selector hit test returns absolute root index");
      Snapshot.Root_Selected_Index := Natural'Last;
      Root_Layout.Height := 0;
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert
        (Natural (Root_Rows.Length) = 0,
         "zero-height root selector clamps stale selected index without overflow");
      Root_Layout.Height := 172;
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Natural (Root_Rows.Length) = 3, "stale root selection still lays out visible rows");
      Assert (Root_Rows.Element (3).Root_Index = Natural (Snapshot.Root_Paths.Length), "stale root selection clamps");
      Assert (Root_Rows.Element (3).Selected, "clamped stale root selection marks final row");
      Files.Model.Close_Root_Selector (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Root_Layout := Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height => 20);
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Root_Layout.Height = 0, "closed root selector has zero dropdown height");
      Assert (Natural (Root_Rows.Length) = 0, "closed root selector has no row layout");
      Assert
        (Files.Rendering.Root_Path_At (Root_Rows, X => 4, Y => 45) = 0,
         "closed root selector hit test returns no root");

      Small_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Natural (Small_Layout.Length) = 3, "small-icons layout includes each visible item");
      Assert (Small_Layout.Element (1).Icon_Size = 20, "small-icons icon equals line height");
      Assert (Small_Layout.Element (1).X > Layout.Main_X, "small-icons layout is padded from main edge");
      Assert (Small_Layout.Element (1).Y > Layout.Main_Y, "small-icons layout is padded below main edge");
      Assert
        (Small_Layout.Element (1).Icon_Y = Small_Layout.Element (1).Y + 4,
         "small-icons content has vertical padding inside hover box");
      Assert
        (Small_Layout.Element (1).Text_Y = Small_Layout.Element (1).Y + 4,
         "small-icons text has vertical padding inside selection box");
      Assert (Small_Layout.Element (2).X = 196, "small-icons layout leaves a gutter between cells");
      Assert (Small_Layout.Element (2).Y = Layout.Main_Y + 8, "small-icons layout stays on first padded grid row");
      Assert
        (Files.Rendering.Item_At (Small_Layout, X => 1, Y => Layout.Main_Y + 1) = 0,
         "small-icons hit test rejects padded outer margin");
      Assert
        (Files.Rendering.Item_At (Small_Layout, X => 9, Y => Layout.Main_Y + 9) = 1,
         "small-icons hit test returns first visible item");
      Assert
        (Files.Rendering.Item_At (Small_Layout, X => 189, Y => Layout.Main_Y + 9) = 0,
         "small-icons hit test rejects horizontal gutter between items");
      Assert
        (Files.Rendering.Item_At (Small_Layout, X => 197, Y => Layout.Main_Y + 9) = 2,
         "small-icons hit test returns second visible item");
      Assert
        (Files.Rendering.Item_At (Small_Layout, X => 1, Y => Layout.Main_Y - 1) = 0,
         "small-icons hit test rejects point above main view");

      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Large_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Large_Layout.Element (1).Icon_Size = 60, "large-icons layout uses larger icons");
      Assert (Large_Layout.Element (1).Icon_X = 48, "large-icons icon is centered in the padded cell");
      Assert
        (Large_Layout.Element (1).Icon_Y = Large_Layout.Element (1).Y + 4,
         "large-icons content has vertical padding inside hover box");
      Assert
        (Large_Layout.Element (1).Text_X > Large_Layout.Element (1).X,
         "large-icons item name is centered beneath the icon");
      Assert
        (Large_Layout.Element (1).Text_Y = Large_Layout.Element (1).Icon_Y + Large_Layout.Element (1).Icon_Size + 4,
         "large-icons item name has padding below the icon");
      Assert (Large_Layout.Element (2).X = 156, "large-icons layout leaves a gutter between cells");
      Assert
        (Files.Rendering.Item_At (Large_Layout, X => 9, Y => Layout.Main_Y + 9) = 1,
         "large-icons hit test returns first visible item");
      Assert
        (Files.Rendering.Item_At (Large_Layout, X => 149, Y => Layout.Main_Y + 9) = 0,
         "large-icons hit test rejects horizontal gutter between items");
      Assert
        (Files.Rendering.Item_At (Large_Layout, X => 157, Y => Layout.Main_Y + 9) = 2,
         "large-icons hit test returns second visible item");

      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Details_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Details_Layout.Element (1).X = Layout.Main_X + 8, "details rows are padded from main edge");
      Assert (Details_Layout.Element (1).Width = Layout.Main_Width - 16, "details rows leave horizontal padding");
      Assert (Details_Layout.Element (1).Y = Layout.Main_Y + 36, "details rows start below padded header");
      Assert (Details_Layout.Element (2).Y = Layout.Main_Y + 68, "details rows advance by padded row height");
      Assert (Details_Layout.Element (1).Height = 28, "details row height leaves a separator gap");
      Assert (Details_Layout.Element (1).Icon_Size = 20, "details row has one icon");
      Assert (Details_Layout.Element (1).Icon_X = Layout.Main_X + 12, "details icon has row padding");
      Assert (Details_Layout.Element (1).Name_X = Layout.Main_X + 44, "details name column has cell padding");
      Assert (Details_Layout.Element (1).Name_Width = 274, "details name column keeps padded priority width");
      Assert (Details_Layout.Element (1).Modified_X = 318, "details modified column follows name");
      Assert (Details_Layout.Element (1).Modified_Width = 193, "details modified column is bounded");
      Assert (Details_Layout.Element (1).Size_X = 511, "details size column follows modified");
      Assert (Details_Layout.Element (1).Size_Width = 82, "details size column has unit-aware width");
      Assert (Details_Layout.Element (1).Filetype_X = 593, "details filetype column follows size");
      Assert (Details_Layout.Element (1).Filetype_Width = 145, "details filetype column has stable width");
      Assert
        (Files.Rendering.Item_At (Details_Layout, X => 9, Y => Layout.Main_Y + 9) = 0,
         "details hit test ignores header row");
      Assert
        (Files.Rendering.Item_At (Details_Layout, X => 9, Y => Layout.Main_Y + 37) = 1,
         "details hit test returns first visible row below header");
      Assert
        (Files.Rendering.Item_At (Details_Layout, X => 9, Y => Layout.Main_Y + 69) = 2,
         "details hit test returns second visible row");
      Assert
        (Files.Rendering.Item_At (Details_Layout, X => Layout.Main_Width, Y => Layout.Main_Y + 21) = 0,
         "details hit test rejects point after row width");
      declare
         Header_Y : constant Natural := Layout.Main_Y + 9;
         Header_Action : Files.Events.Input_Action;
         Header_Result : Files.Controller.Controller_Result;
      begin
         Assert
           (Files.Rendering.Details_Header_Command_At
              (Snapshot,
               Layout,
               X           => Details_Layout.Element (1).Name_X,
               Y           => Header_Y,
               Line_Height => 20) = Files.Commands.Sort_By_Name_Command,
            "details name header maps to sort-by-name command");
         Assert
           (Files.Rendering.Details_Header_Command_At
              (Snapshot,
               Layout,
               X           => Details_Layout.Element (1).Modified_X + 6,
               Y           => Header_Y,
               Line_Height => 20) = Files.Commands.Sort_By_Changed_Command,
            "details changed header maps to sort-by-changed command");
         Assert
           (Files.Rendering.Details_Header_Command_At
              (Snapshot,
               Layout,
               X           => Details_Layout.Element (1).Size_X + 6,
               Y           => Header_Y,
               Line_Height => 20) = Files.Commands.Sort_By_Size_Command,
            "details size header maps to sort-by-size command");
         Assert
           (Files.Rendering.Details_Header_Command_At
              (Snapshot,
               Layout,
               X           => Details_Layout.Element (1).Filetype_X + 6,
               Y           => Header_Y,
               Line_Height => 20) = Files.Commands.Sort_By_Type_Command,
            "details type header maps to sort-by-type command");

         Header_Action :=
           Click_Action
             (Snapshot,
              X           => Details_Layout.Element (1).Size_X + 6,
              Y           => Header_Y,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);
         Assert (Header_Action.Kind = Files.Events.Command_Input_Action, "details header click translates to command");
         Assert
           (Header_Action.Command = Files.Commands.Sort_By_Size_Command,
            "details size header click dispatches sort-by-size command");
         Header_Result :=
           Files.Controller.Execute_Command
             (Header_Action.Command, Model, Files.Settings.Default_Settings);
         Assert (Header_Result.Command = Files.Commands.Sort_By_Size_Command, "details header sort command executes");
         Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Size, "details header click changes sort field");
         Header_Result :=
           Files.Controller.Execute_Command
             (Files.Commands.Sort_By_Name_Command, Model, Files.Settings.Default_Settings);
         Assert (Header_Result.Command = Files.Commands.Sort_By_Name_Command, "details header test restores name sort");
      end;

      declare
         Edge_Items : Files.Rendering.Item_Layout_Vectors.Vector;
         Edge_Rows  : Files.Rendering.Command_Result_Layout_Vectors.Vector;
         Edge_Roots : Files.Rendering.Root_Path_Layout_Vectors.Vector;
      begin
         Edge_Items.Append
           (Files.Rendering.Item_Layout'
              (Visible_Index => 7,
               X             => Natural'Last - 1,
               Y             => Natural'Last - 1,
               Width         => 2,
               Height        => 2,
               others        => <>));
         Edge_Rows.Append
           (Files.Rendering.Command_Result_Layout'
              (Result_Index => 8,
               X            => Natural'Last - 1,
               Y            => Natural'Last - 1,
               Width        => 2,
               Height       => 2,
               others       => <>));
         Edge_Roots.Append
           (Files.Rendering.Root_Path_Layout'
              (Root_Index => 9,
               X          => Natural'Last - 1,
               Y          => Natural'Last - 1,
               Width      => 2,
               Height     => 2,
               others     => <>));

         Assert
           (Files.Rendering.Item_At (Edge_Items, X => Natural'Last, Y => Natural'Last) = 7,
            "item hit test handles saturated lower-right coordinates");
         Assert
           (Files.Rendering.Command_Result_At (Edge_Rows, X => Natural'Last, Y => Natural'Last) = 8,
            "palette hit test handles saturated lower-right coordinates");
         Assert
           (Files.Rendering.Root_Path_At (Edge_Roots, X => Natural'Last, Y => Natural'Last) = 9,
            "root hit test handles saturated lower-right coordinates");
      end;

      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         declare
            Item : Files.Rendering.Item_Snapshot := Snapshot.Items.Element (Positive (Index));
         begin
            Item.Selected := False;
            Snapshot.Items.Replace_Element (Positive (Index), Item);
         end;
      end loop;
      Snapshot.Selected_Count := 0;

      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      declare
         Found_Modified : Boolean := False;
         Found_Missing_Size : Boolean := False;
         Found_Header_Name : Boolean := False;
         Found_Header_Size : Boolean := False;
         Found_Header_Border : Boolean := False;
         Found_Header_Accent : Boolean := False;
         Found_Row_Divider : Boolean := False;
         Found_Row_Name : Boolean := False;
         Found_Header_A11y : Boolean := False;
         Found_Row_A11y : Boolean := False;
         Found_Row_Name_Line_Height : Boolean := False;
         Alternating_Row_Index : Natural := 0;
         Separator_After_Alternating_Row_Index : Natural := 0;
         Found_Separator_Stops_At_Last_Row : Boolean := False;
         Rectangle_Index : Natural := 0;
         Found_Details_Icon_Command : Boolean := False;
         Frame_Details_Layout : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Frame.Layout, Line_Height => 20);
         Details_Header_Y : constant Natural := Frame_Details_Layout.Element (1).Y - 28;
      begin
         for Command of Frame.Rectangles loop
            Rectangle_Index := Rectangle_Index + 1;
            if Command.X = Frame_Details_Layout.Element (1).X
              and then Command.Y = Details_Header_Y
              and then Command.Width > 0
              and then Command.Height > 0
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Header_Border := True;
            elsif Command.X = Frame_Details_Layout.Element (1).X
              and then Command.Y = Details_Header_Y + 26
              and then Command.Width = Frame_Details_Layout.Element (1).Width
              and then Command.Height = 2
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Header_Accent := True;
            elsif Command.X = Frame_Details_Layout.Element (1).X
              and then Command.Y =
                Frame_Details_Layout.Element (1).Y + Frame_Details_Layout.Element (1).Height - 1
              and then Command.Width = Frame_Details_Layout.Element (1).Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Row_Divider := True;
            elsif Command.X = Frame_Details_Layout.Element (2).X
              and then Command.Y = Frame_Details_Layout.Element (2).Y
              and then Command.Width = Frame_Details_Layout.Element (2).Width
              and then Command.Height = Frame_Details_Layout.Element (2).Height
              and then Command.Color = Files.Rendering.Detail_Alternate_Color
            then
               Alternating_Row_Index := Rectangle_Index;
            elsif Command.X =
                (if Frame_Details_Layout.Element (2).Modified_X > 2
                 then Frame_Details_Layout.Element (2).Modified_X - 2
                 else 0)
              and then Command.Y <= Frame_Details_Layout.Element (2).Y
              and then Command.Y + Command.Height >=
                Frame_Details_Layout.Element (2).Y + Frame_Details_Layout.Element (2).Height
              and then Command.Width = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Separator_After_Alternating_Row_Index := Rectangle_Index;
               if Command.Y = Details_Header_Y
                 and then Command.Height =
                   Frame_Details_Layout.Last_Element.Y - Details_Header_Y + Frame_Details_Layout.Last_Element.Height - 1
               then
                  Found_Separator_Stops_At_Last_Row := True;
               end if;
            end if;
         end loop;

         for Command of Frame.Icons loop
            if Command.X = Frame_Details_Layout.Element (1).Icon_X
              and then Command.Y = Frame_Details_Layout.Element (1).Icon_Y
              and then Command.Size = Frame_Details_Layout.Element (1).Icon_Size
            then
               Found_Details_Icon_Command := True;
            end if;
         end loop;

         for Command of Frame.Text loop
            if Command.X = Frame_Details_Layout.Element (1).Modified_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("status.missing_metadata")
            then
               Found_Modified := True;
            elsif Command.X = Frame_Details_Layout.Element (1).Size_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("status.missing_metadata")
            then
               Found_Missing_Size := True;
            elsif Command.X = Frame_Details_Layout.Element (1).Name_X
              and then To_String (Command.Text) =
                Files.Localization.Text ("details.name") & " " & Files.Localization.Text ("sort.direction.ascending")
            then
               Found_Header_Name := True;
            elsif Command.X = Frame_Details_Layout.Element (1).Size_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("details.size")
            then
               Found_Header_Size := True;
            elsif Command.X = Frame_Details_Layout.Element (1).Name_X
              and then To_String (Command.Text) = "Alpha.txt"
            then
               Found_Row_Name := True;
               Found_Row_Name_Line_Height := Command.Height = 20;
            end if;
         end loop;

         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_Table_Row
              and then Node.X = Frame_Details_Layout.Element (1).X
              and then Node.Y = Details_Header_Y
              and then To_String (Node.Name) = Files.Localization.Text ("details.header")
              and then To_String (Node.Description) =
                Files.Localization.Text ("details.name") & ", " &
                Files.Localization.Text ("details.modified") & ", " &
                Files.Localization.Text ("details.size") & ", " &
                Files.Localization.Text ("details.filetype")
            then
               Found_Header_A11y := True;
            elsif Node.Role = Files.Rendering.Role_Table_Row
              and then Node.X = Frame_Details_Layout.Element (1).X
              and then Node.Y = Frame_Details_Layout.Element (1).Y
              and then To_String (Node.Name) = "Alpha.txt"
              and then To_String (Node.Description) =
                Files.Localization.Text ("details.modified") & ": " &
                Files.Localization.Text ("status.missing_metadata") & ", " &
                Files.Localization.Text ("details.size") & ": , " &
                Files.Localization.Text ("details.filetype") & ": " &
                Files.Localization.Text ("info.kind.text")
            then
               Found_Row_A11y := True;
            end if;
         end loop;

         Assert (Found_Modified, "details frame includes modified column text");
         Assert (not Found_Missing_Size, "details frame leaves missing size blank");
         Assert (Found_Header_Name, "details frame includes localized name header");
         Assert (Found_Header_Size, "details frame includes localized size header");
         Assert (Found_Header_Border, "details frame includes header band");
         Assert (Found_Header_Accent, "details frame includes header accent rule");
         Assert (Found_Row_Divider, "details frame includes row divider");
         Assert (Alternating_Row_Index > 0, "details frame includes alternating row fill");
         Assert
           (Separator_After_Alternating_Row_Index > Alternating_Row_Index,
            "details frame redraws column separators after alternating row fills");
         Assert (Found_Separator_Stops_At_Last_Row, "details frame stops column separators at last visible row");
         Assert (Found_Row_Name, "details frame includes row filename text");
         Assert (Found_Row_Name_Line_Height, "details row filename text uses line-height glyph box");
         Assert (Found_Details_Icon_Command, "details frame emits resolved item icon command");
         Assert (Found_Header_A11y, "details frame exposes accessible table header");
         Assert (Found_Row_A11y, "details frame exposes accessible table row columns");
      end;
      declare
         Folder_Details : Files.Rendering.View_Snapshot;
         Folder_Frame   : Files.Rendering.Frame_Commands;
         Folder_Layout  : Files.Rendering.Item_Layout_Vectors.Vector;
         Found_Folder_Icon : Boolean := False;
         Found_Old_Folder_Square : Boolean := False;
      begin
         Folder_Details.View_Mode := Files.Types.Details;
         Folder_Details.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name            => To_Unbounded_String ("src"),
               Filetype        => To_Unbounded_String ("inode/directory"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.directory")),
               Icon_Id         => To_Unbounded_String ("folder"),
               Kind            => Files.Types.Directory_Item,
               Visible_Index   => 1,
               others          => <>));
         Folder_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Folder_Details, Width => 800, Height => 300, Line_Height => 20);
         Folder_Layout :=
           Files.Rendering.Calculate_Item_Layout
             (Folder_Details, Folder_Frame.Layout, Line_Height => 20);

         for Command of Folder_Frame.Icons loop
            if To_String (Command.Icon_Id) = "folder"
              and then Command.X = Folder_Layout.Element (1).Icon_X
              and then Command.Y = Folder_Layout.Element (1).Icon_Y
              and then Command.Size = Folder_Layout.Element (1).Icon_Size
            then
               Found_Folder_Icon := True;
            end if;
         end loop;

         for Command of Folder_Frame.Rectangles loop
            if Command.X = Folder_Layout.Element (1).Icon_X
              and then Command.Y = Folder_Layout.Element (1).Icon_Y
              and then Command.Width = Folder_Layout.Element (1).Icon_Size
              and then Command.Height = Folder_Layout.Element (1).Icon_Size
              and then Command.Color = Files.Rendering.Icon_Directory_Color
            then
               Found_Old_Folder_Square := True;
            end if;
         end loop;

         Assert (Found_Folder_Icon, "details frame renders folder icon asset");
         Assert (not Found_Old_Folder_Square, "details frame does not render folder as a plain square");
      end;
      declare
         Empty_Details : Files.Rendering.View_Snapshot := Snapshot;
         Empty_Frame   : Files.Rendering.Frame_Commands;
         Found_Empty_Header_Name : Boolean := False;
         Found_Empty_Header_Modified : Boolean := False;
         Found_Empty_Header_Size : Boolean := False;
         Found_Empty_Header_Filetype : Boolean := False;
         Found_Empty_Header_Band : Boolean := False;
         Found_Empty_Modified_Separator : Boolean := False;
         Found_Empty_Size_Separator : Boolean := False;
         Found_Empty_Filetype_Separator : Boolean := False;
         Found_Empty_Header_A11y : Boolean := False;
         Empty_Header_X : Natural := 0;
         Empty_Header_Y : Natural := 0;
         Empty_Header_W : Natural := 0;
         Empty_Header_H : Natural := 0;
         Empty_Name_X : Natural := 0;
         Empty_Modified_X : Natural := 0;
         Empty_Size_X : Natural := 0;
         Empty_Filetype_X : Natural := 0;
      begin
         Empty_Details.Items.Clear;
         Empty_Details.Item_Count := 0;
         Empty_Details.Visible_Count := 0;
         Empty_Details.Selected_Count := 0;
         Empty_Details.View_Mode := Files.Types.Details;
         Empty_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Empty_Details, Width => 1000, Height => 800, Line_Height => 20);
         Empty_Header_X := Empty_Frame.Layout.Main_X + 8;
         Empty_Header_Y := Empty_Frame.Layout.Main_Y + 8;
         Empty_Header_W := Empty_Frame.Layout.Main_Width - 16;
         Empty_Header_H := 28;
         declare
            Header_Pad : constant Natural := 4;
            Icon_Gap   : constant Natural := 26;
            Available  : constant Natural := Empty_Header_W - Icon_Gap - Header_Pad * 2;
            Reserved_Name_W : constant Natural := Natural'Min (Available, 120);
            Metadata_W : constant Natural := Available - Reserved_Name_W;
            Type_W     : constant Natural := Natural'Min (180, Metadata_W / 4);
            Size_W     : constant Natural := Natural'Min (120, Metadata_W / 7);
            Modified_W : constant Natural := Natural'Min (220, Metadata_W / 3);
            Name_W     : constant Natural := Available - Type_W - Size_W - Modified_W;
         begin
            Empty_Name_X := Empty_Header_X + Header_Pad + Icon_Gap;
            Empty_Modified_X := Empty_Name_X + Name_W;
            Empty_Size_X := Empty_Modified_X + Modified_W;
            Empty_Filetype_X := Empty_Size_X + Size_W;
         end;

         for Command of Empty_Frame.Rectangles loop
            if Command.X = Empty_Header_X
              and then Command.Y = Empty_Header_Y
              and then Command.Width = Empty_Header_W
              and then Command.Height = Empty_Header_H
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Empty_Header_Band := True;
            elsif Command.X = Empty_Modified_X - 2
              and then Command.Y = Empty_Header_Y
              and then Command.Width = 1
              and then Command.Height = Empty_Header_H
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Empty_Modified_Separator := True;
            elsif Command.X = Empty_Size_X - 2
              and then Command.Y = Empty_Header_Y
              and then Command.Width = 1
              and then Command.Height = Empty_Header_H
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Empty_Size_Separator := True;
            elsif Command.X = Empty_Filetype_X - 2
              and then Command.Y = Empty_Header_Y
              and then Command.Width = 1
              and then Command.Height = Empty_Header_H
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Empty_Filetype_Separator := True;
            end if;
         end loop;

         for Command of Empty_Frame.Text loop
            if Command.X = Empty_Name_X + 6
              and then To_String (Command.Text) =
                Files.Localization.Text ("details.name") & " " & Files.Localization.Text ("sort.direction.ascending")
            then
               Found_Empty_Header_Name := True;
            elsif Command.X = Empty_Modified_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("details.modified")
            then
               Found_Empty_Header_Modified := True;
            elsif Command.X = Empty_Size_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("details.size")
            then
               Found_Empty_Header_Size := True;
            elsif Command.X = Empty_Filetype_X + 6
              and then To_String (Command.Text) = Files.Localization.Text ("details.filetype")
            then
               Found_Empty_Header_Filetype := True;
            end if;
         end loop;

         for Node of Empty_Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_Table_Row
              and then Node.X = Empty_Header_X
              and then Node.Y = Empty_Header_Y
              and then To_String (Node.Name) = Files.Localization.Text ("details.header")
            then
               Found_Empty_Header_A11y := True;
            end if;
         end loop;

         Assert (Found_Empty_Header_Band, "empty details frame includes header band");
         Assert (Found_Empty_Header_Name, "empty details frame includes localized name header");
         Assert (Found_Empty_Header_Modified, "empty details frame includes localized modified header");
         Assert (Found_Empty_Header_Size, "empty details frame includes localized size header");
         Assert (Found_Empty_Header_Filetype, "empty details frame includes localized filetype header");
         Assert (Found_Empty_Modified_Separator, "empty details frame includes modified column separator");
         Assert (Found_Empty_Size_Separator, "empty details frame includes size column separator");
         Assert (Found_Empty_Filetype_Separator, "empty details frame includes filetype column separator");
         Assert (Found_Empty_Header_A11y, "empty details frame exposes accessible table header");
      end;

      Toolbar := Files.UI.Calculate_Toolbar_Layout (1000);
      Assert (Toolbar.Left_X = 0, "toolbar left section starts at left edge");
      Assert (Toolbar.Left_Width = 240 and then Toolbar.Right_Width = 200, "toolbar has side sections");
      Assert (Toolbar.Middle_X = 240, "toolbar middle section follows left section");
      Assert (Toolbar.Middle_Width = 560, "toolbar middle section receives remaining width");
      Assert (Toolbar.Right_X = 800, "toolbar right section follows middle section");
      Assert
        (Files.UI.Toolbar_Command_At (10, 10, 1000, Line_Height => 20) = Files.Commands.Select_Drive_Command,
         "toolbar hit test maps drive selector to command");
      Assert
        (Files.UI.Toolbar_Command_At (40, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Home_Command,
         "toolbar hit test maps home button to command");
      Assert
        (Files.UI.Toolbar_Command_At (39, 10, 1000, Line_Height => 20) = Files.Commands.Select_Drive_Command,
         "toolbar hit test keeps drive button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (75, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Home_Command,
         "toolbar hit test keeps home button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (80, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Back_Command,
         "toolbar hit test maps back button to command");
      Assert
        (Files.UI.Toolbar_Command_At (119, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Back_Command,
         "toolbar hit test keeps back button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (120, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Forward_Command,
         "toolbar hit test maps forward button to command");
      Assert
        (Files.UI.Toolbar_Command_At (159, 10, 1000, Line_Height => 20) = Files.Commands.Navigate_Forward_Command,
         "toolbar hit test keeps forward button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (160, 10, 1000, Line_Height => 20) = Files.Commands.Create_File_Command,
         "toolbar hit test maps create button to command");
      Assert
        (Files.UI.Toolbar_Command_At (199, 10, 1000, Line_Height => 20) = Files.Commands.Create_File_Command,
         "toolbar hit test keeps create button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (200, 10, 1000, Line_Height => 20) =
         Files.Commands.Delete_Selected_Items_Command,
         "toolbar hit test maps delete button to command");
      Assert
        (Files.UI.Toolbar_Command_At (239, 10, 1000, Line_Height => 20) =
         Files.Commands.Delete_Selected_Items_Command,
         "toolbar hit test keeps delete button at fixed width");
      Assert
        (Files.UI.Toolbar_Command_At (240, 10, 1000, Line_Height => 20) =
         Files.Commands.Focus_Path_Input_Command,
         "toolbar hit test maps left section end to path input");
      Assert
        (Files.UI.Toolbar_Command_At (200, 10, 1009, Line_Height => 20) =
         Files.Commands.Delete_Selected_Items_Command,
         "toolbar hit test maps uneven trailing left pixels to delete");
      Assert
        (Files.UI.Toolbar_Command_At (250, 10, 1000, Line_Height => 20) =
         Files.Commands.Focus_Path_Input_Command,
         "toolbar hit test maps path input to command");
      Assert
        (Files.UI.Toolbar_Command_At (250, 5, 1000, Line_Height => 20) =
         Files.Commands.Focus_Path_Input_Command,
         "toolbar hit test includes path input top padding");
      Assert
        (Files.UI.Toolbar_Command_At (250, 38, 1000, Line_Height => 20) = Files.Commands.No_Command,
         "toolbar hit test ignores coordinates below padded path input");
      Assert
        (Files.UI.Toolbar_Command_At (850, 10, 1000, Line_Height => 20) =
         Files.Commands.Focus_Filter_Input_Command,
         "toolbar hit test maps filter input to command");
      Assert
        (Files.UI.Toolbar_Command_At (850, 5, 1000, Line_Height => 20) =
         Files.Commands.Focus_Filter_Input_Command,
         "toolbar hit test includes filter input top padding");
      Assert
        (Files.UI.Toolbar_Command_At (250, 40, 1000, Line_Height => 20) = Files.Commands.No_Command,
         "toolbar hit test ignores coordinates below toolbar");
      Assert
        (Files.UI.Toolbar_Command_At (Natural'Last, 10, Natural'Last, Line_Height => 20) =
         Files.Commands.No_Command,
         "toolbar hit test handles saturated coordinates without overflow");
      Assert
        (Files.UI.Toolbar_Command_At (239, 10, Natural'Last, Line_Height => 20) =
         Files.Commands.Delete_Selected_Items_Command,
         "toolbar hit test handles saturated left-section coordinates without overflow");
      declare
         Offset_Toolbar : constant Files.UI.Toolbar_Layout :=
           (Left_X       => Natural'Last - 1,
            Left_Width   => 12,
            Middle_X     => 0,
            Middle_Width => 0,
            Right_X      => 0,
            Right_Width  => 0);
      begin
         Assert
           (Files.UI.Toolbar_Left_Button_X (Offset_Toolbar, 5) = Natural'Last,
            "toolbar button helper saturates offset origins");
      end;

      Bottom_Bar := Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
      Assert (Bottom_Bar.View_Mode_X = 8, "bottom-bar view selector is padded from left edge");
      Assert (Bottom_Bar.View_Mode_Width = 206, "bottom-bar view selector sizes to short labels");
      Assert (Bottom_Bar.Small_Button_Width = 62, "bottom-bar small button sizes to short label");
      Assert (Bottom_Bar.Large_Button_X = 70, "bottom-bar large button follows compact small button");
      Assert (Bottom_Bar.Large_Button_Width = 62, "bottom-bar large button sizes to short label");
      Assert (Bottom_Bar.Details_Button_X = 132, "bottom-bar details button follows compact large button");
      Assert (Bottom_Bar.Details_Button_Width = 82, "bottom-bar details button sizes to short label");
      Assert (Bottom_Bar.Sort_Button_X = 214, "bottom-bar sort button follows compact view selector");
      Assert (Bottom_Bar.Sort_Button_Width = 106, "bottom-bar sort button fits longest field and arrow");
      Assert (Bottom_Bar.Info_X = 320, "bottom-bar information section follows sort button");
      Assert (Bottom_Bar.Info_Width = 620, "bottom-bar information section receives reclaimed width");
      Assert (Bottom_Bar.Info_Pane_X = 940, "bottom-bar info-pane toggle is right aligned inside padding");
      Assert (Bottom_Bar.Info_Pane_Width = 52, "bottom-bar info-pane toggle sizes to short info label");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Select_Small_Icons_Command,
         "bottom-bar hit test maps small-icons button to command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (90, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Select_Large_Icons_Command,
         "bottom-bar hit test maps large-icons button to command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (70, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Select_Large_Icons_Command,
         "bottom-bar hit test maps small-large separator to large-icons command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (142, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Select_Details_Command,
         "bottom-bar hit test maps details button to command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (132, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Select_Details_Command,
         "bottom-bar hit test maps large-details separator to details command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (950, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Toggle_Info_Pane_Command,
         "bottom-bar hit test maps info-pane toggle to command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (940, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Toggle_Info_Pane_Command,
         "bottom-bar hit test maps info-toggle separator to info-pane command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (300, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Toggle_Sort_Menu_Command,
         "bottom-bar hit test maps sort button to command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (320, 790, 1000, 800, Line_Height => 20) = Files.Commands.No_Command,
         "bottom-bar hit test ignores information section");
      Assert
        (Files.UI.Bottom_Bar_Command_At (214, 790, 1000, 800, Line_Height => 20) =
         Files.Commands.Toggle_Sort_Menu_Command,
         "bottom-bar hit test maps details-info separator ownership through sort button");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 760, 1000, 800, Line_Height => 20) = Files.Commands.No_Command,
         "bottom-bar hit test ignores coordinates above bottom bar");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 773, 1000, 800, Line_Height => 20) = Files.Commands.No_Command,
         "bottom-bar hit test ignores top padding inside bottom bar");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 800, 1000, 800, Line_Height => 20) = Files.Commands.No_Command,
         "bottom-bar hit test ignores coordinate at window bottom edge");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 801, 1000, 800, Line_Height => 20) = Files.Commands.No_Command,
         "bottom-bar hit test ignores coordinates below window");
      Assert
        (Files.UI.Bottom_Bar_Command_At (10, 0, 1000, 10, Line_Height => 20) = Files.Commands.No_Command,
         "short bottom-bar hit test ignores clipped top padding");
      Assert
        (Files.UI.Bottom_Bar_Command_At
           (Natural'Last, Natural'Last, Natural'Last, Natural'Last, Line_Height => 20) =
         Files.Commands.No_Command,
         "bottom-bar hit test handles saturated coordinates without overflow");
      Bottom_Bar := Files.UI.Calculate_Bottom_Bar_Layout (Natural'Last, Line_Height => Positive'Last);
      Assert (Bottom_Bar.Small_Button_Width > 0, "bottom-bar layout keeps a usable button at large line height");
      Assert
        (Files.UI.Bottom_Bar_Command_At
           (8, Natural'Last - 1, Natural'Last, Natural'Last, Line_Height => Positive'Last) =
         Files.Commands.Select_Small_Icons_Command,
         "bottom-bar hit test handles saturated line height without overflow");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 100, Height => 88, Line_Height => 20);
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (Palette_Layout.Results_Height = 10, "partial palette result area is represented");
      Assert (Palette_Rows.Is_Empty, "partial palette result area emits no clipped row");
      Files.Model.Set_Command_Palette_Query (Model, "");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Snapshot.Command_Palette_Result_Offset := 99;
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (Palette_Rows.Is_Empty, "partial palette layout keeps results hidden until a full row fits");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 100, Height => 88, Line_Height => 20);
      declare
         Found_Partial_Track : Boolean := False;
         Found_Partial_Thumb : Boolean := False;
      begin
         for Command of Frame.Rectangles loop
            if Command.X = Palette_Layout.Results_X + Palette_Layout.Results_Width - 6
              and then Command.Y = Palette_Layout.Results_Y
              and then Command.Width = 6
              and then Command.Height = Palette_Layout.Results_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Partial_Track := True;
            elsif Command.X = Palette_Layout.Results_X + Palette_Layout.Results_Width - 6
              and then Command.Y = Palette_Layout.Results_Y
              and then Command.Width = 6
              and then Command.Height = Palette_Layout.Results_Height
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Partial_Thumb := True;
            end if;
         end loop;

         Assert (not Found_Partial_Track, "partial palette without full rows omits scrollbar track");
         Assert (not Found_Partial_Thumb, "partial palette without full rows omits scrollbar thumb");
      end;
      Palette_Layout.Results_Height := 106;
      Snapshot.Command_Palette_Result_Offset := 99;
      Palette_Rows := Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Assert (Natural (Palette_Rows.Length) = 2, "palette layout only includes complete visible rows");
      Assert
        (Palette_Rows.Element (2).Height = Palette_Layout.Row_Height,
         "palette layout keeps final visible row complete");
      Assert
        (Palette_Rows.Element (1).Result_Index = Natural (Snapshot.Command_Palette_Results.Length) - 1,
         "palette stale offset clamps using complete visible rows");

      Files.Model.Open_Root_Selector (Model, Roots);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 100, Height => 125, Line_Height => 20);
      Root_Layout := Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height => 20);
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Root_Layout.Height = 57, "partial root selector height is represented");
      Assert (Root_Rows.Element (1).Height = 41, "partial root selector row is clipped");
      Files.Model.Set_Root_Selected_Index (Model, 3);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Root_Layout.Height := 125;
      Root_Rows := Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Assert (Natural (Root_Rows.Length) = 3, "root selector includes clipped extra visible row");
      Assert
        (Root_Rows.Element (1).Root_Index = 1,
         "root selector keeps selected clipped row visible without over-scrolling");
      Assert (Root_Rows.Element (3).Root_Index = 3, "root selector partial row preserves selected index");
      Assert (Root_Rows.Element (3).Height = 5, "root selector clips extra visible row");
      Assert (Root_Rows.Element (3).Selected, "root selector marks selected clipped row");

      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 40, Height => 50, Line_Height => 20);
      Assert (Layout.Main_Height = 0, "narrow layout saturates main height");
      Assert (Layout.Command_Width = 32, "narrow command palette keeps 80 percent width");
      Assert (Layout.Command_Height = 40, "short command palette keeps 80 percent height");
      Assert
        (Layout.Command_Y + Layout.Command_Height <= Layout.Height,
         "short command palette stays within the window height");
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Assert (Palette_Layout.Results_Height = 0, "short palette result area saturates");
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 40, Height => 10, Line_Height => 20);
      Assert
        (Layout.Command_Y + Layout.Command_Height <= Layout.Height,
         "tiny command palette stays within the window height");
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      Assert (Palette_Layout.Search_Height = 8, "tiny palette clamps search field to palette height");
      Assert (Palette_Layout.Results_Height = 0, "tiny palette has no negative result area");
      Assert
        (Palette_Layout.Results_Y = Palette_Layout.Search_Y + Palette_Layout.Search_Height + 8,
         "tiny palette results start after the clipped search field and padding gap");
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 40, Height => 50, Line_Height => 20);
      Root_Layout := Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Root_Layout.Width = 40, "narrow root selector stays within window width");
      Assert (Root_Layout.Height = 0, "narrow root selector respects zero main height");

      Details_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert
        (Details_Layout.Element (1).Width = Layout.Main_Width,
         "narrow details row stays within main width");
      Assert (Details_Layout.Element (1).Height = 0, "narrow details row height saturates");
      Assert (Details_Layout.Element (1).Icon_Size = 0, "narrow details icon size saturates");
      Assert (Details_Layout.Element (1).Name_Width > 0, "narrow details name column keeps visible width");
      Assert
        (Details_Layout.Element (1).Modified_Width <= Details_Layout.Element (1).Width,
         "narrow details modified column is bounded");
      Assert
        (Details_Layout.Element (1).Size_Width <= Details_Layout.Element (1).Width,
         "narrow details size column is bounded");
      Assert
        (Details_Layout.Element (1).Filetype_Width <= Details_Layout.Element (1).Width,
         "narrow details filetype column is bounded");

      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 100, Height => 73, Line_Height => 20);
      Details_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Layout.Main_Height = 5, "partial details main height is represented");
      Assert (Details_Layout.Element (1).Height = 0, "partial details row is hidden behind clipped header");
      Assert (Details_Layout.Element (1).Icon_Size = 0, "partial details icon is hidden behind clipped header");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 100, Height => 73, Line_Height => 20);
      declare
         Found_Clipped_Metadata_Text : Boolean := False;
      begin
         for Command of Frame.Text loop
            if Command.X >= Details_Layout.Element (1).Modified_X
              and then Command.Y >= Layout.Main_Y
              and then Command.Y < Layout.Main_Y + Layout.Main_Height + Layout.Bottom_Bar_Height
              and then
                (To_String (Command.Text) = Files.Localization.Text ("status.missing_metadata")
                 or else To_String (Command.Text) = Files.Localization.Text ("info.kind.text"))
            then
               Found_Clipped_Metadata_Text := True;
            end if;
         end loop;

         Assert
           (not Found_Clipped_Metadata_Text,
            "partial details row does not draw metadata columns under bottom bar");
      end;

      Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Small_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Small_Layout.Element (1).Height = 0, "partial small-icons cell is hidden until full row fits");
      Assert (Small_Layout.Element (1).Icon_Size = 0, "partial small-icons icon does not shrink while scrolling");

      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 40, Height => 50, Line_Height => 20);
      Small_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Small_Layout.Element (1).Width = Layout.Main_Width, "narrow small-icons cell width is bounded");
      Assert (Small_Layout.Element (1).Height = 0, "narrow small-icons cell height saturates");
      Assert (Small_Layout.Element (1).Icon_Size = 0, "narrow small-icons icon size saturates");

      declare
         Image_Snapshot : Files.Rendering.View_Snapshot;
         Image_Frame    : Files.Rendering.Frame_Commands;
         Image_Layout   : Files.Rendering.Item_Layout_Vectors.Vector;
         Found_Image_Mark : Boolean := False;
         Found_Image_Frame : Boolean := False;
         Ada_Snapshot   : Files.Rendering.View_Snapshot;
         Ada_Frame      : Files.Rendering.Frame_Commands;
         Ada_Layout     : Files.Rendering.Item_Layout_Vectors.Vector;
         Found_Ada_Mark : Boolean := False;
         Found_Ada_Frame : Boolean := False;
         Unknown_Snapshot : Files.Rendering.View_Snapshot;
         Unknown_Frame    : Files.Rendering.Frame_Commands;
         Unknown_Layout   : Files.Rendering.Item_Layout_Vectors.Vector;
         Found_Unknown_Mark : Boolean := False;
         Found_Unknown_Frame : Boolean := False;
         Custom_Snapshot : Files.Rendering.View_Snapshot;
         Custom_Frame    : Files.Rendering.Frame_Commands;
         Custom_Layout   : Files.Rendering.Item_Layout_Vectors.Vector;
         Found_Custom_Fallback : Boolean := False;
         Found_Custom_Command  : Boolean := False;
         Long_Name_Snapshot : Files.Rendering.View_Snapshot;
         Long_Name_Frame    : Files.Rendering.Frame_Commands;
         Found_Truncated_Name : Boolean := False;
         Utf8_Single_Snapshot : Files.Rendering.View_Snapshot;
         Utf8_Single_Frame    : Files.Rendering.Frame_Commands;
         Found_Utf8_Single    : Boolean := False;
         Combining_Snapshot   : Files.Rendering.View_Snapshot;
         Combining_Frame      : Files.Rendering.Frame_Commands;
         Found_Combining_Fit  : Boolean := False;
         Utf8_Name_Snapshot : Files.Rendering.View_Snapshot;
         Utf8_Name_Frame    : Files.Rendering.Frame_Commands;
         Utf8_Text          : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Combining_Text     : constant String :=
           "e" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#));
         Variation_Text     : constant String :=
           "x" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#FE0F#));
         Supplementary_Variation_Text : constant String :=
           "x" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#E0100#));
         CJK_Text           : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#6587#));
         Ellipsis_Text      : constant String :=
           [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
         Broken_Utf8_Text   : constant String := Utf8_Text (Utf8_Text'First .. Utf8_Text'First) & Ellipsis_Text;
         Broken_CJK_Text    : constant String := CJK_Text (CJK_Text'First .. CJK_Text'First) & Ellipsis_Text;
         Found_Utf8_Fit     : Boolean := False;
         CJK_Name_Snapshot  : Files.Rendering.View_Snapshot;
         CJK_Name_Frame     : Files.Rendering.Frame_Commands;
         Found_CJK_Fit      : Boolean := False;
         Overlay_Name_Snapshot : Files.Rendering.View_Snapshot;
         Overlay_Name_Frame    : Files.Rendering.Frame_Commands;
         Found_Overlay_Name_Fit : Boolean := False;
         Overlay_Utf8_Snapshot : Files.Rendering.View_Snapshot;
         Overlay_Utf8_Frame    : Files.Rendering.Frame_Commands;
         Found_Overlay_Utf8_Fit : Boolean := False;
         Overlay_Utf8_Single_Snapshot : Files.Rendering.View_Snapshot;
         Overlay_Utf8_Single_Frame    : Files.Rendering.Frame_Commands;
         Found_Overlay_Utf8_Single    : Boolean := False;
         Exact_Ellipsis_Snapshot : Files.Rendering.View_Snapshot;
         Exact_Ellipsis_Frame    : Files.Rendering.Frame_Commands;
         Found_Exact_Ellipsis    : Boolean := False;
         Details_Snapshot   : Files.Rendering.View_Snapshot;
         Details_Frame      : Files.Rendering.Frame_Commands;
      begin
         Assert
           (Files.UTF8.Display_Units ("a" & Utf8_Text & Byte (16#80#)) = 3,
            "shared UTF-8 helper counts multibyte and malformed units as display cells");
         Assert
           (Files.UTF8.Display_Units (Combining_Text) = 1,
            "shared UTF-8 helper treats combining marks as zero-width cells");
         Assert
           (Files.UTF8.Display_Units (Variation_Text) = 1,
            "shared UTF-8 helper treats variation selectors as zero-width cells");
         Assert
           (Files.UTF8.Display_Units (Supplementary_Variation_Text) = 1,
            "shared UTF-8 helper treats supplementary variation selectors as zero-width cells");
         Assert
           (Files.UTF8.Display_Units (CJK_Text) = 2,
            "shared UTF-8 helper treats CJK item-name glyphs as double-width cells");
         Assert
           (Files.UTF8.Encode_Codepoint (16#2302#) = Files.Application.Windows.Text_Input_Bytes
              (Wide_Wide_Character'Val (16#2302#)),
            "shared UTF-8 helper encodes toolbar icon glyph codepoints");
         Assert
           (Files.UTF8.Encode_Codepoint (16#D800#) = Files.Application.Windows.Text_Input_Bytes
              (Wide_Wide_Character'Val (16#FFFD#)),
            "shared UTF-8 helper replaces invalid encoded codepoints");
         Assert
           (Files.UTF8.Prefix_By_Units ("a" & Utf8_Text & "b", 2) = "a" & Utf8_Text,
            "shared UTF-8 helper preserves whole multibyte prefixes");
         Assert
           (Files.UTF8.Prefix_By_Units (Combining_Text & "b", 1) = Combining_Text,
            "shared UTF-8 helper preserves trailing combining marks within display capacity");
         Assert
           (Files.UTF8.Prefix_By_Units (Variation_Text & "b", 1) = Variation_Text,
            "shared UTF-8 helper preserves trailing variation selectors within display capacity");
         Assert
           (Files.UTF8.Prefix_By_Units (CJK_Text & "ab", 1) = "",
            "shared UTF-8 helper does not fit a double-width glyph into one cell");
         Assert
           (Files.UTF8.Prefix_By_Units (CJK_Text & "ab", 2) = CJK_Text,
            "shared UTF-8 helper preserves whole double-width prefixes");
         Assert
           (Files.UTF8.Previous_Boundary ("a" & Utf8_Text & "b", 3) = 1,
            "shared UTF-8 helper moves previous boundary over whole multibyte units");
         Assert
           (Files.UTF8.Previous_Boundary (Combining_Text & "b", Combining_Text'Length) = 0,
            "shared UTF-8 helper moves previous boundary over trailing combining marks");
         Assert
           (Files.UTF8.Next_Boundary ("a" & Utf8_Text & "b", 1) = 3,
            "shared UTF-8 helper moves next boundary over whole multibyte units");
         Assert
           (Files.UTF8.Next_Boundary (Combining_Text & "b", 0) = Combining_Text'Length,
            "shared UTF-8 helper moves next boundary over trailing combining marks");
         Assert
           (Files.UTF8.Boundary_At_Or_Before ("a" & Utf8_Text & "b", 2) = 1,
            "shared UTF-8 helper snaps interior offsets to earlier boundaries");
         Assert
           (Files.UTF8.Boundary_At_Or_Before (Combining_Text & "b", 1) = 0,
            "shared UTF-8 helper snaps combining mark starts to the base boundary");
         Assert
           (Files.UTF8.Display_Units_Before ("a" & Utf8_Text & "b", 3) = 2,
            "shared UTF-8 helper counts display units before byte cursor");
         Assert
           (Files.UTF8.Display_Units_Before (CJK_Text & "a", CJK_Text'Length) = 2,
            "shared UTF-8 helper counts wide display units before byte cursor");
         Assert
           (Files.UTF8.Byte_Offset_For_Display_Column ("a" & Utf8_Text & "b", 2) = 3,
            "shared UTF-8 helper maps display column to UTF-8 byte offset");
         Assert
           (Files.UTF8.Byte_Offset_For_Display_Column (Combining_Text & "b", 1) = Combining_Text'Length,
            "shared UTF-8 helper maps display columns after trailing combining marks");
         Assert
           (Files.UTF8.Byte_Offset_For_Display_Column (CJK_Text & "a", 1) = 0,
            "shared UTF-8 helper maps interior wide display columns to the wide glyph start");
         Assert
           (Files.UTF8.Byte_Offset_For_Display_Column (CJK_Text & "a", 2) = CJK_Text'Length,
            "shared UTF-8 helper maps wide display column end to the next glyph boundary");
         Assert
           (Files.UTF8.Is_Required_Zero_Width_Codepoint (16#0301#),
            "shared UTF-8 helper marks combining accents as required zero-width glyphs");
         Assert
           (not Files.UTF8.Is_Required_Zero_Width_Codepoint (16#FE0F#),
            "shared UTF-8 helper does not require variation selector glyphs");
         Assert
           (Files.UTF8.Byte_Offset_For_Display_Column ("a" & Byte (16#80#) & "b", 2) = 2,
            "shared UTF-8 helper maps malformed display column to byte offset");
         Assert
           (Files.UTF8.Word_Separator_Length ("a b", 1) = 1,
            "shared UTF-8 helper recognizes ASCII word separators");
         Assert
           (Files.UTF8.Whitespace_Separator_Length ("a b", 1) = 1,
            "shared UTF-8 helper recognizes ASCII whitespace separators");
         Assert
           (Files.UTF8.Whitespace_Separator_Length ("a.b", 1) = 0,
            "shared UTF-8 helper does not treat punctuation as whitespace separator");
         Assert
           (Files.UTF8.Word_Separator_Length ("a.b", 1) = 1,
            "shared UTF-8 helper treats punctuation as word separator");
         Assert
           (Files.UTF8.Word_Separator_Length ("a" & Utf8_Text & "b", 1) = 0,
            "shared UTF-8 helper does not treat normal multibyte text as word separator");
         Assert
           (Files.UTF8.Previous_Word_Boundary ("alpha beta", 10) = 6,
            "shared UTF-8 helper finds previous word boundary");
         Assert
           (Files.UTF8.Next_Word_Boundary ("alpha beta", 0) = 5,
            "shared UTF-8 helper finds next word boundary");
         Assert
           (Files.UTF8.Previous_Word_Boundary ("a" & Utf8_Text & "b beta", 4) = 0,
            "shared UTF-8 helper moves previous word boundary over whole multibyte text");
         Assert
           (Files.UTF8.Next_Word_Boundary ("a" & Utf8_Text & "b beta", 0) = 4,
            "shared UTF-8 helper moves next word boundary over whole multibyte text");
         Assert
           (Files.UTF8.Previous_Word_Boundary (Combining_Text & " beta", Combining_Text'Length) = 0,
            "shared UTF-8 helper moves previous word boundary over combining text");
         Assert
           (Files.UTF8.Next_Word_Boundary (Combining_Text & " beta", 0) = Combining_Text'Length,
            "shared UTF-8 helper moves next word boundary over combining text");
         Assert
           (Files.UTF8.Is_Valid ("a" & Utf8_Text & "b"),
            "shared UTF-8 helper accepts valid multibyte text");
         Assert
           (not Files.UTF8.Is_Valid ("a" & Byte (16#E2#) & Byte (16#82#) & "b"),
            "shared UTF-8 helper rejects truncated multibyte text");
         Assert
           (not Files.UTF8.Is_Valid ("a" & Byte (16#C0#) & Byte (16#AF#) & "b"),
            "shared UTF-8 helper rejects overlong multibyte text");
         declare
            Decode_Index : Integer := 1;
            Decoded      : Natural := 0;
         begin
            Files.UTF8.Decode_Next_Codepoint ("A", Decode_Index, Decoded);
            Assert
              (Decoded = Character'Pos ('A') and then Decode_Index = 2,
               "shared UTF-8 helper decodes ASCII codepoints");
            Decode_Index := 1;
            Files.UTF8.Decode_Next_Codepoint (Utf8_Text, Decode_Index, Decoded);
            Assert
              (Decoded = 16#00E9# and then Decode_Index = Utf8_Text'Length + 1,
               "shared UTF-8 helper decodes multibyte codepoints");
            Decode_Index := 1;
            Files.UTF8.Decode_Next_Codepoint (String'(1 => Byte (16#80#)), Decode_Index, Decoded);
            Assert
              (Decoded = 16#FFFD# and then Decode_Index = 2,
               "shared UTF-8 helper decodes malformed bytes as replacement codepoints");
            Decode_Index := 1;
            Files.UTF8.Decode_Next_Display_Codepoint (String'(1 => Byte (16#E6#)), Decode_Index, Decoded);
            Assert
              (Decoded = 16#00E6# and then Decode_Index = 2,
               "shared UTF-8 display decoder preserves legacy non-ASCII filename bytes");
         end;

         Image_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("photo.png"),
               Filetype      => To_Unbounded_String ("image/png"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.image.png")),
               Icon_Id       => To_Unbounded_String ("image"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Image_Frame := Files.Rendering.Build_Frame_Commands (Image_Snapshot, Width => 200, Height => 120);
         Image_Layout := Files.Rendering.Calculate_Item_Layout (Image_Snapshot, Image_Frame.Layout);
         for Command of Image_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Selection_Color
              and then Command.X >= Image_Layout.Element (1).Icon_X
              and then Command.Y >= Image_Layout.Element (1).Icon_Y
              and then Command.X < Image_Layout.Element (1).Icon_X + Image_Layout.Element (1).Icon_Size
              and then Command.Y < Image_Layout.Element (1).Icon_Y + Image_Layout.Element (1).Icon_Size
            then
               Found_Image_Mark := True;
            elsif Command.Color = Files.Rendering.Border_Color
              and then Command.X = Image_Layout.Element (1).Icon_X
              and then Command.Y = Image_Layout.Element (1).Icon_Y
              and then Command.Width = Image_Layout.Element (1).Icon_Size
              and then Command.Height = 1
            then
               Found_Image_Frame := True;
            end if;
         end loop;
         Assert (Found_Image_Mark, "frame renders image-specific icon mark");
         Assert (not Found_Image_Frame, "frame omits image icon asset outer border");

         Ada_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("main.adb"),
               Filetype      => To_Unbounded_String ("text/x-ada"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.file")),
               Icon_Id       => To_Unbounded_String ("ada"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Ada_Frame := Files.Rendering.Build_Frame_Commands (Ada_Snapshot, Width => 200, Height => 120);
         Ada_Layout := Files.Rendering.Calculate_Item_Layout (Ada_Snapshot, Ada_Frame.Layout);
         for Command of Ada_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Icon_Executable_Color
              and then Command.X >= Ada_Layout.Element (1).Icon_X
              and then Command.Y >= Ada_Layout.Element (1).Icon_Y
              and then Command.X < Ada_Layout.Element (1).Icon_X + Ada_Layout.Element (1).Icon_Size
              and then Command.Y < Ada_Layout.Element (1).Icon_Y + Ada_Layout.Element (1).Icon_Size
            then
               Found_Ada_Mark := True;
            elsif Command.Color = Files.Rendering.Border_Color
              and then Command.X = Ada_Layout.Element (1).Icon_X
              and then Command.Y = Ada_Layout.Element (1).Icon_Y
              and then Command.Width = Ada_Layout.Element (1).Icon_Size
              and then Command.Height = 1
            then
               Found_Ada_Frame := True;
            end if;
         end loop;
         Assert (Found_Ada_Mark, "frame renders settings-driven Ada icon mark");
         Assert (not Found_Ada_Frame, "frame omits Ada icon asset outer border");

         Unknown_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("blob.bin"),
               Filetype      => To_Unbounded_String ("application/octet-stream"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.file")),
               Icon_Id       => To_Unbounded_String ("unknown"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Unknown_Frame := Files.Rendering.Build_Frame_Commands (Unknown_Snapshot, Width => 200, Height => 120);
         Unknown_Layout := Files.Rendering.Calculate_Item_Layout (Unknown_Snapshot, Unknown_Frame.Layout);
         for Command of Unknown_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Border_Color
              and then Command.X >= Unknown_Layout.Element (1).Icon_X
              and then Command.Y >= Unknown_Layout.Element (1).Icon_Y
              and then Command.X < Unknown_Layout.Element (1).Icon_X + Unknown_Layout.Element (1).Icon_Size
              and then Command.Y < Unknown_Layout.Element (1).Icon_Y + Unknown_Layout.Element (1).Icon_Size
            then
               Found_Unknown_Mark := True;
            end if;

            if Command.Color = Files.Rendering.Border_Color
              and then Command.X = Unknown_Layout.Element (1).Icon_X
              and then Command.Y = Unknown_Layout.Element (1).Icon_Y
              and then Command.Width = Unknown_Layout.Element (1).Icon_Size
              and then Command.Height = 1
            then
               Found_Unknown_Frame := True;
            end if;
         end loop;
         Assert (Found_Unknown_Mark, "frame renders unknown-file icon mark");
         Assert (not Found_Unknown_Frame, "frame omits unknown icon asset outer border");

         Custom_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("custom.asset"),
               Filetype      => To_Unbounded_String ("application/x-custom"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.file")),
               Icon_Id       => To_Unbounded_String ("project-private-icon"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Custom_Frame := Files.Rendering.Build_Frame_Commands (Custom_Snapshot, Width => 200, Height => 120);
         Custom_Layout := Files.Rendering.Calculate_Item_Layout (Custom_Snapshot, Custom_Frame.Layout);
         for Command of Custom_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Border_Color
              and then Command.X >= Custom_Layout.Element (1).Icon_X
              and then Command.Y >= Custom_Layout.Element (1).Icon_Y
              and then Command.X < Custom_Layout.Element (1).Icon_X + Custom_Layout.Element (1).Icon_Size
              and then Command.Y < Custom_Layout.Element (1).Icon_Y + Custom_Layout.Element (1).Icon_Size
            then
               Found_Custom_Fallback := True;
            end if;
         end loop;
         for Command of Custom_Frame.Icons loop
            if To_String (Command.Icon_Id) = "unknown" then
               Found_Custom_Command := True;
            end if;
         end loop;
         Assert (Found_Custom_Fallback, "frame renders fallback mark for custom unbundled icon id");
         Assert (Found_Custom_Command, "frame records resolved icon command for custom unbundled icon id");

         Long_Name_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          =>
                 To_Unbounded_String ("this-file-name-is-far-too-long-for-the-visible-cell.txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Long_Name_Frame := Files.Rendering.Build_Frame_Commands (Long_Name_Snapshot, Width => 100, Height => 120);
         for Command of Long_Name_Frame.Text loop
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), "...") = 0
            then
               Found_Truncated_Name := True;
            end if;
         end loop;
         Assert (Found_Truncated_Name, "frame truncates long item text with a single ellipsis");

         Utf8_Single_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String (Utf8_Text),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Utf8_Single_Frame := Files.Rendering.Build_Frame_Commands (Utf8_Single_Snapshot, Width => 60, Height => 120);
         for Command of Utf8_Single_Frame.Text loop
            if To_String (Command.Text) = Utf8_Text
              and then Command.Color = Files.Rendering.Text_Color
              and then not Command.Truncated
            then
               Found_Utf8_Single := True;
            end if;
         end loop;
         Assert (Found_Utf8_Single, "frame fitting treats one UTF-8 character as one display cell");

         Combining_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String (Combining_Text & "file-name-too-long.txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Combining_Frame := Files.Rendering.Build_Frame_Commands (Combining_Snapshot, Width => 80, Height => 120);
         for Command of Combining_Frame.Text loop
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Combining_Fit := True;
            end if;
         end loop;
         Assert
           (Found_Combining_Fit,
            "frame fitting preserves combining item-name marks before ellipsis");

         Utf8_Name_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String (Utf8_Text & "file-name-too-long.txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Utf8_Name_Frame := Files.Rendering.Build_Frame_Commands (Utf8_Name_Snapshot, Width => 70, Height => 120);
         for Command of Utf8_Name_Frame.Text loop
            Assert
              (To_String (Command.Text) /= Broken_Utf8_Text,
               "frame UTF-8 fitting does not split a multibyte name character");
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Utf8_Fit := True;
            end if;
         end loop;
         Assert (Found_Utf8_Fit, "frame UTF-8 fitting keeps whole multibyte prefix in narrow cells");

         CJK_Name_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String (CJK_Text & "file-name-too-long.txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         CJK_Name_Frame := Files.Rendering.Build_Frame_Commands (CJK_Name_Snapshot, Width => 80, Height => 120);
         for Command of CJK_Name_Frame.Text loop
            Assert
              (To_String (Command.Text) /= Broken_CJK_Text,
               "frame CJK fitting does not split a multibyte wide name character");
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_CJK_Fit := True;
            end if;
         end loop;
         Assert (Found_CJK_Fit, "frame CJK fitting keeps whole wide item-name glyphs in narrow cells");

         Overlay_Name_Snapshot.Root_Selector_Open := True;
         Overlay_Name_Snapshot.Root_Selected_Index := 1;
         Overlay_Name_Snapshot.Root_Paths.Append (To_Unbounded_String ("/"));
         Overlay_Name_Snapshot.Root_Labels.Append (To_Unbounded_String ("abcdef"));
         Overlay_Name_Frame :=
           Files.Rendering.Build_Frame_Commands (Overlay_Name_Snapshot, Width => 116, Height => 140);
         for Command of Overlay_Name_Frame.Overlay_Text loop
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), "...") = 0
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Overlay_Name_Fit := True;
            end if;
         end loop;
         Assert (Found_Overlay_Name_Fit, "overlay fitting uses full ellipsis capacity");

         Overlay_Utf8_Snapshot.Root_Selector_Open := True;
         Overlay_Utf8_Snapshot.Root_Selected_Index := 1;
         Overlay_Utf8_Snapshot.Root_Paths.Append (To_Unbounded_String ("/"));
         Overlay_Utf8_Snapshot.Root_Labels.Append
           (To_Unbounded_String (Utf8_Text & "root-name-too-long"));
         Overlay_Utf8_Frame :=
           Files.Rendering.Build_Frame_Commands (Overlay_Utf8_Snapshot, Width => 116, Height => 140);
         for Command of Overlay_Utf8_Frame.Overlay_Text loop
            Assert
              (To_String (Command.Text) /= Broken_Utf8_Text,
               "overlay UTF-8 fitting does not split a multibyte root label character");
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 0
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Overlay_Utf8_Fit := True;
            end if;
         end loop;
         Assert
           (Found_Overlay_Utf8_Fit,
            "overlay UTF-8 fitting keeps full multibyte character before ellipsis");

         Overlay_Utf8_Single_Snapshot.Root_Selector_Open := True;
         Overlay_Utf8_Single_Snapshot.Root_Selected_Index := 1;
         Overlay_Utf8_Single_Snapshot.Root_Paths.Append (To_Unbounded_String ("/"));
         Overlay_Utf8_Single_Snapshot.Root_Labels.Append (To_Unbounded_String (Utf8_Text));
         Overlay_Utf8_Single_Frame :=
           Files.Rendering.Build_Frame_Commands (Overlay_Utf8_Single_Snapshot, Width => 86, Height => 140);
         for Command of Overlay_Utf8_Single_Frame.Overlay_Text loop
            if To_String (Command.Text) = Utf8_Text
              and then Command.Color = Files.Rendering.Text_Color
              and then not Command.Truncated
            then
               Found_Overlay_Utf8_Single := True;
            end if;
         end loop;
         Assert
           (Found_Overlay_Utf8_Single,
            "overlay fitting treats one UTF-8 character as one display cell");

         Exact_Ellipsis_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("abcdefghi.txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Exact_Ellipsis_Frame :=
           Files.Rendering.Build_Frame_Commands (Exact_Ellipsis_Snapshot, Width => 70, Height => 120);
         for Command of Exact_Ellipsis_Frame.Text loop
            if Command.Truncated
              and then Ada.Strings.Fixed.Index (To_String (Command.Text), Ellipsis_Text) > 1
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Exact_Ellipsis := True;
            end if;
         end loop;
         Assert (Found_Exact_Ellipsis, "frame keeps a useful prefix before the ellipsis");

         Details_Snapshot.View_Mode := Files.Types.Details;
         Details_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name               => To_Unbounded_String ("report.long"),
               Filetype           => To_Unbounded_String ("application/x-extremely-long-type"),
               Filetype_Detail    => To_Unbounded_String ("application/x-extremely-long-type"),
               Icon_Id            => To_Unbounded_String ("unknown"),
               Kind               => Files.Types.Regular_File_Item,
               Modified_Available => True,
               Modified_Time      => Ada.Calendar.Time_Of (2026, 6, 17),
               Size_Available     => True,
               Size               => 42,
               Visible_Index      => 1,
               others             => <>));
         Details_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name               => To_Unbounded_String ("archive.bin"),
               Filetype           => To_Unbounded_String ("application/octet-stream"),
               Filetype_Detail    => To_Unbounded_String ("application/octet-stream"),
               Icon_Id            => To_Unbounded_String ("unknown"),
               Kind               => Files.Types.Regular_File_Item,
               Size_Available     => True,
               Size               => 1536,
               Visible_Index      => 2,
               others             => <>));
         Details_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name               => To_Unbounded_String ("image.raw"),
               Filetype           => To_Unbounded_String ("application/octet-stream"),
               Filetype_Detail    => To_Unbounded_String ("application/octet-stream"),
               Icon_Id            => To_Unbounded_String ("unknown"),
               Kind               => Files.Types.Regular_File_Item,
               Size_Available     => True,
               Size               => 1_048_576,
               Visible_Index      => 3,
               others             => <>));
         Details_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name               => To_Unbounded_String ("disk.img"),
               Filetype           => To_Unbounded_String ("application/octet-stream"),
               Filetype_Detail    => To_Unbounded_String ("application/octet-stream"),
               Icon_Id            => To_Unbounded_String ("unknown"),
               Kind               => Files.Types.Regular_File_Item,
               Size_Available     => True,
               Size               => 5_368_709_120,
               Visible_Index      => 4,
               others             => <>));
         Details_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name               => To_Unbounded_String ("recent.txt"),
               Filetype           => To_Unbounded_String ("text/plain"),
               Filetype_Detail    => To_Unbounded_String ("text/plain"),
               Icon_Id            => To_Unbounded_String ("text"),
               Kind               => Files.Types.Regular_File_Item,
               Modified_Available => True,
               Modified_Time      => Ada.Calendar.Clock,
               Visible_Index      => 5,
               others             => <>));
         Details_Frame := Files.Rendering.Build_Frame_Commands (Details_Snapshot, Width => 1000, Height => 300);
         declare
            Found_Size_With_Unit : Boolean := False;
            Found_Size_With_KB   : Boolean := False;
            Found_Size_With_MB   : Boolean := False;
            Found_Size_With_GB   : Boolean := False;
            Found_Full_Modified  : Boolean := False;
            Found_Relative_Time  : Boolean := False;
            Found_Modified_Tooltip : Boolean := False;
            Decimal_Separator    : constant String :=
              Files.Localization.Text ("number.decimal", Files.Localization.System_Number_Locale);
            Observed_Modified    : Unbounded_String;
         begin
            for Command of Details_Frame.Text loop
               if To_String (Command.Text) =
                 "42 " & Files.Localization.Text
                   ("details.size.unit.bytes",
                    Files.Localization.System_Number_Locale)
               then
                  Found_Size_With_Unit := True;
               elsif To_String (Command.Text) =
                 "1" & Decimal_Separator & "5 "
                   & Files.Localization.Text
                     ("details.size.unit.kib",
                      Files.Localization.System_Number_Locale)
               then
                  Found_Size_With_KB := True;
               elsif To_String (Command.Text) =
                 "1 " & Files.Localization.Text
                   ("details.size.unit.mib",
                    Files.Localization.System_Number_Locale)
               then
                  Found_Size_With_MB := True;
               elsif To_String (Command.Text) =
                 "5 " & Files.Localization.Text
                   ("details.size.unit.gib",
                    Files.Localization.System_Number_Locale)
               then
                  Found_Size_With_GB := True;
               elsif Ada.Strings.Fixed.Index (To_String (Command.Text), "/2026") > 0
                 and then Ada.Strings.Fixed.Index (To_String (Command.Text), ":") > 0
                 and then To_String (Command.Text)'Length >= 19
                 and then not Command.Truncated
               then
                  Found_Full_Modified := True;
               elsif To_String (Command.Text) = Files.Localization.Text ("time.relative.now") then
                  Found_Relative_Time := True;
               elsif Ada.Strings.Fixed.Index (To_String (Command.Text), "2026") > 0
                 or else Ada.Strings.Fixed.Index (To_String (Command.Text), "06/17") > 0
               then
                  Observed_Modified := Command.Text;
               end if;
            end loop;
            for Command of Details_Frame.Tooltips loop
               if Ada.Strings.Fixed.Index (To_String (Command.Text), "/2026") > 0
                 and then Ada.Strings.Fixed.Index (To_String (Command.Text), ":") > 0
                 and then To_String (Command.Text)'Length >= 19
               then
                  Found_Modified_Tooltip := True;
               end if;
            end loop;
            Assert (Found_Size_With_Unit, "details size includes byte unit");
            Assert (Found_Size_With_KB, "details size scales to KB with one decimal");
            Assert (Found_Size_With_MB, "details size scales to MB");
            Assert (Found_Size_With_GB, "details size scales to GB");
            Assert
              (Found_Full_Modified,
               "details modified timestamp is not abbreviated; observed: " & To_String (Observed_Modified));
            Assert (Found_Relative_Time, "details modified timestamp humanizes current values");
            Assert (Found_Modified_Tooltip, "details modified tooltip exposes full timestamp");
         end;
      end;

      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 100, Height => 73, Line_Height => 20);
      Large_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Large_Layout.Element (1).Height = 0, "partial large-icons cell is hidden until full row fits");
      Assert (Large_Layout.Element (1).Icon_Size = 0, "partial large-icons icon does not shrink while scrolling");

      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 40, Height => 50, Line_Height => 20);
      Large_Layout := Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
      Assert (Large_Layout.Element (1).Width = Layout.Main_Width, "narrow large-icons cell width is bounded");
      Assert (Large_Layout.Element (1).Height = 0, "narrow large-icons cell height saturates");
      Assert (Large_Layout.Element (1).Icon_Size = 0, "narrow large-icons icon size saturates");

      Toolbar := Files.UI.Calculate_Toolbar_Layout (3);
      Assert
        (Toolbar.Left_X = 0 and then Toolbar.Middle_X = 0 and then Toolbar.Right_X = 3,
         "narrow toolbar keeps explicit section origins");
      Assert (Toolbar.Left_Width = 0, "narrow toolbar hides fixed-width icon buttons");
      Assert (Toolbar.Middle_Width = 3, "narrow toolbar preserves total width");
      Assert
        (Files.UI.Toolbar_Command_At (0, Files.UI.Toolbar_Input_Y (20), 239, Line_Height => 20) =
         Files.Commands.Focus_Path_Input_Command,
         "toolbar hit test hides icon buttons when fixed width cannot fit");
      Assert
        (Files.UI.Toolbar_Command_At (1, Files.UI.Toolbar_Input_Y (20), 3, Line_Height => 20) =
         Files.Commands.Focus_Path_Input_Command,
         "narrow toolbar hit test includes padded path input top edge");
      Assert
        (Files.UI.Toolbar_Command_At (1, 10, 3, Line_Height => 20) = Files.Commands.Focus_Path_Input_Command,
         "narrow toolbar hit test gives remaining width to path input");
      Toolbar := Files.UI.Calculate_Toolbar_Layout (0);
      Assert
        (Toolbar.Left_X = 0 and then Toolbar.Left_Width = 0 and then Toolbar.Middle_X = 0 and then
         Toolbar.Middle_Width = 0 and then Toolbar.Right_X = 0 and then Toolbar.Right_Width = 0,
         "zero-width toolbar stays empty");
      Assert
        (Files.UI.Toolbar_Command_At (0, 10, 0, Line_Height => 20) = Files.Commands.No_Command,
         "zero-width toolbar hit test stays empty");
      declare
         Utf8_Caret_Snapshot : Files.Rendering.View_Snapshot;
         Utf8_Caret_Frame    : Files.Rendering.Frame_Commands;
         Utf8_Caret_Toolbar  : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (400);
         Utf8_Caret_X        : constant Natural :=
           Utf8_Caret_Toolbar.Right_X + Files.UI.Input_Field_Padding + 20;
         Utf8_Caret_Y        : constant Natural :=
           Files.UI.Toolbar_Input_Y (20) + Files.UI.Input_Field_Padding + 2;
         Found_Utf8_Caret    : Boolean := False;
         Found_Byte_Caret    : Boolean := False;
         Malformed_Caret_Frame : Files.Rendering.Frame_Commands;
         Found_Malformed_Caret : Boolean := False;
         Found_Malformed_Skip  : Boolean := False;
      begin
         Utf8_Caret_Snapshot.Focus := Files.Types.Focus_Filter_Input;
         Utf8_Caret_Snapshot.Filter_Text :=
           To_Unbounded_String ("a" & Byte (16#C3#) & Byte (16#A9#));
         Utf8_Caret_Snapshot.Text_Cursor_Position := 3;
         Utf8_Caret_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Utf8_Caret_Snapshot,
              Width       => 400,
              Height      => 120,
              Line_Height => 20);

         for Command of Utf8_Caret_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Text_Color
              and then Command.Width = 2
              and then Command.Height = 16
              and then Command.Y = Utf8_Caret_Y
            then
               if Command.X = Utf8_Caret_X then
                  Found_Utf8_Caret := True;
               elsif Command.X = Utf8_Caret_X + 10 then
                  Found_Byte_Caret := True;
               end if;
            end if;
         end loop;

         Assert (Found_Utf8_Caret, "filter caret renders after UTF-8 characters, not bytes");
         Assert (not Found_Byte_Caret, "filter caret does not use UTF-8 byte length for x position");

         Utf8_Caret_Snapshot.Filter_Text := To_Unbounded_String ("a" & Byte (16#A9#));
         Utf8_Caret_Snapshot.Text_Cursor_Position := 2;
         Malformed_Caret_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Utf8_Caret_Snapshot,
              Width       => 400,
              Height      => 120,
              Line_Height => 20);

         for Command of Malformed_Caret_Frame.Rectangles loop
            if Command.Color = Files.Rendering.Text_Color
              and then Command.Width = 2
              and then Command.Height = 16
              and then Command.Y = Utf8_Caret_Y
            then
               if Command.X = Utf8_Caret_X then
                  Found_Malformed_Caret := True;
               elsif Command.X = Utf8_Caret_X - 10 then
                  Found_Malformed_Skip := True;
               end if;
            end if;
         end loop;

         Assert
           (Found_Malformed_Caret,
            "filter caret counts malformed UTF-8 byte as replacement cell");
         Assert
           (not Found_Malformed_Skip,
            "filter caret does not skip malformed UTF-8 continuation byte");
      end;
      Bottom_Bar := Files.UI.Calculate_Bottom_Bar_Layout (40, Line_Height => 20);
      Assert (Bottom_Bar.View_Mode_X = 8, "narrow bottom bar keeps left padding");
      Assert (Bottom_Bar.View_Mode_Width = 24, "narrow bottom bar keeps view selector within padded width");
      Assert (Bottom_Bar.Info_Width = 0, "narrow bottom bar saturates info section");
      Assert (Bottom_Bar.Info_Pane_Width = 0, "narrow bottom bar saturates info-pane toggle");
      Assert
        (Files.UI.Bottom_Bar_Command_At (31, 40, 40, 60, Line_Height => 20) =
         Files.Commands.Select_Small_Icons_Command,
         "narrow bottom-bar hit test keeps available pixels on small-icons command");
      Assert
        (Files.UI.Bottom_Bar_Command_At (32, 40, 40, 60, Line_Height => 20) = Files.Commands.No_Command,
         "narrow bottom-bar hit test rejects edge after collapsed buttons");
      Bottom_Bar := Files.UI.Calculate_Bottom_Bar_Layout (0, Line_Height => 20);
      Assert
        (Bottom_Bar.View_Mode_Width = 0 and then Bottom_Bar.Info_Width = 0 and then
         Bottom_Bar.Info_Pane_Width = 0,
         "zero-width bottom bar stays empty");
      Assert
        (Files.UI.Bottom_Bar_Command_At (0, 0, 0, 20, Line_Height => 20) = Files.Commands.No_Command,
         "zero-width bottom-bar hit test stays empty");

      Model := Sample_Model;
      Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Layout := Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
      declare
         Palette_Frame        : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Found_Palette_Border : Boolean := False;
         Found_Palette_Focus_Ring : Boolean := False;
         Found_Palette_Shadow : Boolean := False;
         Found_Palette_Opaque_Panel : Boolean := False;
         Found_Palette_Transparent_Row : Boolean := False;
         Found_Palette_Top_Accent : Boolean := False;
         Found_Palette_Description : Boolean := False;
         Found_Palette_Selection_Accent : Boolean := False;
         Found_Palette_Disabled_Fill : Boolean := False;
         Found_Palette_Disabled_Rule : Boolean := False;
         Found_Palette_Description_Gutter : Boolean := False;
         Found_Palette_Shortcut_Gutter : Boolean := False;
         Found_Palette_Shortcut : Boolean := False;
         Found_Palette_Search_Padding : Boolean := False;
         Found_Palette_Item_Text_Leak : Boolean := False;
         Found_Palette_Accessible_Shortcut : Boolean := False;
         Found_Palette_Accessible_Disabled : Boolean := False;
         Palette_Text_Right_Edge : constant Natural :=
           Palette_Layout.Results_X + Palette_Layout.Results_Width - 14;
         Utf8_Shortcut_Text : constant String :=
           "x" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#)) & "y";
         Utf8_Shortcut_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
         Utf8_Shortcut_Frame    : Files.Rendering.Frame_Commands;
         Found_Utf8_Shortcut_Width : Boolean := False;
      begin
         declare
            Result : Files.Rendering.Command_Result_Snapshot :=
              Utf8_Shortcut_Snapshot.Command_Palette_Results.Element (1);
         begin
            Result.Shortcut_Text := To_Unbounded_String (Utf8_Shortcut_Text);
            Utf8_Shortcut_Snapshot.Command_Palette_Results.Replace_Element (1, Result);
         end;
         Utf8_Shortcut_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Utf8_Shortcut_Snapshot, Width => 1000, Height => 800, Line_Height => 20);

         for Command of Palette_Frame.Rectangles loop
            if Command.X = Palette_Layout.Search_X
              and then Command.Y = Palette_Layout.Search_Y
              and then Command.Width = Palette_Layout.Search_Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Palette_Border := True;
            elsif Command.X = Palette_Layout.Search_X - 1
              and then Command.Y = Palette_Layout.Search_Y - 1
              and then Command.Width = Palette_Layout.Search_Width + 2
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Palette_Focus_Ring := True;
            elsif Command.X = Palette_Layout.X + Palette_Layout.Width
              and then Command.Y = Palette_Layout.Y + 3
              and then Command.Width = 3
              and then Command.Height = Palette_Layout.Height
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Palette_Shadow := True;
            elsif Command.X = Palette_Layout.X
              and then Command.Y = Palette_Layout.Y
              and then Command.Width = Palette_Layout.Width
              and then Command.Height = Palette_Layout.Height
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Palette_Opaque_Panel := True;
            elsif Command.X = Palette_Layout.X
              and then Command.Y = Palette_Layout.Y
              and then Command.Width = Palette_Layout.Width
              and then Command.Height = 3
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Palette_Top_Accent := True;
            elsif Command.X = Palette_Layout.Results_X
              and then Command.Y = Palette_Layout.Results_Y
              and then Command.Width = 3
              and then Command.Height = 48
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Palette_Selection_Accent := True;
            elsif Command.X = Palette_Layout.Results_X
              and then Command.Y = Palette_Layout.Results_Y
              and then Command.Width = Palette_Layout.Results_Width
              and then Command.Height = 48
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Palette_Disabled_Fill := True;
            elsif Command.X >= Palette_Layout.Results_X
              and then Command.Y >= Palette_Layout.Results_Y
              and then Command.X < Palette_Layout.Results_X + Palette_Layout.Results_Width
              and then Command.Y < Palette_Layout.Results_Y + Palette_Layout.Results_Height
              and then Command.Color = Files.Rendering.Overlay_Color
            then
               Found_Palette_Transparent_Row := True;
            elsif Command.X = Palette_Layout.Results_X + 8
              and then Command.Y = Palette_Layout.Results_Y + 23
              and then Command.Width = Palette_Layout.Results_Width - 30
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Disabled_Text_Color
            then
               Found_Palette_Disabled_Rule := True;
            end if;
         end loop;

         for Command of Palette_Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("command.navigate.back.description")
              and then Command.Color = Files.Rendering.Disabled_Text_Color
            then
               Found_Palette_Description := True;
               if Command.X + Command.Width <= Palette_Text_Right_Edge then
                  Found_Palette_Description_Gutter := True;
               end if;
            elsif To_String (Command.Text) = "alt+left"
              and then Command.Color = Files.Rendering.Disabled_Text_Color
            then
               Found_Palette_Shortcut := True;
               if Command.X + Command.Width <= Palette_Text_Right_Edge then
                  Found_Palette_Shortcut_Gutter := True;
               end if;
            elsif To_String (Command.Text) = To_String (Snapshot.Command_Palette_Query)
              and then Command.X = Palette_Layout.Search_X + Files.UI.Input_Field_Padding
              and then Command.Width =
                Palette_Layout.Search_Width - 2 * Files.UI.Input_Field_Padding
            then
               Found_Palette_Search_Padding := True;
            elsif To_String (Command.Text) = "Alpha.txt" then
               Found_Palette_Item_Text_Leak := True;
            end if;
         end loop;

         for Command of Utf8_Shortcut_Frame.Text loop
            if To_String (Command.Text) = Utf8_Shortcut_Text
              and then Command.Width = Files.UTF8.Display_Units (Utf8_Shortcut_Text) * 10
            then
               Found_Utf8_Shortcut_Width := True;
            end if;
         end loop;

         for Node of Palette_Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_List_Item
              and then To_String (Node.Name) = Files.Localization.Text ("command.navigate.back")
              and then Ada.Strings.Fixed.Index (To_String (Node.Description), "alt+left") > 0
            then
               Found_Palette_Accessible_Shortcut := True;
               if Ada.Strings.Fixed.Index
                   (To_String (Node.Description), Files.Localization.Text ("accessibility.command_disabled")) > 0
               then
                  Found_Palette_Accessible_Disabled := True;
               end if;
            end if;
         end loop;

         Assert (Found_Palette_Border, "frame renders focused command-palette search border");
         Assert (Found_Palette_Focus_Ring, "frame renders expanded command-palette focus ring");
         Assert (Found_Palette_Shadow, "frame renders command-palette drop shadow");
         Assert (Found_Palette_Opaque_Panel, "frame renders opaque command-palette panel");
         Assert (Found_Palette_Top_Accent, "frame renders command-palette top accent");
         Assert (Found_Palette_Description, "frame renders command-palette result description");
         Assert (Found_Palette_Search_Padding, "frame renders command-palette input with inner padding");
         Assert (not Found_Palette_Item_Text_Leak, "frame hides file item text behind command palette");
         Assert (Found_Palette_Shortcut, "frame renders command-palette result shortcut text");
         Assert
           (Found_Palette_Description_Gutter and then Found_Palette_Shortcut_Gutter,
            "frame keeps command-palette text out of scrollbar gutter");
         Assert
           (Found_Utf8_Shortcut_Width,
            "frame sizes command-palette UTF-8 shortcut text by display cells");
         Assert
           (Found_Palette_Accessible_Shortcut,
            "frame exposes command-palette shortcut text in accessibility metadata");
         Assert
           (Found_Palette_Accessible_Disabled,
            "frame exposes disabled command-palette state in accessibility metadata");
         Assert (Found_Palette_Selection_Accent, "frame renders selected command-palette row accent");
         Assert (Found_Palette_Disabled_Fill, "frame renders disabled command-palette row fill");
         Assert (not Found_Palette_Transparent_Row, "frame renders command-palette rows opaque");
         Assert (Found_Palette_Disabled_Rule, "frame renders disabled command-palette row rule");
      end;
      Files.Model.Open_Root_Selector (Model, Roots);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      declare
         Found_Count_Text : Boolean := False;
         Found_Count_Tooltip : Boolean := False;
         Found_Count_Hover_Tooltip : Boolean := False;
         Expected_Count_Text : constant String :=
           Files.Localization.Text ("status.items") & ": 3  "
           & Files.Localization.Text ("status.visible") & ": 3  "
           & Files.Localization.Text ("status.selected") & ": 1";
         Bottom_For_Count : constant Files.UI.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
         Hover_Count_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Bottom_For_Count.Info_X + 8,
              Hover_Y     => Frame.Layout.Height - Files.UI.Bottom_Bar_Padding - 2,
              Has_Hover   => True);
         Root_For_Frame : constant Files.Rendering.Root_Selector_Layout :=
           Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Frame.Layout, Line_Height => 20);
         Root_Rows : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_For_Frame);
         Found_Root_Selected_Accent : Boolean := False;
      begin
         for Command of Frame.Text loop
            if To_String (Command.Text) = Expected_Count_Text
              and then Command.Color = Files.Rendering.Muted_Text_Color
            then
               Found_Count_Text := True;
            end if;
         end loop;
         for Command of Frame.Tooltips loop
            if To_String (Command.Text) = Expected_Count_Text
              and then Command.X = Bottom_For_Count.Info_X
              and then Command.Width = Bottom_For_Count.Info_Width
            then
               Found_Count_Tooltip := True;
            end if;
         end loop;
         for Command of Hover_Count_Frame.Overlay_Text loop
            if To_String (Command.Text) = Expected_Count_Text then
               Found_Count_Hover_Tooltip := True;
            end if;
         end loop;
         for Command of Frame.Overlay_Rectangles loop
            if Command.X = Root_Rows.Element (1).X
              and then Command.Y = Root_Rows.Element (1).Y
              and then Command.Width = 3
              and then Command.Height = Root_Rows.Element (1).Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Root_Selected_Accent := True;
            end if;
         end loop;

         Assert (Found_Count_Text, "frame renders localized bottom-bar count text");
         Assert (Found_Count_Tooltip, "frame exposes localized bottom-bar count tooltip text");
         Assert (Found_Count_Hover_Tooltip, "frame renders bottom-bar count hover tooltip text");
         Assert (Found_Root_Selected_Accent, "frame renders root selector selected-row accent");
      end;
      declare
         Utf8_Error_Model : Files.Model.Window_Model := Sample_Model;
         Utf8_Error_Snapshot : Files.Rendering.View_Snapshot;
         Utf8_Error_Frame : Files.Rendering.Frame_Commands;
         Utf8_Error_Text : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#))
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Utf8_Error_Bottom : Files.UI.Bottom_Bar_Layout;
         Found_Utf8_Error_Tooltip_Text : Boolean := False;
         Found_Utf8_Error_Tooltip_Panel : Boolean := False;
         Found_Byte_Sized_Tooltip_Panel : Boolean := False;
      begin
         Files.Model.Set_Error (Utf8_Error_Model, Utf8_Error_Text);
         Utf8_Error_Snapshot := Files.Rendering.Build_Snapshot (Utf8_Error_Model);
         Utf8_Error_Bottom := Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
         Utf8_Error_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Utf8_Error_Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Utf8_Error_Bottom.Info_X + 8,
              Hover_Y     => 800 - Files.UI.Bottom_Bar_Padding - 2,
              Has_Hover   => True);

         for Command of Utf8_Error_Frame.Overlay_Text loop
            if To_String (Command.Text) = Utf8_Error_Text then
               Found_Utf8_Error_Tooltip_Text := True;
            end if;
         end loop;

         for Command of Utf8_Error_Frame.Overlay_Rectangles loop
            if Command.Color = Files.Rendering.Overlay_Color
              and then Command.Width = 212
            then
               Found_Utf8_Error_Tooltip_Panel := True;
            elsif Command.Color = Files.Rendering.Overlay_Color
              and then Command.Width = 412
            then
               Found_Byte_Sized_Tooltip_Panel := True;
            end if;
         end loop;

         Assert
           (Found_Utf8_Error_Tooltip_Text,
            "frame renders UTF-8 bottom-bar hover tooltip text");
         Assert
           (Found_Utf8_Error_Tooltip_Panel,
            "frame sizes UTF-8 hover tooltip by display cells");
         Assert
           (not Found_Byte_Sized_Tooltip_Panel,
           "frame does not size UTF-8 hover tooltip by bytes");
      end;
      declare
         Short_Tooltip_Model : Files.Model.Window_Model := Sample_Model;
         Short_Tooltip_Snapshot : Files.Rendering.View_Snapshot;
         Short_Tooltip_Frame : Files.Rendering.Frame_Commands;
         Short_Tooltip_Bottom : Files.UI.Bottom_Bar_Layout;
         Found_Short_Tooltip_Text : Boolean := False;
         Found_Short_Tooltip_Panel : Boolean := False;
         Found_Minimum_Sized_Tooltip_Panel : Boolean := False;
         Narrow_Tooltip_Frame : Files.Rendering.Frame_Commands;
      begin
         Files.Model.Set_Error (Short_Tooltip_Model, "x");
         Short_Tooltip_Snapshot := Files.Rendering.Build_Snapshot (Short_Tooltip_Model);
         Short_Tooltip_Bottom := Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
         Short_Tooltip_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Short_Tooltip_Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Short_Tooltip_Bottom.Info_X + 8,
              Hover_Y     => 800 - Files.UI.Bottom_Bar_Padding - 2,
              Has_Hover   => True);

         for Command of Short_Tooltip_Frame.Overlay_Text loop
            if To_String (Command.Text) = "x" then
               Found_Short_Tooltip_Text := True;
            end if;
         end loop;

         for Command of Short_Tooltip_Frame.Overlay_Rectangles loop
            if Command.Color = Files.Rendering.Overlay_Color
              and then Command.Width = 22
            then
               Found_Short_Tooltip_Panel := True;
            elsif Command.Color = Files.Rendering.Overlay_Color
              and then Command.Width = 172
            then
               Found_Minimum_Sized_Tooltip_Panel := True;
            end if;
         end loop;

         Assert
           (Found_Short_Tooltip_Text,
            "frame renders short bottom-bar hover tooltip text");
         Assert
           (Found_Short_Tooltip_Panel,
            "frame sizes short hover tooltip by content width");
         Assert
           (not Found_Minimum_Sized_Tooltip_Panel,
            "frame does not force a wide minimum hover tooltip width");

         Narrow_Tooltip_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Short_Tooltip_Snapshot,
              Width       => 8,
              Height      => 80,
              Line_Height => 20,
              Hover_X     => 1,
              Hover_Y     => 70,
              Has_Hover   => True);
         Assert
           (Narrow_Tooltip_Frame.Overlay_Text.Is_Empty,
            "narrow frame omits hover tooltip text when no text cells fit");
         Assert
           (Narrow_Tooltip_Frame.Overlay_Rectangles.Is_Empty,
            "narrow frame omits empty hover tooltip panel when no text cells fit");
      end;
      declare
         Found_Text_Icon : Boolean := False;
      begin
         Assert
           (Natural (Frame.Icons.Length) = Snapshot.Visible_Count + 5,
            "frame emits item and toolbar icon commands");
         for Command of Frame.Icons loop
            if To_String (Command.Icon_Id) = "text"
              and then To_String (Command.Theme_Name) = "files-basic"
              and then To_String (Command.Asset_Path) = "share/files/icons/text.icon"
            then
               Found_Text_Icon := True;
            end if;
         end loop;

         Assert (Found_Text_Icon, "frame exposes default themed text icon asset command");
      end;
      declare
         Icon_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Icon_Items    : Files.File_System.Item_Vectors.Vector;
         Icon_Model    : Files.Model.Window_Model;
         Icon_Snapshot : Files.Rendering.View_Snapshot;
         Icon_Frame    : Files.Rendering.Frame_Commands;
         Found_Markdown_Icon : Boolean := False;
      begin
         Files.Settings.Add_Icon_Mapping (Icon_Settings, "text/markdown", "markdown");
         Icon_Settings.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
         Icon_Items.Append
           (Files.File_System.Make_Item
              (Root, "readme.md", Files.Types.Regular_File_Item, Icon_Settings));
         Files.Model.Initialize (Icon_Model, Root, Icon_Items, Root);
         Icon_Snapshot := Files.Rendering.Build_Snapshot (Icon_Model, Icon_Settings);
         Icon_Frame :=
           Files.Rendering.Build_Frame_Commands (Icon_Snapshot, Width => 1000, Height => 800, Line_Height => 20);

         for Command of Icon_Frame.Icons loop
            if To_String (Command.Icon_Id) = "markdown"
              and then To_String (Command.Theme_Name) = "files-high-contrast"
              and then To_String (Command.Asset_Path) = "share/files/icons/high-contrast/markdown.icon"
            then
               Found_Markdown_Icon := True;
            end if;
         end loop;

         Assert (Found_Markdown_Icon, "frame exposes configured high-contrast markdown icon asset command");
      end;
      Files.Model.Close_Root_Selector (Model);
      declare
         Summary_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Args             : Files.Types.String_Vectors.Vector;
      begin
         Args.Append (To_Unbounded_String ("{path}"));
         Files.Settings.Add_Extension_Mapping (Summary_Settings, "ada", "text/x-ada");
         Files.Settings.Add_Icon_Mapping (Summary_Settings, "text/x-ada", "ada");
         Files.Settings.Add_Open_Action
           (Summary_Settings,
            "text/x-ada",
            Files.Settings.Make_Action ("editor", Args));
         Summary_Settings.Default_View := Files.Types.Details;
         Summary_Settings.Show_Hidden_Files := True;
         Summary_Settings.Sort_Field_Value := Files.Settings.Sort_By_Size;
         Summary_Settings.Sort_Ascending := False;
         Summary_Settings.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
         Files.Model.Toggle_Settings_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model, Summary_Settings);
      end;
      Assert (Snapshot.Settings_Pane_Open, "snapshot captures settings pane visibility");
      Assert
        (To_String (Snapshot.Settings_Default_View) = Files.Localization.Text ("command.view.details"),
         "settings snapshot captures actual default view setting");
      Assert
        (To_String (Snapshot.Settings_Default_View_Token) = "details",
         "settings snapshot keeps raw default view token");
      Assert
        (To_String (Snapshot.Settings_Hidden_Files) = Files.Localization.Text ("settings.value.true"),
         "settings snapshot captures actual hidden-file setting");
      Assert
        (To_String (Snapshot.Settings_Hidden_Files_Token) = "true",
         "settings snapshot keeps raw hidden-file token");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Snapshot.Settings_Sort), Files.Localization.Text ("settings.sort.size")) = 1,
         "settings snapshot captures actual sort field setting");
      Assert
        (To_String (Snapshot.Settings_Sort_Field_Token) = "size",
         "settings snapshot keeps raw sort-field token");
      Assert
        (To_String (Snapshot.Settings_Sort_Ascending_Token) = "false",
         "settings snapshot keeps raw sort-direction token");
      Assert
        (To_String (Snapshot.Settings_High_Contrast_Token) = "false",
         "settings snapshot keeps raw high-contrast token");
      Assert (To_String (Snapshot.Settings_Filetypes) = "20", "settings snapshot counts filetype mappings");
      Assert (To_String (Snapshot.Settings_Icons) = "21", "settings snapshot counts icon mappings");
      Assert (To_String (Snapshot.Settings_Open_Actions) = "2", "settings snapshot counts open actions");
      Assert
        (To_String (Snapshot.Settings_Icon_Theme) = "files-high-contrast",
         "settings snapshot captures icon theme setting");
      declare
         Draft_Count_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Draft_Count_Model    : Files.Model.Window_Model := Sample_Model;
         Draft_Count_Snapshot : Files.Rendering.View_Snapshot;
         Args                 : Files.Types.String_Vectors.Vector;
      begin
         Args.Append (To_Unbounded_String ("{path}"));
         Files.Settings.Add_Extension_Mapping (Draft_Count_Settings, "ada", "text/x-ada");
         Files.Settings.Add_Icon_Mapping (Draft_Count_Settings, "text/x-ada", "ada");
         Files.Settings.Add_Open_Action
           (Draft_Count_Settings,
            "text/x-ada",
            Files.Settings.Make_Action ("editor", Args));
         Files.Model.Begin_Settings_Edit
           (Draft_Count_Model,
            Files.Settings.Make_Draft (Draft_Count_Settings));

         Files.Model.Set_Settings_Field_Index (Draft_Count_Model, 7);
         Files.Model.Add_Settings_Entry (Draft_Count_Model);
         Files.Model.Set_Settings_Field_Index (Draft_Count_Model, 10);
         Files.Model.Remove_Settings_Entry (Draft_Count_Model);
         Files.Model.Set_Settings_Field_Index (Draft_Count_Model, 11);
         Files.Model.Add_Settings_Entry (Draft_Count_Model);

         Draft_Count_Snapshot := Files.Rendering.Build_Snapshot (Draft_Count_Model, Draft_Count_Settings);
         Assert
           (To_String (Draft_Count_Snapshot.Settings_Filetypes) = "21",
            "editable settings snapshot counts draft filetype mappings");
         Assert
           (To_String (Draft_Count_Snapshot.Settings_Icons) = "20",
            "editable settings snapshot counts draft icon mappings");
         Assert
           (To_String (Draft_Count_Snapshot.Settings_Open_Actions) = "3",
            "editable settings snapshot counts draft open actions");
         Assert
           (Natural (Draft_Count_Settings.Extension_Filetypes.Length) = 20,
            "draft snapshot count does not mutate saved filetype mappings");
         Assert
           (Natural (Draft_Count_Settings.Icon_Mappings.Length) = 21,
            "draft snapshot count does not mutate saved icon mappings");
         Assert
           (Natural (Draft_Count_Settings.Open_Actions.Length) = 2,
            "draft snapshot count does not mutate saved open actions");
      end;
      declare
         Misaligned_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Misaligned_Model    : Files.Model.Window_Model := Sample_Model;
         Misaligned_Snapshot : Files.Rendering.View_Snapshot;
         Misaligned_Draft    : Files.Settings.Settings_Draft;
      begin
         Misaligned_Settings.Extension_Filetypes.Clear;
         Misaligned_Settings.Icon_Mappings.Clear;
         Misaligned_Settings.Open_Actions.Clear;
         Misaligned_Draft := Files.Settings.Make_Draft (Misaligned_Settings);
         Misaligned_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
         Misaligned_Draft.Icon_Values.Append (To_Unbounded_String ("orphan-icon"));
         Misaligned_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/x-orphan"));
         Files.Model.Begin_Settings_Edit (Misaligned_Model, Misaligned_Draft);
         Misaligned_Snapshot := Files.Rendering.Build_Snapshot (Misaligned_Model, Misaligned_Settings);
         Assert
           (To_String (Misaligned_Snapshot.Settings_Filetypes) = "0",
            "editable settings snapshot ignores orphan filetype rows");
         Assert
           (To_String (Misaligned_Snapshot.Settings_Icons) = "0",
            "editable settings snapshot ignores orphan icon rows");
         Assert
           (To_String (Misaligned_Snapshot.Settings_Open_Actions) = "0",
            "editable settings snapshot ignores orphan open-action rows");
      end;
      declare
         Control_Model    : Files.Model.Window_Model := Sample_Model;
         Control_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Control_Snapshot : Files.Rendering.View_Snapshot;
         Control_Frame    : Files.Rendering.Frame_Commands;
         Found_Active     : Boolean := False;
      begin
         Control_Settings.Default_View := Files.Types.Details;
         Files.Model.Begin_Settings_Edit
           (Control_Model,
            Files.Settings.Make_Draft (Control_Settings));
         Files.Model.Set_Settings_Field_Index (Control_Model, 1);
         Control_Snapshot := Files.Rendering.Build_Snapshot (Control_Model, Control_Settings);
         Control_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Control_Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);

         for Command of Control_Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("command.view.details") then
               for Rectangle of Control_Frame.Rectangles loop
                  if Rectangle.X + Files.UI.Input_Field_Padding = Command.X
                    and then Rectangle.Y = Command.Y
                    and then Rectangle.Height = Command.Height
                    and then Rectangle.Color = Files.Rendering.Selection_Color
                  then
                     Found_Active := True;
                  end if;
               end loop;
            end if;
         end loop;

         Assert
           (Found_Active,
            "settings option controls highlight active raw token while rendering localized text");
      end;
      Assert
        (To_String (Snapshot.Settings_Control_Options) = Files.Localization.Text ("settings.options.default_view"),
         "settings snapshot exposes selected control options");
      Assert (Snapshot.Settings_Can_Save, "settings snapshot exposes save availability");
      Assert (Snapshot.Settings_Can_Reset, "settings snapshot exposes reset availability");
      Assert (To_String (Snapshot.Theme_Name) = "default", "snapshot exposes default theme name");
      Assert (not Snapshot.Theme_High_Contrast, "snapshot exposes default contrast state");
      Assert (Snapshot.Theme_Focus_Ring = Files.Rendering.Border_Color, "snapshot exposes focus ring color");
      declare
         Contrast_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Contrast_Snapshot : Files.Rendering.View_Snapshot;
      begin
         Contrast_Settings.High_Contrast_Theme := True;
         Contrast_Snapshot := Files.Rendering.Build_Snapshot (Model, Contrast_Settings);
         Assert
           (To_String (Contrast_Snapshot.Theme_Name) = "high_contrast",
            "snapshot exposes high-contrast theme name");
         Assert (Contrast_Snapshot.Theme_High_Contrast, "snapshot exposes high-contrast state");
         Assert
           (Contrast_Snapshot.Theme_Focus_Ring = Files.Rendering.Selection_Color,
            "snapshot exposes high-contrast focus ring color");
      end;
      declare
         Default_A11y : constant Files.Rendering.Accessibility_Profile :=
           Files.Rendering.Default_Accessibility_Profile;
         Contrast_A11y : constant Files.Rendering.Accessibility_Profile :=
           Files.Rendering.High_Contrast_Accessibility_Profile;
         Accessibility_Integration : constant Files.Rendering.Accessibility_Integration_Profile :=
           Files.Rendering.Accessibility_Integration_Profile_Of_Current_UI;
         Settings_Profile : constant Files.Rendering.Settings_Editor_Profile :=
           Files.Rendering.Settings_Editor_Profile_Of_Current_UI;
         Icon_Profile : constant Files.Rendering.Icon_Theme_Profile :=
           Files.Rendering.Icon_Theme_Profile_Of_Current_UI;
         Contrast_Icon_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Contrast_Icon_Profile  : Files.Rendering.Icon_Theme_Profile;
         Icon_Names : constant Files.Types.String_Vectors.Vector :=
           Files.Rendering.Bundled_Icon_Asset_Names;
         Parsed_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=test" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=1,2,3,4,accent" & ASCII.LF);
         Parsed_Bundled_Text_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             (Files.Rendering.Icon_Asset_Text ("text", "files-basic"));
         Parsed_Contrast_Folder_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             (Files.Rendering.Icon_Asset_Text ("folder", "files-high-contrast"));
         Parsed_Toolbar_Home_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             (Files.Rendering.Icon_Asset_Text ("toolbar-home", "files-basic"));
         Parsed_Toolbar_Delete_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             (Files.Rendering.Icon_Asset_Text ("toolbar-delete", "files-basic"));
         Bad_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=1,2,0,4,accent" & ASCII.LF);
         Out_Of_Bounds_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-bounds" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=15,2,2,4,accent" & ASCII.LF);
         Rect_Before_Grid_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-order" & ASCII.LF &
              "rect=1,2,3,4,accent" & ASCII.LF &
              "grid=16" & ASCII.LF);
         Huge_Rect_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-huge" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=" & Natural'Image (Natural'Last) & ",2,1,4,accent" & ASCII.LF);
         Bad_Grid_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-grid" & ASCII.LF &
              "grid=sixteen" & ASCII.LF &
              "rect=1,2,3,4,accent" & ASCII.LF);
         Bad_Rect_Number_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-rect-number" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=1,x,3,4,accent" & ASCII.LF);
         Bad_Role_Icon : constant Files.Rendering.Icon_Asset :=
           Files.Rendering.Parse_Icon_Asset
             ("files-icon-v1" & ASCII.LF &
              "name=bad-role" & ASCII.LF &
              "grid=16" & ASCII.LF &
              "rect=1,2,3,4,glow" & ASCII.LF);
         A11y_Frame : Files.Rendering.Frame_Commands;
         A11y_Export : Files.Accessibility.Export_Result;

         function Repository_File_Exists (Path : String) return Boolean is
         begin
            return Ada.Directories.Exists (Path)
              or else Ada.Directories.Exists ("../" & Path)
              or else Ada.Directories.Exists ("../../" & Path);
         end Repository_File_Exists;
      begin
         Assert (Default_A11y.Keyboard_Navigation, "default accessibility profile supports keyboard navigation");
         Assert (Default_A11y.Focus_Rings, "default accessibility profile exposes focus rings");
         Assert (Default_A11y.Tooltips, "default accessibility profile exposes tooltips");
         Assert (Default_A11y.Text_Truncation, "default accessibility profile exposes truncation behavior");
         Assert (not Default_A11y.High_Contrast, "default accessibility profile is not high contrast");
         Assert (Contrast_A11y.High_Contrast, "high-contrast accessibility profile advertises high contrast");
         Assert
           (Default_A11y.Screen_Reader_Role_Metadata,
            "accessibility profile exposes screen-reader role metadata");
         Assert (Settings_Profile.Scalar_Controls = 7, "settings profile counts scalar controls");
         Assert (Settings_Profile.Mapping_Controls = 4, "settings profile counts mapping controls");
         Assert (Settings_Profile.Open_Action_Controls = 2, "settings profile counts open-action controls");
         Assert (Settings_Profile.Supports_Save, "settings profile exposes save support");
         Assert (Settings_Profile.Supports_Reset, "settings profile exposes reset support");
         Assert (Settings_Profile.Per_Field_Diagnostics, "settings profile exposes field diagnostics");
         Assert (Settings_Profile.Supports_Option_Cycling, "settings profile exposes option cycling");
         Assert
           (Settings_Profile.Supports_Add_Remove_Mapping,
            "settings profile exposes add and remove mapping controls");
         Assert
           (Settings_Profile.Supports_Draft_Validation,
            "settings profile exposes draft validation");
         Assert (Settings_Profile.Saves_Central_Settings, "settings profile records central settings saves");
         Assert
           (Accessibility_Integration.Render_Node_Tree,
            "accessibility integration profile exposes render node tree");
         Assert
           (Accessibility_Integration.Native_API_Binding_Status =
            Files.File_System.Native_API_Binding_Available,
            "accessibility integration profile records native bridge binding");
         Assert
           (Accessibility_Integration.Role_Metadata,
            "accessibility integration profile exposes role metadata");
         Assert
           (Accessibility_Integration.Table_Metadata,
            "accessibility integration profile exposes table metadata");
         Assert
           (Accessibility_Integration.Pane_Section_Metadata,
            "accessibility integration profile exposes pane section metadata");
         Assert
           (Accessibility_Integration.Keyboard_Focus_Metadata,
            "accessibility integration profile exposes keyboard focus metadata");
         Assert
           (To_String (Accessibility_Integration.Binding_Unit) =
            "Files.Accessibility",
            "accessibility integration profile records accessibility bridge unit");
         A11y_Frame.Accessibility.Append
           (Files.Rendering.Accessibility_Node'
              (Role        => Files.Rendering.Role_Button,
               X           => 1,
               Y           => 2,
               Width       => 30,
               Height      => 20,
               Name        => To_Unbounded_String ("Open"),
               Description => To_Unbounded_String ("Open item"),
               Enabled     => True,
               Selected    => False,
               Focused     => True));
         A11y_Export := Files.Accessibility.Export_Tree (A11y_Frame);
         Assert (A11y_Export.Success, "accessibility bridge exports a tree");
         Assert
           (A11y_Export.Native_API_Binding_Status = Files.File_System.Native_API_Binding_Available,
            "accessibility bridge reports an available Ada binding");
         Assert (A11y_Export.Node_Count = 1, "accessibility bridge counts exported nodes");
         Assert (A11y_Export.Focused_Node_Count = 1, "accessibility bridge counts focused nodes");
         Assert
           (To_String (A11y_Export.Nodes.Element (1).Name) = "Open",
            "accessibility bridge preserves node names");
         Assert (To_String (Icon_Profile.Theme_Name) = "files-basic", "icon profile exposes theme name");
         Assert (not Icon_Profile.Placeholder_Icons, "icon profile records bundled asset icon mode");
         Assert (Icon_Profile.Scalable_Icons, "icon profile records scalable vector assets");
         Assert (To_String (Icon_Profile.Asset_Directory) = "share/files/icons", "icon profile exposes asset path");
         Assert (To_String (Icon_Profile.Asset_Format) = "files-icon-v1", "icon profile exposes asset format");
         Assert (Icon_Profile.Filetype_Icons = Natural (Icon_Names.Length), "icon profile counts bundled assets");
         Assert (Icon_Profile.User_Selectable, "icon profile records selectable theme support");
         Assert (Icon_Profile.High_Contrast_Ready, "icon profile records high-contrast asset support");
         Assert (Parsed_Icon.Valid, "icon asset parser accepts files-icon-v1 text");
         Assert (To_String (Parsed_Icon.Name) = "test", "icon asset parser captures name");
         Assert (Parsed_Icon.Grid = 16, "icon asset parser captures grid size");
         Assert (Natural (Parsed_Icon.Rectangles.Length) = 1, "icon asset parser captures rectangle count");
         Assert
           (Parsed_Icon.Rectangles.Element (1).Role = Files.Rendering.Icon_Asset_Accent,
            "icon asset parser captures rectangle role");
         Assert (Parsed_Bundled_Text_Icon.Valid, "renderer exposes bundled text icon asset text");
         Assert
           (To_String (Parsed_Bundled_Text_Icon.Name) = "text",
            "renderer bundled text icon asset has the expected name");
         Assert
           (Parsed_Contrast_Folder_Icon.Valid,
            "renderer exposes bundled high-contrast folder icon asset text");
         Assert (Parsed_Toolbar_Home_Icon.Valid, "renderer exposes bundled toolbar home icon asset text");
         Assert (Parsed_Toolbar_Delete_Icon.Valid, "renderer exposes bundled toolbar trash icon asset text");
         Assert
           (Natural (Parsed_Toolbar_Delete_Icon.Rectangles.Length) = 7,
            "toolbar trash icon asset uses a bin shape instead of an x shape");
         Assert (not Bad_Icon.Valid, "icon asset parser rejects malformed rectangles");
         Assert (not Out_Of_Bounds_Icon.Valid, "icon asset parser rejects rectangles outside the grid");
         Assert (not Rect_Before_Grid_Icon.Valid, "icon asset parser rejects rectangles before grid declaration");
         Assert (not Huge_Rect_Icon.Valid, "icon asset parser rejects huge out-of-grid coordinates");
         Assert (not Bad_Grid_Icon.Valid, "icon asset parser rejects nonnumeric grid size");
         Assert (not Bad_Rect_Number_Icon.Valid, "icon asset parser rejects nonnumeric rectangle fields");
         Assert (not Bad_Role_Icon.Valid, "icon asset parser rejects unknown rectangle roles");
         for Icon_Name of Icon_Names loop
            declare
               Path : constant String :=
                 To_String (Icon_Profile.Asset_Directory) & "/" & To_String (Icon_Name) & ".icon";
            begin
               Assert (Repository_File_Exists (Path), "bundled icon asset exists: " & Path);
            end;
         end loop;
         Contrast_Icon_Settings.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
         Contrast_Icon_Profile := Files.Rendering.Icon_Theme_Profile_For (Contrast_Icon_Settings);
         Assert
           (To_String (Contrast_Icon_Profile.Theme_Name) = "files-high-contrast",
            "settings-selected icon profile exposes high-contrast theme");
         Assert
           (To_String (Contrast_Icon_Profile.Asset_Directory) = "share/files/icons/high-contrast",
            "settings-selected icon profile exposes high-contrast asset path");
         for Icon_Name of Icon_Names loop
            declare
               Path : constant String :=
                 To_String (Contrast_Icon_Profile.Asset_Directory) & "/" & To_String (Icon_Name) & ".icon";
            begin
               Assert (Repository_File_Exists (Path), "high-contrast icon asset exists: " & Path);
            end;
         end loop;
      end;
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      declare
         Found_Settings_Title : Boolean := False;
         Found_Settings_Row   : Boolean := False;
         Found_Settings_Options : Boolean := False;
         Found_Settings_Add : Boolean := False;
         Found_Settings_Remove : Boolean := False;
         Settings_Add_Text_Width : Natural := 0;
         Settings_Remove_Text_Width : Natural := 0;
         Found_Settings_Reset : Boolean := False;
         Found_Settings_Save : Boolean := False;
         Found_Settings_Add_Tooltip : Boolean := False;
         Found_Settings_Remove_Tooltip : Boolean := False;
         Found_Settings_Reset_Tooltip : Boolean := False;
         Found_Settings_Save_Tooltip : Boolean := False;
         Found_A11y_Settings_Add : Boolean := False;
         Found_A11y_Settings_Remove : Boolean := False;
         Found_A11y_Settings_Reset : Boolean := False;
         Found_A11y_Settings_Save : Boolean := False;
         Pane : constant Files.UI.Settings_Pane_Layout :=
           Files.UI.Calculate_Settings_Pane_Layout (1000, 800, Frame.Layout.Toolbar_Height, Line_Height => 20);
         Pane_W : constant Natural := Pane.Width;
         Pane_H : constant Natural := Pane.Height;
         Pane_X : constant Natural := Pane.X;
         Pane_Y : constant Natural := Pane.Y;
         Settings_Row_Step : constant Natural := 20 + Files.UI.Settings_Row_Gap;
         Focus_Row_Y : constant Natural := Pane.Text_Y + 3 * Settings_Row_Step;
         Found_Settings_Shadow : Boolean := False;
         Found_Settings_Top_Accent : Boolean := False;
         Found_Settings_Field_Focus_Ring : Boolean := False;
         Found_Settings_Field_Accent : Boolean := False;
      begin
         for Command of Frame.Rectangles loop
            if Command.X = Pane_X + Pane_W
              and then Command.Y = Pane_Y + 3
              and then Command.Width = 3
              and then Command.Height = Pane_H
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Settings_Shadow := True;
            elsif Command.X = Pane_X
              and then Command.Y = Pane_Y
              and then Command.Width = Pane_W
              and then Command.Height = 3
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Settings_Top_Accent := True;
            elsif Command.X = Pane.Text_X - 2
              and then Command.Y = Focus_Row_Y
              and then Command.Width = Pane.Text_Width + 4
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Settings_Field_Focus_Ring := True;
            elsif Command.X = Pane.Text_X - 2
              and then Command.Y = Focus_Row_Y
              and then Command.Width = 3
              and then Command.Height = 20
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Settings_Field_Accent := True;
            end if;
         end loop;

         for Command of Frame.Text loop
            if To_String (Command.Text) = Files.Localization.Text ("settings.title")
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Settings_Title := True;
            elsif Ada.Strings.Fixed.Index (To_String (Command.Text), "Def") = 1
            then
               Found_Settings_Row := True;
            elsif Ada.Strings.Fixed.Index (To_String (Command.Text), "Options:") = 1 then
               Found_Settings_Options := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("settings.add") then
               Found_Settings_Add := True;
               Settings_Add_Text_Width := Command.Width;
            elsif To_String (Command.Text) = Files.Localization.Text ("settings.remove") then
               Found_Settings_Remove := True;
               Settings_Remove_Text_Width := Command.Width;
            elsif To_String (Command.Text) = Files.Localization.Text ("command.settings.reset") then
               Found_Settings_Reset := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("command.settings.save") then
               Found_Settings_Save := True;
            end if;
         end loop;
         for Command of Frame.Tooltips loop
            if To_String (Command.Text) = Files.Localization.Text ("settings.add") then
               Found_Settings_Add_Tooltip := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("settings.remove") then
               Found_Settings_Remove_Tooltip := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("command.settings.reset.description") then
               Found_Settings_Reset_Tooltip := True;
            elsif Ada.Strings.Fixed.Index
              (To_String (Command.Text), Files.Localization.Text ("command.settings.save.description")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Command.Text),
                 Files.Commands.Shortcut_Text
                   (Files.Commands.Shortcut_For (Files.Commands.Save_Settings_Command))) > 0
            then
               Found_Settings_Save_Tooltip := True;
            end if;
         end loop;
         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_Button
              and then To_String (Node.Name) = Files.Localization.Text ("settings.add")
            then
               Found_A11y_Settings_Add := True;
            elsif Node.Role = Files.Rendering.Role_Button
              and then To_String (Node.Name) = Files.Localization.Text ("settings.remove")
            then
               Found_A11y_Settings_Remove := True;
            elsif Node.Role = Files.Rendering.Role_Button
              and then To_String (Node.Name) = Files.Localization.Text ("command.settings.reset")
              and then To_String (Node.Description) =
                Files.Localization.Text ("command.settings.reset.description")
            then
               Found_A11y_Settings_Reset := True;
            elsif Node.Role = Files.Rendering.Role_Button
              and then To_String (Node.Name) = Files.Localization.Text ("command.settings.save")
              and then To_String (Node.Description) =
                Files.Localization.Text ("command.settings.save.description")
            then
               Found_A11y_Settings_Save := True;
            end if;
         end loop;

         Assert (Found_Settings_Title, "frame renders localized settings pane title");
         Assert (Found_Settings_Row, "frame renders localized settings pane settings rows");
         Assert (Found_Settings_Options, "frame renders settings control options");
         Assert (Found_Settings_Add, "frame renders settings add button");
         Assert (Found_Settings_Remove, "frame renders settings remove button");
         Assert
           (Settings_Add_Text_Width >= Files.UTF8.Display_Units (Files.Localization.Text ("settings.add")) * 10,
            "frame sizes settings add button text to localized label");
         Assert
           (Settings_Remove_Text_Width >= Files.UTF8.Display_Units (Files.Localization.Text ("settings.remove")) * 10,
            "frame sizes settings remove button text to localized label");
         Assert (Found_Settings_Add_Tooltip, "frame exposes settings add tooltip");
         Assert (Found_Settings_Remove_Tooltip, "frame exposes settings remove tooltip");
         Assert (Found_A11y_Settings_Add, "frame exposes settings add accessibility node");
         Assert (Found_A11y_Settings_Remove, "frame exposes settings remove accessibility node");
         Assert (Found_Settings_Reset, "frame renders settings reset command button");
         Assert (Found_Settings_Save, "frame renders settings save command button");
         Assert (Found_Settings_Reset_Tooltip, "frame exposes settings reset tooltip");
         Assert (Found_Settings_Save_Tooltip, "frame exposes settings save tooltip");
         Assert (Found_A11y_Settings_Reset, "frame exposes settings reset accessibility node");
         Assert (Found_A11y_Settings_Save, "frame exposes settings save accessibility node");
         Assert (Found_Settings_Shadow, "frame renders settings pane drop shadow");
         Assert (Found_Settings_Top_Accent, "frame renders settings pane top accent");
         Assert (Found_Settings_Field_Focus_Ring, "frame renders focused settings field ring");
         Assert (Found_Settings_Field_Accent, "frame renders focused settings field accent");
      end;
      declare
         Error_Model    : Files.Model.Window_Model := Sample_Model;
         Error_Result   : Files.Controller.Controller_Result;
         Error_Snapshot : Files.Rendering.View_Snapshot;
         Error_Frame    : Files.Rendering.Frame_Commands;
         Found_Error    : Boolean := False;
      begin
         Error_Result :=
           Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Error_Model, Settings);
         pragma Unreferenced (Error_Result);
         Files.Model.Set_Settings_Field_Index (Error_Model, 2);
         Files.Model.Set_Settings_Field_Text (Error_Model, "maybe");
         Error_Result := Files.Controller.Handle_Key (Error_Model, Settings, Files.Types.Key_Return);
         Error_Snapshot := Files.Rendering.Build_Snapshot (Error_Model);
         Assert (not Error_Snapshot.Settings_Draft_Valid, "snapshot captures invalid settings draft");
         Assert
           (To_String (Error_Snapshot.Settings_Draft_Error) = "error.settings.invalid_boolean",
            "snapshot captures settings draft diagnostic key");
         Error_Frame := Files.Rendering.Build_Frame_Commands
           (Error_Snapshot,
            Width       => 1000,
            Height      => 800,
            Line_Height => 20);
         declare
            Error_Pane : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout
                (1000, 800, Error_Frame.Layout.Toolbar_Height, Line_Height => 20);
            Error_Row_Y : constant Natural := Error_Pane.Text_Y + 21 * (20 + Files.UI.Settings_Row_Gap);
         begin
            for Command of Error_Frame.Text loop
               if Ada.Strings.Fixed.Index (To_String (Command.Text), "Settings file contains") = 1
                 and then Command.Y = Error_Row_Y
               then
                  Found_Error := True;
               end if;
            end loop;
         end;
         Assert (Found_Error, "frame renders settings draft error inside pane");
         Files.Model.Set_Settings_Field_Text (Error_Model, "true");
         Error_Snapshot := Files.Rendering.Build_Snapshot (Error_Model);
         Assert (Error_Snapshot.Settings_Draft_Valid, "settings edit clears stale draft invalid state");
         Assert
           (To_String (Error_Snapshot.Settings_Draft_Error) = "",
            "settings edit clears stale draft diagnostic key");
      end;
      Files.Commands.Execute (Files.Commands.Toggle_Settings_Pane_Command, Model);

      Files.Model.Set_Error (Model, "error.path.missing");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (not Snapshot.Command_Enabled (Files.Commands.Navigate_Back_Command),
         "snapshot captures disabled back command");
      Assert
        (Snapshot.Command_Enabled (Files.Commands.Delete_Selected_Items_Command),
         "snapshot captures enabled delete command");
      declare
         Generic_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Toolbar_For_Generic : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (1000);
         Drive_Button_X : constant Natural :=
           Files.UI.Toolbar_Left_Button_X (Toolbar_For_Generic, 0);
         Drive_Button_W : constant Natural :=
           Files.UI.Toolbar_Left_Button_Width (Toolbar_For_Generic, 0);
         Button_H : constant Natural := Files.UI.Toolbar_Input_Height (20);
         Button_Y : constant Natural := Files.UI.Toolbar_Input_Y (20);
         Drive_Icon_Size : constant Natural :=
           (if Drive_Button_W >= Files.UI.Toolbar_Button_Width
            then Natural'Min (Button_H, Files.UI.Toolbar_Button_Width - 4)
            else Natural'Min (Drive_Button_W, Button_H));
         Drive_Icon_X : constant Natural :=
           (if Drive_Button_W > Drive_Icon_Size
            then Drive_Button_X + (Drive_Button_W - Drive_Icon_Size) / 2
            else Drive_Button_X);
         Drive_Icon_Y : constant Natural :=
           (if Button_H > Drive_Icon_Size then Button_Y + (Button_H - Drive_Icon_Size) / 2 else Button_Y);
         Drive_Bar_H : constant Natural := Natural'Max (2, Drive_Icon_Size / 9);
         Drive_Bar_W : constant Natural := Natural'Max (1, (Drive_Icon_Size * 2) / 3);
         Drive_Gap : constant Natural := Natural'Max (2, Drive_Icon_Size / 7);
         Drive_Total_H : constant Natural :=
           Drive_Bar_H * 3 + Drive_Gap * 2;
         Drive_Bar_X : constant Natural :=
           Drive_Icon_X
           + (if Drive_Icon_Size > Drive_Bar_W then (Drive_Icon_Size - Drive_Bar_W) / 2 else 0);
         Drive_First_Y : constant Natural :=
           Drive_Icon_Y
           + (if Drive_Icon_Size > Drive_Total_H then (Drive_Icon_Size - Drive_Total_H) / 2 else 0);
         Home_Button_X : constant Natural :=
           Files.UI.Toolbar_Left_Button_X (Toolbar_For_Generic, 1);
         Home_Button_W : constant Natural :=
           Files.UI.Toolbar_Left_Button_Width (Toolbar_For_Generic, 1);
         Home_Icon_Size : constant Natural :=
           (if Home_Button_W >= Files.UI.Toolbar_Button_Width
            then Natural'Min (Button_H, Files.UI.Toolbar_Button_Width - 4)
            else Natural'Min (Home_Button_W, Button_H));
         Home_Icon_X : constant Natural :=
           (if Home_Button_W > Home_Icon_Size
            then Home_Button_X + (Home_Button_W - Home_Icon_Size) / 2
            else Home_Button_X);
         Home_Icon_Y : constant Natural :=
           (if Button_H > Home_Icon_Size then Button_Y + (Button_H - Home_Icon_Size) / 2 else Button_Y);
         Old_Drive_Icon_Text : constant String := Files.UTF8.Encode_Codepoint (16#25A3#);
         Found_Generic_Toolbar_Label : Boolean := False;
         Found_Drive_Toolbar_Bar_1 : Boolean := False;
         Found_Drive_Toolbar_Bar_2 : Boolean := False;
         Found_Drive_Toolbar_Bar_3 : Boolean := False;
         Found_Old_Drive_Toolbar_Icon : Boolean := False;
         Found_Generic_Toolbar_Icon : Boolean := False;
         Found_Generic_Toolbar_Icon_Geometry : Boolean := False;
         Found_Generic_Toolbar_Icon_Triangle : Boolean := False;
         Found_Generic_Hover_Toolbar_Fill : Boolean := False;
         Found_Generic_Pressed_Toolbar_Fill : Boolean := False;
      begin
         for Command of Generic_Frame.Text loop
            if To_String (Command.Text) = Old_Drive_Icon_Text
              and then Command.X >= Drive_Button_X
              and then Command.X < Drive_Button_X + Drive_Button_W
              and then Command.Y < Generic_Frame.Layout.Toolbar_Height
            then
               Found_Old_Drive_Toolbar_Icon := True;
            elsif Command.X < Toolbar_For_Generic.Left_Width
              and then Command.Y < Generic_Frame.Layout.Toolbar_Height
              and then
                (To_String (Command.Text) = Files.Localization.Text ("command.navigate.home")
                 or else To_String (Command.Text) = Files.Localization.Text ("command.navigate.back")
                 or else To_String (Command.Text) = Files.Localization.Text ("command.navigate.forward"))
            then
               Found_Generic_Toolbar_Label := True;
            end if;
         end loop;
         for Command of Generic_Frame.Triangles loop
            if Command.X1 >= Float (Home_Icon_X)
              and then Command.Y1 >= Float (Home_Icon_Y)
              and then Command.X1 <= Float (Home_Icon_X + Home_Icon_Size)
              and then Command.Y1 <= Float (Home_Icon_Y + Home_Icon_Size)
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Generic_Toolbar_Icon_Triangle := True;
            end if;
         end loop;
         for Command of Generic_Frame.Icons loop
            if To_String (Command.Icon_Id) = "toolbar-home"
              and then Command.X = Home_Icon_X
              and then Command.Y = Home_Icon_Y
              and then Command.Size = Home_Icon_Size
            then
               Found_Generic_Toolbar_Icon := True;
            end if;
         end loop;
         for Command of Generic_Frame.Rectangles loop
            if Command.X = Drive_Bar_X
              and then Command.Width = Drive_Bar_W
              and then Command.Height = Drive_Bar_H
              and then Command.Color = Files.Rendering.Text_Color
            then
               if Command.Y = Drive_First_Y then
                  Found_Drive_Toolbar_Bar_1 := True;
               elsif Command.Y = Drive_First_Y + Drive_Bar_H + Drive_Gap then
                  Found_Drive_Toolbar_Bar_2 := True;
               elsif Command.Y = Drive_First_Y + 2 * (Drive_Bar_H + Drive_Gap) then
                  Found_Drive_Toolbar_Bar_3 := True;
               end if;
            elsif Command.X >= Home_Icon_X
              and then Command.Y >= Home_Icon_Y
              and then Command.X < Home_Icon_X + Home_Icon_Size
              and then Command.Y < Home_Icon_Y + Home_Icon_Size
              and then Command.Color = Files.Rendering.Text_Color
            then
               Found_Generic_Toolbar_Icon_Geometry := True;
            end if;
         end loop;
         declare
            Generic_Hover_Frame : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => 1000,
                 Height      => 800,
                 Line_Height => 20,
                 Hover_X     => Home_Button_X + 5,
                 Hover_Y     => 10,
                 Has_Hover   => True);
            Generic_Pressed_Frame : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => 1000,
                 Height      => 800,
                 Line_Height => 20,
                 Pressed_X   => Home_Button_X + 5,
                 Pressed_Y   => 10,
                 Has_Press   => True);
         begin
            for Command of Generic_Hover_Frame.Rectangles loop
               if Command.X = Home_Button_X
                 and then Command.Y = Files.UI.Toolbar_Input_Y (20)
                 and then Command.Width = Home_Button_W
                 and then Command.Height = Files.UI.Toolbar_Input_Height (20)
                 and then Command.Color = Files.Rendering.Hover_Color
               then
                  Found_Generic_Hover_Toolbar_Fill := True;
               end if;
            end loop;
            for Command of Generic_Pressed_Frame.Rectangles loop
               if Command.X = Home_Button_X
                 and then Command.Y = Files.UI.Toolbar_Input_Y (20)
                 and then Command.Width = Home_Button_W
                 and then Command.Height = Files.UI.Toolbar_Input_Height (20)
                 and then Command.Color = Files.Rendering.Pressed_Color
               then
                  Found_Generic_Pressed_Toolbar_Fill := True;
               end if;
            end loop;
         end;
         Assert (not Found_Generic_Toolbar_Label, "frame keeps left toolbar command labels out of visible text");
         Assert (Found_Drive_Toolbar_Bar_1, "frame renders drive chooser toolbar hamburger top bar");
         Assert (Found_Drive_Toolbar_Bar_2, "frame renders drive chooser toolbar hamburger middle bar");
         Assert (Found_Drive_Toolbar_Bar_3, "frame renders drive chooser toolbar hamburger bottom bar");
         Assert (not Found_Old_Drive_Toolbar_Icon, "frame does not render drive chooser as a square glyph");
         Assert (Found_Generic_Toolbar_Icon, "frame renders toolbar icons as centered icon assets");
         Assert (Found_Generic_Toolbar_Icon_Geometry, "frame renders visible toolbar icon geometry");
         Assert (Found_Generic_Toolbar_Icon_Triangle, "frame renders toolbar icon diagonals as triangles");
         Assert (Found_Generic_Hover_Toolbar_Fill, "frame renders hover fill for toolbar command");
         Assert (Found_Generic_Pressed_Toolbar_Fill, "frame renders pressed fill for toolbar command");
      end;
      Files.Model.Open_Root_Selector (Model, Roots);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Assert (Frame.Layout.Width = 1000, "frame commands preserve layout metrics");
      Assert (Natural (Frame.Rectangles.Length) >= 18, "frame includes drawable rectangles");
      Assert (Natural (Frame.Text.Length) > 0, "frame includes drawable text runs");
      Assert (Frame.Rectangles.Element (1).Color = Files.Rendering.Canvas_Color, "frame starts with canvas fill");
      Assert (Frame.Rectangles.Element (2).Color = Files.Rendering.Toolbar_Color, "frame includes toolbar fill");
      Assert
        (Frame.Rectangles.Element (3).Color = Files.Rendering.Main_Color,
         "frame includes main-area fill");

      declare
         Found_Selected_Item : Boolean := False;
         Found_Selected_Item_Border : Boolean := False;
         Found_Selected_Item_Accent : Boolean := False;
         Icon_Geometry_Count : Natural := 0;
         Found_Item_Text : Boolean := False;
         Found_Root_Text : Boolean := False;
         Found_Bottom_Label  : Boolean := False;
         Found_Left_Toolbar_Label : Boolean := False;
         Found_Left_Toolbar_Icon : Boolean := False;
         Found_Disabled_Back_Fill : Boolean := False;
         Found_Disabled_Back_Border : Boolean := False;
         Found_Selected_Bottom_Border : Boolean := False;
         Found_Error_Text : Boolean := False;
         Found_Root_Border : Boolean := False;
         Found_Root_Shadow : Boolean := False;
         Found_Info_Pane_Top_Edge : Boolean := False;
         Found_Home_Tooltip : Boolean := False;
         Found_Info_Tooltip : Boolean := False;
         Found_Root_Tooltip : Boolean := False;
         Found_Hover_Tooltip_Text : Boolean := False;
         Found_Hover_Tooltip_Panel : Boolean := False;
         Found_Info_Edge_Tooltip_Text : Boolean := False;
         Found_Info_Edge_Tooltip_Panel : Boolean := False;
         Found_Toolbar_Separator : Boolean := False;
         Found_Toolbar_Left_Path_Separator : Boolean := False;
         Found_Toolbar_Path_Filter_Separator : Boolean := False;
         Found_Bottom_Separator : Boolean := False;
         Found_Bottom_View_Info_Separator : Boolean := False;
         Found_Bottom_Info_Toggle_Separator : Boolean := False;
         Found_Info_Pane_Separator : Boolean := False;
         Found_Pressed_Path_Border : Boolean := False;
         Found_Hover_Item_Fill : Boolean := False;
         Found_Hover_Item_Border : Boolean := False;
         Found_Pressed_Item_Fill : Boolean := False;
         Found_Pressed_Item_Border : Boolean := False;
         Found_A11y_Window : Boolean := False;
         Found_A11y_Toolbar : Boolean := False;
         Found_A11y_Path_Input : Boolean := False;
         Found_A11y_Main_View_State : Boolean := False;
         Found_A11y_Filter_Input_State : Boolean := False;
         Found_A11y_Item : Boolean := False;
         Found_A11y_Item_State : Boolean := False;
         Found_A11y_Root : Boolean := False;
         Found_A11y_Root_Item_State : Boolean := False;
         Found_A11y_Status : Boolean := False;
         Found_A11y_Info_Toggle_State : Boolean := False;
         Toolbar_For_Frame : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (1000);
         Bottom_For_Frame : constant Files.UI.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
         Hover_Info_X : constant Natural :=
           Bottom_For_Frame.Info_Pane_X + Bottom_For_Frame.Info_Pane_Width - 2;
         Hover_Info_Y : constant Natural :=
           Frame.Layout.Height - Files.UI.Bottom_Bar_Padding - 2;
         Back_Button_X : constant Natural := Files.UI.Toolbar_Left_Button_X (Toolbar_For_Frame, 2);
         Back_Button_W : constant Natural := Files.UI.Toolbar_Left_Button_Width (Toolbar_For_Frame, 2);
         Home_Button_X : constant Natural := Files.UI.Toolbar_Left_Button_X (Toolbar_For_Frame, 1);
         Home_Button_W : constant Natural := Files.UI.Toolbar_Left_Button_Width (Toolbar_For_Frame, 1);
         Home_Icon_Size : constant Natural :=
           (if Home_Button_W >= Files.UI.Toolbar_Button_Width
            then Natural'Min (Files.UI.Toolbar_Input_Height (20), Files.UI.Toolbar_Button_Width - 4)
            else Natural'Min (Home_Button_W, Files.UI.Toolbar_Input_Height (20)));
         Home_Icon_X : constant Natural :=
           (if Home_Button_W > Home_Icon_Size
            then Home_Button_X + (Home_Button_W - Home_Icon_Size) / 2
            else Home_Button_X);
         Home_Icon_Y : constant Natural :=
           (if Files.UI.Toolbar_Input_Height (20) > Home_Icon_Size
            then Files.UI.Toolbar_Input_Y (20) + (Files.UI.Toolbar_Input_Height (20) - Home_Icon_Size) / 2
            else Files.UI.Toolbar_Input_Y (20));
         Delete_Button_X : constant Natural := Files.UI.Toolbar_Left_Button_X (Toolbar_For_Frame, 5);
         Root_For_Frame : constant Files.Rendering.Root_Selector_Layout :=
           Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Frame.Layout, Line_Height => 20);
         Info_For_Frame : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Frame.Layout, Line_Height => 20);
         Item_Layouts : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Frame.Layout, Line_Height => 20);
         First_Icon : constant Files.Rendering.Item_Layout := Item_Layouts.Element (1);
         Second_Item : constant Files.Rendering.Item_Layout := Item_Layouts.Element (2);
         Hover_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Home_Button_X + 5,
              Hover_Y     => 10,
              Has_Hover   => True);
         Pressed_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Pressed_X   => Home_Button_X + 5,
              Pressed_Y   => 10,
              Has_Press   => True);
         Pressed_Input_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Pressed_X   => Toolbar_For_Frame.Middle_X + 5,
              Pressed_Y   => 15,
              Has_Press   => True);
         Hover_Item_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Second_Item.X + 1,
              Hover_Y     => Second_Item.Y + 1,
              Has_Hover   => True);
         Hover_Info_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Hover_X     => Hover_Info_X,
              Hover_Y     => Hover_Info_Y,
              Has_Hover   => True);
         Pressed_Item_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => 1000,
              Height      => 800,
              Line_Height => 20,
              Pressed_X   => Second_Item.X + 1,
              Pressed_Y   => Second_Item.Y + 1,
              Has_Press   => True);
      begin
         for Command of Frame.Rectangles loop
            if Command.Color = Files.Rendering.Selection_Color
              and then Command.X = First_Icon.X
              and then Command.Y = First_Icon.Y
            then
               Found_Selected_Item := True;
            end if;

            if Command.X = First_Icon.X
              and then Command.Y = First_Icon.Y
              and then Command.Width = First_Icon.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Selected_Item_Border := True;
            elsif Command.X = First_Icon.X
              and then Command.Y = First_Icon.Y
              and then Command.Width = 3
              and then Command.Height = First_Icon.Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Selected_Item_Accent := True;
            end if;

            if Command.Width > 0
              and then Command.Height > 0
              and then Command.X >= First_Icon.Icon_X
              and then Command.Y >= First_Icon.Icon_Y
              and then Command.X < First_Icon.Icon_X + First_Icon.Icon_Size
              and then Command.Y < First_Icon.Icon_Y + First_Icon.Icon_Size
            then
               Icon_Geometry_Count := Icon_Geometry_Count + 1;
            end if;

            if Command.X = Back_Button_X
              and then Command.Y = Files.UI.Toolbar_Input_Y (20)
              and then Command.Width = Back_Button_W
              and then Command.Height = Files.UI.Toolbar_Input_Height (20)
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Disabled_Back_Fill := True;
            elsif Command.X = Back_Button_X
              and then Command.Y = Files.UI.Toolbar_Input_Y (20)
              and then Command.Width = Back_Button_W
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Disabled_Back_Border := True;
            elsif Command.X = Bottom_For_Frame.Small_Button_X
              and then Command.Y = Frame.Layout.Height - Frame.Layout.Bottom_Bar_Height
              and then Command.Width = Bottom_For_Frame.Small_Button_Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Selected_Bottom_Border := True;
            elsif Command.X = Info_For_Frame.X
              and then Command.Y = Info_For_Frame.Y
              and then Command.Width = Info_For_Frame.Width
              and then Command.Height = 2
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Info_Pane_Top_Edge := True;
            elsif Command.X = 0
              and then Command.Y = Frame.Layout.Toolbar_Height - 1
              and then Command.Width = Frame.Layout.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Toolbar_Separator := True;
            elsif Command.X = Toolbar_For_Frame.Middle_X
              and then Command.Y = 0
              and then Command.Width = 1
              and then Command.Height = Frame.Layout.Toolbar_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Toolbar_Left_Path_Separator := True;
            elsif Command.X = Toolbar_For_Frame.Right_X
              and then Command.Y = 0
              and then Command.Width = 1
              and then Command.Height = Frame.Layout.Toolbar_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Toolbar_Path_Filter_Separator := True;
            elsif Command.X = 0
              and then Command.Y = Frame.Layout.Height - Frame.Layout.Bottom_Bar_Height
              and then Command.Width = Frame.Layout.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Bottom_Separator := True;
            elsif Command.X = Bottom_For_Frame.Info_X
              and then Command.Y = Frame.Layout.Height - Frame.Layout.Bottom_Bar_Height
              and then Command.Width = 1
              and then Command.Height = Frame.Layout.Bottom_Bar_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Bottom_View_Info_Separator := True;
            elsif Command.X = Bottom_For_Frame.Info_Pane_X
              and then Command.Y = Frame.Layout.Height - Frame.Layout.Bottom_Bar_Height
              and then Command.Width = 1
              and then Command.Height = Frame.Layout.Bottom_Bar_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Bottom_Info_Toggle_Separator := True;
            elsif Command.X = Frame.Layout.Main_Width
              and then Command.Y = Frame.Layout.Main_Y
              and then Command.Width = 1
              and then Command.Height = Frame.Layout.Main_Height
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Info_Pane_Separator := True;
            end if;
         end loop;

         for Command of Frame.Text loop
            if To_String (Command.Text) = "Alpha.txt" then
               Found_Item_Text := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("command.view.small.short") then
               Found_Bottom_Label := True;
            elsif Command.X < Toolbar_For_Frame.Left_Width
              and then Command.Y < Frame.Layout.Toolbar_Height
              and then
                (To_String (Command.Text) = Files.Localization.Text ("command.navigate.home")
                 or else To_String (Command.Text) = Files.Localization.Text ("command.navigate.back")
                 or else To_String (Command.Text) = Files.Localization.Text ("command.navigate.forward"))
            then
               Found_Left_Toolbar_Label := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("error.path.missing")
              and then Command.Color = Files.Rendering.Error_Text_Color
            then
               Found_Error_Text := True;
            end if;
         end loop;

         for Command of Frame.Icons loop
            if To_String (Command.Icon_Id) = "toolbar-home"
              and then Command.X = Home_Icon_X
              and then Command.Y = Home_Icon_Y
              and then Command.Size = Home_Icon_Size
            then
               Found_Left_Toolbar_Icon := True;
            end if;
         end loop;

         for Command of Frame.Overlay_Rectangles loop
            if Command.X = Root_For_Frame.X
              and then Command.Y = Root_For_Frame.Y
              and then Command.Width = Root_For_Frame.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Border_Color
            then
               Found_Root_Border := True;
            elsif Command.X = Root_For_Frame.X + Root_For_Frame.Width
              and then Command.Y = Root_For_Frame.Y + 3
              and then Command.Width = 3
              and then Command.Height = Root_For_Frame.Height
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Root_Shadow := True;
            end if;
         end loop;

         for Command of Frame.Overlay_Text loop
            if To_String (Command.Text) = "/"
              and then Command.Height = 20
            then
               Found_Root_Text := True;
            end if;
         end loop;

         for Command of Frame.Tooltips loop
            if Ada.Strings.Fixed.Index
              (To_String (Command.Text), Files.Localization.Text ("command.navigate.home.description")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Command.Text),
                 Files.Commands.Shortcut_Text
                   (Files.Commands.Shortcut_For (Files.Commands.Navigate_Home_Command))) > 0
            then
               Found_Home_Tooltip := True;
            elsif Ada.Strings.Fixed.Index
              (To_String (Command.Text), Files.Localization.Text ("command.info.toggle.description")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Command.Text),
                 Files.Commands.Shortcut_Text
                   (Files.Commands.Shortcut_For (Files.Commands.Toggle_Info_Pane_Command))) > 0
            then
               Found_Info_Tooltip := True;
            elsif To_String (Command.Text) = Files.Localization.Text ("command.drive.open_selected.description") then
               Found_Root_Tooltip := True;
            end if;
         end loop;

         for Node of Frame.Accessibility loop
            if Node.Role = Files.Rendering.Role_Window
              and then To_String (Node.Name) = To_String (Snapshot.Current_Path)
            then
               Found_A11y_Window := True;
            elsif Node.Role = Files.Rendering.Role_Toolbar
              and then To_String (Node.Name) = Files.Localization.Text ("accessibility.toolbar")
            then
               Found_A11y_Toolbar := True;
            elsif Node.Role = Files.Rendering.Role_List
              and then To_String (Node.Name) = Files.Localization.Text ("accessibility.main_view")
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("command.view.small")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("status.items") & ": 3") > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("status.visible") & ": 3") > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("status.selected") & ": 1") > 0
            then
               Found_A11y_Main_View_State := True;
            elsif Node.Role = Files.Rendering.Role_Text_Input
              and then To_String (Node.Name) = Files.Localization.Text ("command.path.focus")
            then
               Found_A11y_Path_Input := True;
            elsif Node.Role = Files.Rendering.Role_Text_Input
              and then To_String (Node.Name) = Files.Localization.Text ("command.filter.focus")
              and then To_String (Node.Description) = To_String (Snapshot.Filter_Text)
            then
               Found_A11y_Filter_Input_State := True;
            elsif Node.Role = Files.Rendering.Role_List_Item
              and then Node.Selected
              and then To_String (Node.Name) = "Alpha.txt"
            then
               Found_A11y_Item := True;
               if Node.Focused
                 and then Ada.Strings.Fixed.Index
                   (To_String (Node.Description), Files.Localization.Text ("info.kind.text")) > 0
               then
                  Found_A11y_Item_State := True;
               end if;
            elsif Node.Role = Files.Rendering.Role_List
              and then To_String (Node.Name) = Files.Localization.Text ("accessibility.root_selector")
            then
               Found_A11y_Root := True;
            elsif Node.Role = Files.Rendering.Role_List_Item
              and then Node.Selected
              and then To_String (Node.Description) = "/"
            then
               Found_A11y_Root_Item_State := True;
            elsif Node.Role = Files.Rendering.Role_Status
              and then To_String (Node.Name) = Files.Localization.Text ("error.path.missing")
            then
               Found_A11y_Status := True;
            elsif Node.Role = Files.Rendering.Role_Button
              and then To_String (Node.Name) = Files.Localization.Text ("command.info.toggle")
              and then Node.Selected = Snapshot.Info_Pane_Open
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("command.info.toggle.description")) > 0
            then
               Found_A11y_Info_Toggle_State := True;
            end if;
         end loop;

         for Command of Hover_Frame.Overlay_Text loop
            if Ada.Strings.Fixed.Index
              (To_String (Command.Text), Files.Localization.Text ("command.navigate.home.description")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Command.Text),
                 Files.Commands.Shortcut_Text
                   (Files.Commands.Shortcut_For (Files.Commands.Navigate_Home_Command))) > 0
            then
               Found_Hover_Tooltip_Text := True;
            end if;
         end loop;

         for Command of Hover_Frame.Overlay_Rectangles loop
            if Command.X >= Home_Button_X
              and then Command.Width >= 160
              and then Command.Height > 20
              and then Command.Color = Files.Rendering.Overlay_Color
            then
               Found_Hover_Tooltip_Panel := True;
            end if;
         end loop;

         for Command of Hover_Info_Frame.Overlay_Text loop
            if Ada.Strings.Fixed.Index
                (To_String (Command.Text), Files.Localization.Text ("command.info.toggle.description")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Command.Text),
                 Files.Commands.Shortcut_Text
                   (Files.Commands.Shortcut_For (Files.Commands.Toggle_Info_Pane_Command))) > 0
              and then Command.X + Command.Width <= Hover_Info_Frame.Layout.Width
              and then Command.Y + Command.Height <= Hover_Info_Frame.Layout.Height
              and then Command.X < Hover_Info_X
              and then Command.Y < Hover_Info_Y
            then
               Found_Info_Edge_Tooltip_Text := True;
            end if;
         end loop;

         for Command of Hover_Info_Frame.Overlay_Rectangles loop
            if Command.Color = Files.Rendering.Overlay_Color
              and then Command.Height = 32
              and then Command.X + Command.Width <= Hover_Info_Frame.Layout.Width
              and then Command.Y + Command.Height <= Hover_Info_Frame.Layout.Height
              and then Command.X < Hover_Info_X
              and then Command.Y < Hover_Info_Y
            then
               Found_Info_Edge_Tooltip_Panel := True;
            end if;
         end loop;

         for Command of Pressed_Input_Frame.Rectangles loop
            if Command.X = Toolbar_For_Frame.Middle_X
              and then Command.Y = Files.UI.Toolbar_Input_Y (20)
              and then Command.Width = Toolbar_For_Frame.Middle_Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Pressed_Color
            then
               Found_Pressed_Path_Border := True;
            end if;
         end loop;

         for Command of Hover_Item_Frame.Rectangles loop
            if Command.X = Second_Item.X
              and then Command.Y = Second_Item.Y
              and then Command.Width = Second_Item.Width
              and then Command.Height = Second_Item.Height
              and then Command.Color = Files.Rendering.Hover_Color
            then
               Found_Hover_Item_Fill := True;
            elsif Command.X = Second_Item.X
              and then Command.Y = Second_Item.Y
              and then Command.Width = Second_Item.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Hover_Color
            then
               Found_Hover_Item_Border := True;
            end if;
         end loop;

         for Command of Pressed_Item_Frame.Rectangles loop
            if Command.X = Second_Item.X
              and then Command.Y = Second_Item.Y
              and then Command.Width = Second_Item.Width
              and then Command.Height = Second_Item.Height
              and then Command.Color = Files.Rendering.Pressed_Color
            then
               Found_Pressed_Item_Fill := True;
            elsif Command.X = Second_Item.X
              and then Command.Y = Second_Item.Y
              and then Command.Width = Second_Item.Width
              and then Command.Height = 1
              and then Command.Color = Files.Rendering.Pressed_Color
            then
               Found_Pressed_Item_Border := True;
            end if;
         end loop;

         Assert (Found_Selected_Item, "frame includes selected item rectangle with content inset inside");
         Assert (Found_Selected_Item_Border, "frame renders selected item border");
         Assert (Found_Selected_Item_Accent, "frame renders selected item accent strip");
         Assert (Icon_Geometry_Count >= 3, "frame renders multi-part vector icon geometry");
         Assert (Found_Item_Text, "frame includes item text");
         Assert (Found_Root_Text, "frame includes root-selector text");
         Assert (Found_Left_Toolbar_Icon, "frame renders left toolbar icon as centered icon asset");
         Assert (not Found_Left_Toolbar_Label, "frame keeps left toolbar command labels out of visible text");
         Assert (Found_Bottom_Label, "frame includes localized bottom-bar command label");
         Assert (Found_Disabled_Back_Fill, "frame renders disabled toolbar button fill");
         Assert (Found_Disabled_Back_Border, "frame renders disabled toolbar button border");
         Assert (Found_Selected_Bottom_Border, "frame renders selected bottom-bar button border");
         Assert (Found_Error_Text, "frame renders localized bottom-bar error text");
         Assert (Found_Root_Border, "frame renders bordered root selector panel");
         Assert (Found_Root_Shadow, "frame renders root selector drop shadow");
         Assert (Found_Info_Pane_Top_Edge, "frame renders info-pane top edge polish");
         Assert (Found_Toolbar_Separator, "frame renders toolbar separator polish");
         Assert
           (Found_Toolbar_Left_Path_Separator,
            "frame renders toolbar left and path separator polish");
         Assert
           (Found_Toolbar_Path_Filter_Separator,
            "frame renders toolbar path and filter separator polish");
         Assert (Found_Bottom_Separator, "frame renders bottom-bar separator polish");
         Assert
           (Found_Bottom_View_Info_Separator,
            "frame renders bottom-bar view and info separator polish");
         Assert
           (Found_Bottom_Info_Toggle_Separator,
            "frame renders bottom-bar info and toggle separator polish");
         Assert (Found_Info_Pane_Separator, "frame renders info-pane separator polish");
         Assert (Found_Home_Tooltip, "frame exposes localized toolbar tooltip text");
         Assert (Found_Info_Tooltip, "frame exposes localized bottom-bar tooltip text");
         Assert (Found_Root_Tooltip, "frame exposes localized root-selector tooltip text");
         Assert (Found_Hover_Tooltip_Text, "frame renders localized hover tooltip text");
         Assert (Found_Hover_Tooltip_Panel, "frame renders hover tooltip panel");
         Assert (Found_Info_Edge_Tooltip_Text, "frame keeps info tooltip text inside window edge");
         Assert (Found_Info_Edge_Tooltip_Panel, "frame keeps info tooltip panel inside window edge");
         Assert (Found_Pressed_Path_Border, "frame renders pressed border for path input");
         Assert (Found_Hover_Item_Fill, "frame renders hover fill around padded visible item");
         Assert (Found_Hover_Item_Border, "frame renders hover border around padded visible item");
         Assert (not Found_Pressed_Item_Fill, "frame suppresses transient pressed fill for visible item");
         Assert (not Found_Pressed_Item_Border, "frame suppresses transient pressed border for visible item");
         Assert (Found_A11y_Window, "frame exposes accessible window node");
         Assert (Found_A11y_Toolbar, "frame exposes accessible toolbar node");
         Assert (Found_A11y_Main_View_State, "frame exposes main-view count state to accessibility");
         Assert (Found_A11y_Path_Input, "frame exposes focused path input node");
         Assert (Found_A11y_Filter_Input_State, "frame exposes filter input state to accessibility");
         Assert (Found_A11y_Item, "frame exposes selected item node");
         Assert (Found_A11y_Item_State, "frame exposes selected item metadata to accessibility");
         Assert (Found_A11y_Root, "frame exposes root selector node");
         Assert (Found_A11y_Root_Item_State, "frame exposes selected root path to accessibility");
         Assert (Found_A11y_Status, "frame exposes bottom status node");
         Assert (Found_A11y_Info_Toggle_State, "frame exposes info-pane toggle state to accessibility");
      end;
      Files.Model.Close_Root_Selector (Model);

      declare
         Had_Font_Path : constant Boolean := Ada.Environment_Variables.Exists ("FILES_FONT_PATH");
         Old_Font_Path : constant Unbounded_String :=
           To_Unbounded_String ((if Had_Font_Path then Ada.Environment_Variables.Value ("FILES_FONT_PATH") else ""));
         Override_Font : constant String := Join (Root, "override-font.ttf");
         Valid_Font    : Unbounded_String;

         procedure Restore_Font_Environment is
         begin
            if Had_Font_Path then
               Ada.Environment_Variables.Set ("FILES_FONT_PATH", To_String (Old_Font_Path));
            else
               Ada.Environment_Variables.Clear ("FILES_FONT_PATH");
            end if;
         end Restore_Font_Environment;
      begin
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", "");
         Valid_Font := To_Unbounded_String (Files.Fonts.Default_Font_Path);
         Assert (Length (Valid_Font) > 0, "empty FILES_FONT_PATH falls back to known fonts");
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", To_String (Valid_Font));
         Assert
           (Files.Fonts.Default_Font_Path = To_String (Valid_Font),
            "FILES_FONT_PATH selects a loadable font file override");
         Write_File (Override_Font, "fake font path probe");
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", Override_Font);
         Assert
           (Files.Fonts.Default_Font_Path /= Override_Font,
            "FILES_FONT_PATH rejects ordinary non-font file overrides");
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", Root);
         Assert
           (Files.Fonts.Default_Font_Path /= Root,
            "FILES_FONT_PATH rejects directory overrides");
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", Join (Root, "missing-font.ttf"));
         Assert
           (Files.Fonts.Default_Font_Path /= Join (Root, "missing-font.ttf"),
            "FILES_FONT_PATH ignores missing font overrides");
         Ada.Environment_Variables.Set ("FILES_FONT_PATH", "");
         Assert (Files.Fonts.Default_Font_Path /= "", "empty FILES_FONT_PATH still falls back to known fonts");
         Restore_Font_Environment;
      exception
         when others =>
            Restore_Font_Environment;
            raise;
      end;

      Assert (Files.Fonts.Default_Font_Path /= "", "default text font is available");
      declare
         DejaVu_Mono : constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
      begin
         if Ada.Directories.Exists (DejaVu_Mono) then
            Assert
              (Files.Fonts.Default_Font_Path = DejaVu_Mono,
               "default text font prefers stable monospace UI glyphs");
         end if;
      end;
      declare
         Font : Textrender.Fonts.Font;
      begin
         Assert
           (Textrender.Fonts.Load (Font, Files.Fonts.Default_Font_Path) = Textrender.Fonts.Loaded,
            "default text font is parseable for glyph coverage");
         Assert
           (Textrender.Fonts.Has_Glyph (Font, 16#00E5#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#00E6#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#00E9#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#00F8#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#0301#),
            "default text font directly covers non-ASCII filename glyphs");
         Textrender.Fonts.Reset (Font);
      exception
         when others =>
            Textrender.Fonts.Reset (Font);
            raise;
      end;
      Assert
        (Files.Rendering.Default_Font_Path = Files.Fonts.Default_Font_Path,
         "rendering default font delegates to startup font discovery");
      Assert
        (Files.Fonts.Font_Path_For_Text
           ("caf" & Byte (16#C3#) & Byte (16#A9#) & " "
            & Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
            & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#)) /= "",
         "font discovery can select a font for main-section Unicode filename text");
      declare
         Stable_Renderer : Files.Rendering.Text_Renderer;
         Stable_Frame    : Files.Rendering.Frame_Commands;
         Before_Text     : Files.Rendering.Text_Render_Result;
         After_Text      : Files.Rendering.Text_Render_Result;
         Ignored_Path    : Unbounded_String;
      begin
         Assert
           (Files.Rendering.Initialize_Text
              (Renderer    => Stable_Renderer,
               Font_Path   => Files.Fonts.Default_Font_Path,
               Pixel_Size  => 16,
               Cell_Width  => 10,
               Cell_Height => 20)
            = Files.Rendering.Text_Render_Success,
            "font discovery side-effect test initializes text renderer");
         Stable_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X            => 8,
               Y            => 8,
               Width        => 160,
               Height       => 20,
               Text         => To_Unbounded_String ("stable text"),
               Color        => Files.Rendering.Text_Color,
               Truncated    => False,
               Italic       => False,
               Scale_To_Box => False));
         Before_Text := Files.Rendering.Build_Text_Glyphs (Stable_Renderer, Stable_Frame);
         Assert
           (Before_Text.Status = Files.Rendering.Text_Render_Success
            and then Natural (Before_Text.Glyphs.Length) > 0,
            "text renderer emits glyphs before font discovery");
         Ignored_Path :=
           To_Unbounded_String
             (Files.Fonts.Font_Path_For_Text
                ("caf" & Byte (16#C3#) & Byte (16#A9#) & " "
                 & Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
                 & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#)));
         Assert (Length (Ignored_Path) > 0, "font discovery still returns a usable Unicode font");
         After_Text := Files.Rendering.Build_Text_Glyphs (Stable_Renderer, Stable_Frame);
         Assert
           (After_Text.Status = Files.Rendering.Text_Render_Success
            and then Natural (After_Text.Glyphs.Length) = Natural (Before_Text.Glyphs.Length),
            "font discovery does not reset or replace the active text renderer atlas");
      end;
      declare
         Unicode_Font_Path : constant String :=
           Files.Fonts.Font_Path_For_Text
             ("caf" & Byte (16#C3#) & Byte (16#A9#) & " "
              & Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
              & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#));
         Font : Textrender.Fonts.Font;
         Unicode_Text_Renderer : Files.Rendering.Text_Renderer;
      begin
         Assert
           (Textrender.Fonts.Load (Font, Unicode_Font_Path) = Textrender.Fonts.Loaded,
            "font discovery selected Unicode filename font is loadable");
         Assert
           (Textrender.Fonts.Has_Glyph (Font, 16#00E9#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#0301#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#6587#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#4EF6#),
            "font discovery selected Unicode filename font covers every visible filename glyph");
         Textrender.Fonts.Reset (Font);
         Assert
           (Files.Rendering.Initialize_Text
              (Renderer    => Unicode_Text_Renderer,
               Font_Path   => Unicode_Font_Path,
               Pixel_Size  => 16,
               Cell_Width  => 10,
               Cell_Height => 20)
            = Files.Rendering.Text_Render_Success,
            "font discovery selected Unicode filename font initializes the text renderer");
      exception
         when others =>
            Textrender.Fonts.Reset (Font);
            raise;
      end;
      declare
         Supplementary_Name : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#)) & ".txt";
         Probe_Font_Path : constant String := "/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf";
         Probe_Font     : Textrender.Fonts.Font;
         Selected_Font  : Textrender.Fonts.Font;
         Probe_Loaded   : constant Boolean :=
           Ada.Directories.Exists (Probe_Font_Path)
           and then Textrender.Fonts.Load (Probe_Font, Probe_Font_Path) = Textrender.Fonts.Loaded;
      begin
         if Probe_Loaded and then Textrender.Fonts.Has_Glyph (Probe_Font, 16#1F4C1#) then
            declare
               Selected_Font_Path : constant String := Files.Fonts.Font_Path_For_Text (Supplementary_Name);
            begin
               Textrender.Fonts.Reset (Probe_Font);
               Assert
                 (Selected_Font_Path /= "",
                  "font discovery selects a font for supplementary-plane filename glyphs");
               Assert
                 (Textrender.Fonts.Load (Selected_Font, Selected_Font_Path) = Textrender.Fonts.Loaded,
                  "supplementary-plane filename font is loadable");
               Assert
                 (Textrender.Fonts.Has_Glyph (Selected_Font, 16#1F4C1#),
                  "font discovery scores supplementary-plane filename glyph coverage");
               Textrender.Fonts.Reset (Selected_Font);
            end;
         else
            Textrender.Fonts.Reset (Probe_Font);
         end if;
      exception
         when others =>
            Textrender.Fonts.Reset (Probe_Font);
            Textrender.Fonts.Reset (Selected_Font);
            raise;
      end;
      declare
         Weak_Override : constant String := "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";
         Old_Font_Path : constant Unbounded_String :=
           (if Ada.Environment_Variables.Exists ("FILES_FONT_PATH")
            then To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_FONT_PATH"))
            else Null_Unbounded_String);
         Had_Font_Path : constant Boolean := Ada.Environment_Variables.Exists ("FILES_FONT_PATH");

         procedure Restore_Font_Environment is
         begin
            if Had_Font_Path then
               Ada.Environment_Variables.Set ("FILES_FONT_PATH", To_String (Old_Font_Path));
            else
               Ada.Environment_Variables.Set ("FILES_FONT_PATH", "");
            end if;
         end Restore_Font_Environment;
      begin
         if Ada.Directories.Exists (Weak_Override) then
            declare
               Weak_Font : Textrender.Fonts.Font;
               Weak_Loaded : constant Boolean :=
                 Textrender.Fonts.Load (Weak_Font, Weak_Override) = Textrender.Fonts.Loaded;
               Weak_Misses_CJK : constant Boolean :=
                 Weak_Loaded and then not Textrender.Fonts.Has_Glyph (Weak_Font, 16#6587#);
            begin
               Textrender.Fonts.Reset (Weak_Font);
               if Weak_Misses_CJK then
                  Ada.Environment_Variables.Set ("FILES_FONT_PATH", Weak_Override);
                  declare
                     Selected_Font_Path : constant String :=
                       Files.Fonts.Font_Path_For_Text
                         ("caf" & Byte (16#C3#) & Byte (16#A9#) & " "
                          & Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
                          & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#));
                     Selected_Font : Textrender.Fonts.Font;
                  begin
                     Assert
                       (Selected_Font_Path /= Weak_Override,
                        "weak FILES_FONT_PATH does not pin main-section Unicode filename rendering");
                     Assert
                       (Textrender.Fonts.Load (Selected_Font, Selected_Font_Path) = Textrender.Fonts.Loaded,
                        "weak FILES_FONT_PATH fallback selects a loadable Unicode filename font");
                     Assert
                       (Textrender.Fonts.Has_Glyph (Selected_Font, 16#6587#)
                        and then Textrender.Fonts.Has_Glyph (Selected_Font, 16#4EF6#),
                        "weak FILES_FONT_PATH fallback still covers non-Latin filename glyphs");
                     Textrender.Fonts.Reset (Selected_Font);
                  exception
                     when others =>
                        Textrender.Fonts.Reset (Selected_Font);
                        raise;
                  end;
               end if;
            end;
         end if;
         Restore_Font_Environment;
      exception
         when others =>
            Restore_Font_Environment;
            raise;
      end;
      Assert
        (Files.Rendering.Initialize_Text
           (Renderer    => Text_Renderer,
            Font_Path   => Files.Fonts.Default_Font_Path,
            Pixel_Size  => 16,
            Cell_Width  => 10,
            Cell_Height => 20)
         = Files.Rendering.Text_Render_Success,
         "text renderer loads default font");
      Text_Result := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Frame);
      Assert (Text_Result.Status = Files.Rendering.Text_Render_Success, "frame text rasterizes through textrender");
      Assert (Natural (Text_Result.Glyphs.Length) > 0, "text renderer emits glyph draw commands");
      Assert (Text_Result.Missing_Glyph_Count = 0, "default frame text uses directly mapped glyphs");
      for Glyph of Text_Result.Glyphs loop
         Assert
           (Glyph.X = Float (Integer (Glyph.X))
            and then Glyph.Y = Float (Integer (Glyph.Y))
            and then Glyph.Width = Float (Integer (Glyph.Width))
            and then Glyph.Height = Float (Integer (Glyph.Height)),
            "text renderer snaps glyph rectangles to whole pixels");
      end loop;
      declare
         Edge_Frame : Files.Rendering.Frame_Commands;
         Edge_Text  : Files.Rendering.Text_Render_Result;
      begin
         Edge_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => Natural'Last - 4,
               Y         => 0,
               Width     => 20,
               Height    => 20,
               Text      => To_Unbounded_String ("x"),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Edge_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Edge_Frame);
         Assert
           (Edge_Text.Status = Files.Rendering.Text_Render_Success,
           "text renderer saturates edge text extents");
      end;
      declare
         Icon_Frame : Files.Rendering.Frame_Commands;
         Icon_Text  : Files.Rendering.Text_Render_Result;
         Icon_Glyph : Files.Rendering.Glyph_Command;
      begin
         Icon_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 50,
               Y         => 40,
               Width     => 28,
               Height    => 28,
               Text      => To_Unbounded_String (Files.UTF8.Encode_Codepoint (16#2302#)),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => True));
         Icon_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Icon_Frame);
         Assert
           (Icon_Text.Status = Files.Rendering.Text_Render_Success
            and then Natural (Icon_Text.Glyphs.Length) > 0,
            "box-scaled text rasterizes");
         Icon_Glyph := Icon_Text.Glyphs.Element (1);
         Assert
           (Icon_Glyph.Width > 20.0 or else Icon_Glyph.Height > 20.0,
            "text renderer supports explicit box-scaled glyphs");
      end;
      declare
         Wide_Glyph_Frame : Files.Rendering.Frame_Commands;
         Wide_Glyph_Text  : Files.Rendering.Text_Render_Result;
         Wide_Name        : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#6587#)) & "a";
         Wide_Renderer     : Files.Rendering.Text_Renderer;
         Wide_X           : Float := 0.0;
         ASCII_X          : Float := 0.0;
         Found_Wide       : Boolean := False;
         Found_ASCII      : Boolean := False;
      begin
         Assert
           (Files.Rendering.Initialize_Text
              (Renderer    => Wide_Renderer,
               Font_Path   => Files.Fonts.Font_Path_For_Text (Wide_Name),
               Pixel_Size  => 16,
               Cell_Width  => 10,
               Cell_Height => 20)
            = Files.Rendering.Text_Render_Success,
            "wide glyph spacing text initializes a frame-specific font");
         Wide_Glyph_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 100,
               Y         => 0,
               Width     => 80,
               Height    => 20,
               Text      => To_Unbounded_String (Wide_Name),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Wide_Glyph_Text := Files.Rendering.Build_Text_Glyphs (Wide_Renderer, Wide_Glyph_Frame);
         for Glyph of Wide_Glyph_Text.Glyphs loop
            if Glyph.Codepoint = 16#6587# then
               Wide_X := Glyph.X;
               Found_Wide := True;
            elsif Glyph.Codepoint = Character'Pos ('a') then
               ASCII_X := Glyph.X;
               Found_ASCII := True;
            end if;
         end loop;
         Assert (Wide_Glyph_Text.Status = Files.Rendering.Text_Render_Success, "wide glyph spacing text rasterizes");
         Assert (Found_Wide and then Found_ASCII, "wide glyph spacing test emits both glyphs");
         Assert
           (ASCII_X - Wide_X > 12.0,
            "text renderer advances after CJK glyphs by wide display cells");
         Assert
           (Wide_X < 105.0,
            "text renderer anchors CJK glyphs at the reserved wide-cell origin");
      end;
      declare
         Combining_Glyph_Frame : Files.Rendering.Frame_Commands;
         Combining_Glyph_Text  : Files.Rendering.Text_Render_Result;
         Combining_Name        : constant String :=
           "e" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#));
         Base_X                : Float := 0.0;
         Mark_X                : Float := 0.0;
         Found_Base            : Boolean := False;
         Found_Mark            : Boolean := False;
         Found_Fallback        : Boolean := False;
      begin
         Combining_Glyph_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 100,
               Y         => 0,
               Width     => 80,
               Height    => 20,
               Text      => To_Unbounded_String (Combining_Name),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Combining_Glyph_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Combining_Glyph_Frame);
         for Glyph of Combining_Glyph_Text.Glyphs loop
            if Glyph.Codepoint = Character'Pos ('e') then
               Base_X := Glyph.X;
               Found_Base := True;
            elsif Glyph.Codepoint = 16#0301# then
               Mark_X := Glyph.X;
               Found_Mark := True;
            elsif Glyph.Codepoint = Character'Pos ('?') then
               Found_Fallback := True;
            end if;
         end loop;
         Assert
           (Combining_Glyph_Text.Status = Files.Rendering.Text_Render_Success,
            "combining glyph spacing text rasterizes");
         Assert (Found_Base, "combining glyph spacing test emits base glyph");
         Assert
           (Combining_Glyph_Text.Missing_Glyph_Count = 0,
            "combining glyph spacing accounts for required zero-width marks");
         Assert
           (not Found_Fallback,
            "combining glyph spacing does not emit a visible fallback marker for zero-width marks");
         Assert
           (not Found_Mark or else Mark_X < Base_X + 8.0,
            "text renderer places combining marks on the previous base cell");
      end;
      declare
         Utf8_Item_Snapshot : Files.Rendering.View_Snapshot;
         Utf8_Item_Frame    : Files.Rendering.Frame_Commands;
         Utf8_Item_Text     : Files.Rendering.Text_Render_Result;
         Found_E_Acute      : Boolean := False;
         Found_Byte_C3      : Boolean := False;
         Found_Byte_A9      : Boolean := False;
      begin
         Utf8_Item_Snapshot.Current_Path := To_Unbounded_String (Root);
         Utf8_Item_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Utf8_Item_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Utf8_Item_Snapshot,
              Width       => 300,
              Height      => 120,
              Line_Height => 20);
         Utf8_Item_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Utf8_Item_Frame);

         for Glyph of Utf8_Item_Text.Glyphs loop
            if Glyph.Codepoint = 16#00E9# then
               Found_E_Acute := True;
            elsif Glyph.Codepoint = 16#00C3# then
               Found_Byte_C3 := True;
            elsif Glyph.Codepoint = 16#00A9# then
               Found_Byte_A9 := True;
            end if;
         end loop;

         Assert
           (Utf8_Item_Text.Status = Files.Rendering.Text_Render_Success,
            "text renderer rasterizes UTF-8 item names");
         Assert
           (Utf8_Item_Text.Missing_Glyph_Count = 0,
            "main-section UTF-8 item name renders without missing-glyph fallback");
         Assert (Found_E_Acute, "main-section UTF-8 item name emits Unicode glyph codepoint");
         Assert
           (not Found_Byte_C3 and then not Found_Byte_A9,
            "main-section UTF-8 item name is not rendered as byte codepoints");
      end;
      declare
         Legacy_Item_Snapshot : Files.Rendering.View_Snapshot;
         Legacy_Item_Frame    : Files.Rendering.Frame_Commands;
         Legacy_Item_Text     : Files.Rendering.Text_Render_Result;
         Found_AE             : Boolean := False;
         Found_Replacement    : Boolean := False;
      begin
         Legacy_Item_Snapshot.Current_Path := To_Unbounded_String (Root);
         Legacy_Item_Snapshot.Items.Append
           (Files.Rendering.Item_Snapshot'
              (Name          => To_Unbounded_String ("legacy-" & Byte (16#E6#) & ".txt"),
               Filetype      => To_Unbounded_String ("text/plain"),
               Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
               Icon_Id       => To_Unbounded_String ("text"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => 1,
               others        => <>));
         Legacy_Item_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Legacy_Item_Snapshot,
              Width       => 300,
              Height      => 120,
              Line_Height => 20);
         Legacy_Item_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Legacy_Item_Frame);

         for Glyph of Legacy_Item_Text.Glyphs loop
            if Glyph.Codepoint = 16#00E6# then
               Found_AE := True;
            elsif Glyph.Codepoint = 16#FFFD# then
               Found_Replacement := True;
            end if;
         end loop;

         Assert
           (Legacy_Item_Text.Status = Files.Rendering.Text_Render_Success,
            "main-section legacy non-ASCII item name rasterizes");
         Assert
           (Found_AE,
            "main-section legacy non-ASCII item name emits Latin-1 fallback glyph");
         Assert
           (not Found_Replacement,
            "main-section legacy non-ASCII item name is not rendered as replacement glyphs");
      end;
      declare
         Missing_Glyph_Frame : Files.Rendering.Frame_Commands;
         Missing_Glyph_Text  : Files.Rendering.Text_Render_Result;
         Missing_Name        : constant String :=
           "missing-"
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#10FFFF#))
           & ".txt";
         Found_Fallback      : Boolean := False;
      begin
         Missing_Glyph_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 100,
               Y         => 0,
               Width     => 160,
               Height    => 20,
               Text      => To_Unbounded_String (Missing_Name),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Missing_Glyph_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Missing_Glyph_Frame);

         for Glyph of Missing_Glyph_Text.Glyphs loop
            if Glyph.Codepoint = Character'Pos ('?') then
               Found_Fallback := True;
            end if;
         end loop;

         Assert
           (Missing_Glyph_Text.Status = Files.Rendering.Text_Render_Success,
            "missing filename glyph fallback rasterizes successfully");
         Assert
           (Missing_Glyph_Text.Missing_Glyph_Count = 1,
            "missing filename glyph fallback is still reported");
         Assert
           (Found_Fallback,
            "missing filename glyph emits a visible replacement marker");
      end;
      declare
         Emoji_Frame : Files.Rendering.Frame_Commands;
         Emoji_Text  : Files.Rendering.Text_Render_Result;
         Emoji_Name  : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#)) & ".txt";
         Found_Fallback : Boolean := False;
      begin
         Emoji_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 100,
               Y         => 0,
               Width     => 160,
               Height    => 20,
               Text      => To_Unbounded_String (Emoji_Name),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Emoji_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Emoji_Frame);

         for Glyph of Emoji_Text.Glyphs loop
            if Glyph.Codepoint = Character'Pos ('?') then
               Found_Fallback := True;
            end if;
         end loop;

         Assert
           (Emoji_Text.Status = Files.Rendering.Text_Render_Success,
            "emoji filename glyph fallback does not abort main-section text rendering");
         Assert
           (Natural (Emoji_Text.Glyphs.Length) > 0,
            "emoji filename fallback still emits visible filename glyphs");
         Assert
           (Found_Fallback or else Emoji_Text.Missing_Glyph_Count > 0,
            "emoji filename renders directly, emits a marker, or records a skipped missing glyph");
      end;
      declare
         Variation_Frame : Files.Rendering.Frame_Commands;
         Variation_Text  : Files.Rendering.Text_Render_Result;
         Variation_Name  : constant String :=
           "icon"
           & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#FE0F#))
           & ".txt";
         Found_Fallback  : Boolean := False;
      begin
         Variation_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 100,
               Y         => 0,
               Width     => 160,
               Height    => 20,
               Text      => To_Unbounded_String (Variation_Name),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Variation_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Variation_Frame);

         for Glyph of Variation_Text.Glyphs loop
            if Glyph.Codepoint = Character'Pos ('?') then
               Found_Fallback := True;
            end if;
         end loop;

         Assert
           (Variation_Text.Status = Files.Rendering.Text_Render_Success,
            "variation-selector filename text rasterizes successfully");
         Assert
           (not Found_Fallback,
            "variation-selector filename text does not emit visible fallback marker");
      end;
      declare
         type View_Mode_List is array (Positive range <>) of Files.Types.View_Mode;

         Utf8_Name : constant String := "caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt";
         Wide_Name : constant String :=
           Byte (16#E6#) & Byte (16#96#) & Byte (16#87#)
           & Byte (16#E4#) & Byte (16#BB#) & Byte (16#B6#)
           & ".txt";
         Modes     : constant View_Mode_List :=
           [Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details];
      begin
         for Mode of Modes loop
            declare
               Mode_Snapshot : Files.Rendering.View_Snapshot;
               Mode_Frame    : Files.Rendering.Frame_Commands;
               Mode_Text     : Files.Rendering.Text_Render_Result;
               Mode_Batch    : Files.Rendering.Vulkan.Submission_Batch;
               Found_Name_Glyph : Boolean := False;
               Found_Wide_Glyph : Boolean := False;
               Found_Byte_C3    : Boolean := False;
               Found_Byte_A9    : Boolean := False;
            begin
               Mode_Snapshot.Current_Path := To_Unbounded_String (Root);
               Mode_Snapshot.View_Mode := Mode;
               Mode_Snapshot.Items.Append
                 (Files.Rendering.Item_Snapshot'
                    (Name          => To_Unbounded_String (Utf8_Name),
                     Filetype      => To_Unbounded_String ("text/plain"),
                     Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
                     Icon_Id       => To_Unbounded_String ("text"),
                     Kind          => Files.Types.Regular_File_Item,
                     Visible_Index => 1,
                     others        => <>));
               Mode_Snapshot.Items.Append
                 (Files.Rendering.Item_Snapshot'
                    (Name          => To_Unbounded_String (Wide_Name),
                     Filetype      => To_Unbounded_String ("text/plain"),
                     Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
                     Icon_Id       => To_Unbounded_String ("text"),
                     Kind          => Files.Types.Regular_File_Item,
                     Visible_Index => 2,
                     others        => <>));
               Mode_Frame :=
                 Files.Rendering.Build_Frame_Commands
                   (Mode_Snapshot,
                    Width       => 360,
                    Height      => 200,
                    Line_Height => 20);
               declare
                  Mode_Font_Path : constant String := Files.Rendering.Font_Path_For_Frame (Mode_Frame);
               begin
                  Assert
                    (Mode_Font_Path /= "",
                     "frame text selects a concrete font path for main-section Unicode item names");
                  Assert
                    (Files.Rendering.Initialize_Text
                       (Renderer    => Text_Renderer,
                        Font_Path   => Mode_Font_Path,
                        Pixel_Size  => 16,
                        Cell_Width  => 10,
                        Cell_Height => 20)
                     = Files.Rendering.Text_Render_Success,
                     "frame text initializes the selected Unicode item-name font");
               end;
               Mode_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Mode_Frame);
               Mode_Batch := Files.Rendering.Vulkan.Build_Submission (Mode_Frame, Mode_Text);

               for Glyph of Mode_Text.Glyphs loop
                  if Glyph.Codepoint = 16#00E9# then
                     Found_Name_Glyph := True;
                  elsif Glyph.Codepoint = 16#6587# or else Glyph.Codepoint = 16#4EF6# then
                     Found_Wide_Glyph := True;
                  elsif Glyph.Codepoint = 16#00C3# then
                     Found_Byte_C3 := True;
                  elsif Glyph.Codepoint = 16#00A9# then
                     Found_Byte_A9 := True;
                  end if;
               end loop;

               Assert
                 (Mode_Text.Status = Files.Rendering.Text_Render_Success,
                  "main-section UTF-8 item names rasterize in every view mode");
               Assert
                 (Mode_Text.Missing_Glyph_Count = 0,
                  "main-section Unicode item names render without missing-glyph fallback in every view mode");
               Assert
                 (Found_Name_Glyph,
                  "main-section UTF-8 item names emit Unicode glyphs in every view mode");
               Assert
                 (Found_Wide_Glyph,
                  "main-section non-Latin item names emit visible Unicode glyphs in every view mode");
               Assert
                 (not Found_Byte_C3 and then not Found_Byte_A9,
                  "main-section UTF-8 item names never emit raw byte glyphs");
               Assert
                 (Mode_Batch.Glyph_Vertex_Count > 0,
                  "main-section UTF-8 item name glyphs reach Vulkan submission");
            end;
         end loop;
      end;
      Assert (Text_Result.Atlas_Width = 1024, "text renderer reports atlas width");
      Assert (Text_Result.Atlas_Height = 1024, "text renderer reports atlas height");
      Assert (Text_Result.Atlas_Pixels /= System.Null_Address, "text renderer exposes atlas pixels");
      Assert (Text_Result.Atlas_Bytes = 1024 * 1024, "text renderer reports atlas byte count");
      Assert (Text_Result.Atlas_Dirty, "text renderer reports dirty atlas after glyph rasterization");

      Vulkan_Batch := Files.Rendering.Vulkan.Build_Submission (Frame, Text_Result);
      Assert (Vulkan_Batch.Width = Frame.Layout.Width, "vulkan batch preserves frame width");
      Assert (Vulkan_Batch.Height = Frame.Layout.Height, "vulkan batch preserves frame height");
      Assert (Vulkan_Batch.Atlas_Width = Text_Result.Atlas_Width, "vulkan batch preserves atlas width");
      Assert (Vulkan_Batch.Atlas_Height = Text_Result.Atlas_Height, "vulkan batch preserves atlas height");
      Assert (Vulkan_Batch.Atlas_Pixels = Text_Result.Atlas_Pixels, "vulkan batch preserves atlas pixels");
      Assert (Vulkan_Batch.Atlas_Bytes = Text_Result.Atlas_Bytes, "vulkan batch preserves atlas byte count");
      Assert (Vulkan_Batch.Atlas_Dirty, "vulkan batch preserves dirty atlas state");
      Assert
        (Vulkan_Batch.Rectangle_Vertex_Count = Natural (Frame.Rectangles.Length) * 6,
         "vulkan batch expands each rectangle to two triangles");
      Assert
        (Vulkan_Batch.Triangle_Vertex_Count = Natural (Frame.Triangles.Length) * 3,
         "vulkan batch expands each triangle command to one triangle");
      Assert
        (Vulkan_Batch.Icon_Vertex_Count = Vulkan_Drawable_Icon_Count (Frame) * 6,
         "vulkan mixed batch preserves drawable icon vertices alongside text");
      Assert
        (Vulkan_Batch.Icon_Quad_Count = Vulkan_Drawable_Icon_Count (Frame),
         "vulkan mixed batch preserves drawable icon draw count alongside text");
      Assert
        (Vulkan_Batch.Icon_Atlas_Bytes = Natural (Vulkan_Batch.Icon_Atlas_Pixels.Length),
         "vulkan mixed batch keeps icon atlas byte count and payload aligned");
      Assert
        (Vulkan_Batch.Icon_Atlas_Bytes > 0,
         "vulkan mixed batch builds a usable separate icon atlas payload");
      Assert
        (Vulkan_Batch.Icon_Atlas_Dirty,
         "vulkan mixed batch keeps icon atlas dirty while text atlas is active");
      Assert (Vulkan_Batch.Text_Atlas_Used, "vulkan batch records glyph use of the text atlas");
      Assert (Vulkan_Batch.Texture_Count = 2, "vulkan mixed batch records text and icon texture payloads");
      Assert
        (Vulkan_Batch.Uses_Separate_Text_And_Icon_Textures,
         "vulkan mixed batch routes separate text and icon textures");
      Assert
        (Vulkan_Batch.Icon_Texture_Format = Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
         "vulkan mixed batch records independent RGBA icon texture format");
      Assert
        (Files.Rendering.Vulkan.Upload_Texture_Format (Vulkan_Batch) =
         Files.Rendering.Vulkan.Atlas_Texture_R8,
         "vulkan mixed batch keeps text atlas upload on the current descriptor path");
      Assert
        (Files.Rendering.Vulkan.Icon_Upload_Texture_Format (Vulkan_Batch) =
         Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
         "vulkan mixed batch exposes separate RGBA icon upload");
      Assert
        (Project_Tools.Files.File_Contains
           ("src/files-rendering-vulkan.adb",
            "Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT")
         or else
           Project_Tools.Files.File_Contains
             ("../src/files-rendering-vulkan.adb",
              "Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT")
         or else
           Project_Tools.Files.File_Contains
             ("../../src/files-rendering-vulkan.adb",
             "Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT"),
         "vulkan swapchain images opt into transfer-source usage for framebuffer readback");
      Assert
        (Project_Tools.Files.File_Contains ("src/files-rendering-vulkan.adb", "Cmd_Copy_Image_To_Buffer")
         or else Project_Tools.Files.File_Contains ("../src/files-rendering-vulkan.adb", "Cmd_Copy_Image_To_Buffer")
         or else Project_Tools.Files.File_Contains
           ("../../src/files-rendering-vulkan.adb", "Cmd_Copy_Image_To_Buffer"),
         "vulkan command buffers copy rendered swapchain images into readback buffers");
      Assert
        (Project_Tools.Files.File_Contains ("src/files-rendering-vulkan.adb", "Capture_Completed_Readback")
         or else Project_Tools.Files.File_Contains
           ("../src/files-rendering-vulkan.adb", "Capture_Completed_Readback")
         or else Project_Tools.Files.File_Contains
           ("../../src/files-rendering-vulkan.adb", "Capture_Completed_Readback"),
         "vulkan present path hashes completed framebuffer readback buffers");
      declare
         Reference_Batch : constant Files.Rendering.Vulkan.Submission_Batch :=
           Files.Rendering.Vulkan.Build_Submission (Frame, Text_Result);
         Mutated_Batch : Files.Rendering.Vulkan.Submission_Batch := Reference_Batch;
         Match_Result : Files.Rendering.Vulkan.Gpu_Screenshot_Comparison;
         Mismatch_Result : Files.Rendering.Vulkan.Gpu_Screenshot_Comparison;
      begin
         Match_Result := Files.Rendering.Vulkan.Compare_Gpu_Screenshot (Vulkan_Batch, Reference_Batch);
         Assert (Match_Result.Supported, "GPU screenshot comparison is available headlessly");
         Assert (Match_Result.Matched, "GPU screenshot comparison matches identical Vulkan batches");
         Assert
           (Match_Result.Compared_Vertices = Natural (Vulkan_Batch.Vertices.Length),
            "GPU screenshot comparison records compared vertex count");
         if not Mutated_Batch.Vertices.Is_Empty then
            declare
               First : Files.Rendering.Vulkan.Vertex := Mutated_Batch.Vertices.First_Element;
            begin
               First.Color := Files.Rendering.Error_Text_Color;
               Mutated_Batch.Vertices.Replace_Element (Mutated_Batch.Vertices.First_Index, First);
            end;
         end if;
         Mismatch_Result := Files.Rendering.Vulkan.Compare_Gpu_Screenshot (Vulkan_Batch, Mutated_Batch);
         Assert (not Mismatch_Result.Matched, "GPU screenshot comparison detects changed vertex colors");
         Assert
           (Mismatch_Result.Actual_Hash /= Mismatch_Result.Expected_Hash,
            "GPU screenshot comparison reports distinct hashes for mismatches");
      end;
      declare
         Clean_Text_Atlas : Files.Rendering.Text_Render_Result := Text_Result;
         Clean_Mixed_Batch : Files.Rendering.Vulkan.Submission_Batch;
      begin
         Clean_Text_Atlas.Atlas_Dirty := False;
         Clean_Mixed_Batch := Files.Rendering.Vulkan.Build_Submission (Frame, Clean_Text_Atlas);
         Assert
           (Clean_Mixed_Batch.Text_Atlas_Used,
            "vulkan clean mixed batch still records text atlas use");
         Assert
           (Files.Rendering.Vulkan.Upload_Texture_Format (Clean_Mixed_Batch) =
            Files.Rendering.Vulkan.Atlas_Texture_R8,
            "vulkan clean mixed batch keeps text atlas bound");
         Assert
           (Files.Rendering.Vulkan.Icon_Upload_Texture_Format (Clean_Mixed_Batch) =
            Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
            "vulkan clean mixed batch keeps icon atlas upload available");
      end;
      Assert
        (Vulkan_Batch.Glyph_Vertex_Count = Natural (Text_Result.Glyphs.Length) * 6,
         "vulkan batch expands each glyph to two triangles");
      Assert
        (Vulkan_Batch.Overlay_Vertex_Count =
         (Natural (Frame.Overlay_Rectangles.Length) + Natural (Text_Result.Overlay_Glyphs.Length)) * 6,
         "vulkan batch expands overlay rectangles and glyphs after normal content");
      Assert
        (Natural (Vulkan_Batch.Vertices.Length) =
         Vulkan_Batch.Rectangle_Vertex_Count + Vulkan_Batch.Triangle_Vertex_Count + Vulkan_Batch.Icon_Vertex_Count +
         Vulkan_Batch.Glyph_Vertex_Count + Vulkan_Batch.Overlay_Vertex_Count,
         "vulkan batch vertex count matches rectangle, triangle, icon, glyph, and overlay vertices");
      Assert (Vulkan_Batch.Vertices.Element (1).X = -1.0, "first vertex is normalized to left edge");
      Assert (Vulkan_Batch.Vertices.Element (1).Y = 1.0, "first vertex is normalized to top edge");

      declare
         Overlay_Frame : Files.Rendering.Frame_Commands;
         Overlay_Text  : Files.Rendering.Text_Render_Result;
         Overlay_Batch : Files.Rendering.Vulkan.Submission_Batch;
      begin
         Overlay_Frame.Layout := Frame.Layout;
         Overlay_Frame.Rectangles.Append
           (Files.Rendering.Rectangle_Command'
              (X      => 0,
               Y      => 0,
               Width  => 20,
               Height => 20,
               Color  => Files.Rendering.Main_Color));
         Overlay_Frame.Text.Append
           (Files.Rendering.Text_Command'
              (X         => 0,
               Y         => 0,
               Width     => 40,
               Height    => 20,
               Text      => To_Unbounded_String ("main"),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Overlay_Frame.Overlay_Rectangles.Append
           (Files.Rendering.Rectangle_Command'
              (X      => 0,
               Y      => 0,
               Width  => 80,
               Height => 20,
               Color  => Files.Rendering.Overlay_Color));
         Overlay_Frame.Overlay_Text.Append
           (Files.Rendering.Text_Command'
              (X         => 0,
               Y         => 0,
               Width     => 80,
               Height    => 20,
               Text      => To_Unbounded_String ("tip"),
               Color     => Files.Rendering.Text_Color,
               Truncated => False,
               Italic       => False,
               Scale_To_Box => False));
         Overlay_Text := Files.Rendering.Build_Text_Glyphs (Text_Renderer, Overlay_Frame);
         Overlay_Batch := Files.Rendering.Vulkan.Build_Submission (Overlay_Frame, Overlay_Text);
         Assert
           (Overlay_Text.Status = Files.Rendering.Text_Render_Success
            and then Natural (Overlay_Text.Overlay_Glyphs.Length) > 0,
            "text renderer emits tooltip overlay glyphs separately");
         Assert
           (Overlay_Batch.Overlay_Vertex_Count =
            (Natural (Overlay_Frame.Overlay_Rectangles.Length) + Natural (Overlay_Text.Overlay_Glyphs.Length)) * 6,
            "vulkan batch accounts for tooltip overlay vertices");
         Assert
           (Overlay_Batch.Overlay_Vertex_Count > 0
            and then Natural (Overlay_Batch.Vertices.Length) >= Overlay_Batch.Overlay_Vertex_Count
            and then Overlay_Batch.Vertices.Last_Element.Color = Files.Rendering.Text_Color,
            "vulkan batch appends tooltip overlay text after normal content");
      end;

      declare
         Found_Textured : Boolean := False;
         Found_Text_Texture_Vertex : Boolean := False;
         Found_Icon_Texture_Vertex : Boolean := False;
      begin
         for Vertex of Vulkan_Batch.Vertices loop
            if Vertex.Textured then
               Found_Textured := True;
            end if;
            if Vertex.Texture = Files.Rendering.Vulkan.Texture_Text_Atlas then
               Found_Text_Texture_Vertex := True;
            elsif Vertex.Texture = Files.Rendering.Vulkan.Texture_Icon_Atlas then
               Found_Icon_Texture_Vertex := True;
            end if;
         end loop;

         Assert (Found_Textured, "vulkan batch includes textured glyph vertices");
         Assert (Found_Text_Texture_Vertex, "vulkan batch marks glyph vertices with the text atlas");
         Assert
           (Found_Icon_Texture_Vertex,
            "vulkan mixed batch marks icon vertices with the icon atlas");
      end;

      declare
         Empty_Text : Files.Rendering.Text_Render_Result;
         Rect_Only  : constant Files.Rendering.Vulkan.Submission_Batch :=
           Files.Rendering.Vulkan.Build_Submission (Frame, Empty_Text);
         Found_Textured : Boolean := False;
      begin
         for Vertex of Rect_Only.Vertices loop
            if Vertex.Textured then
               Found_Textured := True;
            end if;
         end loop;

         Assert (Rect_Only.Glyph_Vertex_Count = 0, "vulkan icon-only batch has no glyph vertices");
         Assert
           (Rect_Only.Icon_Vertex_Count = Vulkan_Drawable_Icon_Count (Frame) * 6,
            "vulkan icon-only batch preserves themed non-toolbar icon vertices");
         Assert
           (Rect_Only.Icon_Quad_Count = Vulkan_Drawable_Icon_Count (Frame),
            "vulkan icon-only batch preserves themed non-toolbar icon draw count");
         Assert (Rect_Only.Atlas_Pixels = System.Null_Address, "vulkan rectangle-only batch has no atlas pixels");
         Assert (Rect_Only.Atlas_Bytes = 0, "vulkan rectangle-only batch has no atlas byte payload");
         Assert (not Rect_Only.Atlas_Dirty, "vulkan rectangle-only batch leaves atlas clean");
         Assert (not Rect_Only.Text_Atlas_Used, "vulkan icon-only batch does not use the text atlas");
         Assert
           (Rect_Only.Icon_Atlas_Bytes = Natural (Rect_Only.Icon_Atlas_Pixels.Length),
            "vulkan icon-only batch keeps icon atlas byte count and payload aligned");
         Assert (Rect_Only.Icon_Atlas_Dirty, "vulkan icon-only batch still uploads an icon atlas");
         Assert (Rect_Only.Texture_Count = 1, "vulkan icon-only batch records one logical texture");
         Assert
           (Rect_Only.Icon_Texture_Format = Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
            "vulkan icon-only batch records RGBA icon texture format");
         Assert
           (Files.Rendering.Vulkan.Upload_Texture_Format (Rect_Only) =
            Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
            "vulkan icon-only batch uploads colored icons as RGBA8");
         Assert
           (Files.Rendering.Vulkan.Icon_Upload_Texture_Format (Rect_Only) =
            Files.Rendering.Vulkan.Atlas_Texture_RGBA8,
            "vulkan icon-only batch exposes RGBA icon upload format");
         Assert (Found_Textured, "vulkan icon-only batch includes textured icon vertices");
      end;

      declare
         Empty_Text    : Files.Rendering.Text_Render_Result;
         Toolbar_Frame : Files.Rendering.Frame_Commands;
         Toolbar_Batch : Files.Rendering.Vulkan.Submission_Batch;
      begin
         Toolbar_Frame.Layout.Width := 64;
         Toolbar_Frame.Layout.Height := 64;
         Toolbar_Frame.Icons.Append
           (Files.Rendering.Icon_Command'
              (X          => 8,
               Y          => 8,
               Size       => 32,
               Icon_Id    => To_Unbounded_String ("toolbar-home"),
               Theme_Name => To_Unbounded_String ("default"),
               Asset_Path => Null_Unbounded_String,
               Thumbnail_Width  => 0,
               Thumbnail_Height => 0,
               Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
         Toolbar_Frame.Rectangles.Append
           (Files.Rendering.Rectangle_Command'
              (X      => 8,
               Y      => 8,
               Width  => 32,
               Height => 32,
               Color  => Files.Rendering.Text_Color));
         Toolbar_Batch := Files.Rendering.Vulkan.Build_Submission (Toolbar_Frame, Empty_Text);
         Assert
           (Toolbar_Batch.Icon_Quad_Count = 0
            and then Toolbar_Batch.Icon_Vertex_Count = 0
            and then not Toolbar_Batch.Icon_Atlas_Dirty,
            "vulkan skips toolbar icon atlas quads so vector toolbar icons stay visible");
      end;

      declare
         Empty_Text   : Files.Rendering.Text_Render_Result;
         Folder_Frame : Files.Rendering.Frame_Commands;
         Folder_Batch : Files.Rendering.Vulkan.Submission_Batch;
         Pixel_Offset : constant Positive := Positive (((12 * 64) + 2) * 4 + 1);
      begin
         Folder_Frame.Layout.Width := 64;
         Folder_Frame.Layout.Height := 64;
         Folder_Frame.Icons.Append
           (Files.Rendering.Icon_Command'
              (X          => 0,
               Y          => 0,
               Size       => 64,
               Icon_Id    => To_Unbounded_String ("folder"),
               Theme_Name => To_Unbounded_String ("default"),
               Asset_Path => Null_Unbounded_String,
               Thumbnail_Width  => 0,
               Thumbnail_Height => 0,
               Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
         Folder_Batch := Files.Rendering.Vulkan.Build_Submission (Folder_Frame, Empty_Text);
         Assert
           (Folder_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset) = 82
            and then Folder_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 1) = 128
            and then Folder_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 2) = 209
            and then Folder_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 3) = 255,
            "vulkan folder icon atlas uses directory blue base color");
      end;

      declare
         Empty_Text : Files.Rendering.Text_Render_Result;
         Skipped_Icon_Frame : Files.Rendering.Frame_Commands;
         Skipped_Icon_Batch : Files.Rendering.Vulkan.Submission_Batch;
      begin
         Skipped_Icon_Frame.Layout.Width := 64;
         Skipped_Icon_Frame.Layout.Height := 64;
         Skipped_Icon_Frame.Icons.Append
           (Files.Rendering.Icon_Command'
              (X          => 0,
               Y          => 0,
               Size       => 0,
               Icon_Id    => To_Unbounded_String ("image"),
               Theme_Name => To_Unbounded_String ("default"),
               Asset_Path => Null_Unbounded_String,
               Thumbnail_Width  => 0,
               Thumbnail_Height => 0,
               Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
         Skipped_Icon_Frame.Icons.Append
           (Files.Rendering.Icon_Command'
              (X          => 16,
               Y          => 16,
               Size       => 16,
               Icon_Id    => To_Unbounded_String ("ada"),
               Theme_Name => To_Unbounded_String ("default"),
               Asset_Path => Null_Unbounded_String,
               Thumbnail_Width  => 0,
               Thumbnail_Height => 0,
               Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
         Skipped_Icon_Batch := Files.Rendering.Vulkan.Build_Submission (Skipped_Icon_Frame, Empty_Text);
         Assert
           (Skipped_Icon_Batch.Icon_Quad_Count = 1,
            "vulkan skipped source icon batch emits one visible icon quad");
         Assert
           (Skipped_Icon_Batch.Vertices.Element (1).Texture = Files.Rendering.Vulkan.Texture_Icon_Atlas,
            "vulkan skipped source icon batch still uses the icon atlas");
         Assert
           (Skipped_Icon_Batch.Vertices.Element (1).U = 0.5,
            "vulkan skipped source icon batch advances source atlas tile coordinates");
      end;

      declare
         Empty_Text : Files.Rendering.Text_Render_Result;
         Large_Icon_Frame : Files.Rendering.Frame_Commands;
         Large_Icon_Batch : Files.Rendering.Vulkan.Submission_Batch;
         Found_Textured_Icon : Boolean := False;
      begin
         Large_Icon_Frame.Layout.Width := 640;
         Large_Icon_Frame.Layout.Height := 480;
         for Index in 1 .. 4_097 loop
            Large_Icon_Frame.Icons.Append
              (Files.Rendering.Icon_Command'
                 (X          => 0,
                  Y          => 0,
                  Size       => 16,
                  Icon_Id    => To_Unbounded_String ("text"),
                  Theme_Name => To_Unbounded_String ("default"),
                  Asset_Path => Null_Unbounded_String,
                  Thumbnail_Width  => 0,
                  Thumbnail_Height => 0,
                  Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector));
         end loop;

         Large_Icon_Batch := Files.Rendering.Vulkan.Build_Submission (Large_Icon_Frame, Empty_Text);
         for Vertex of Large_Icon_Batch.Vertices loop
            if Vertex.Texture = Files.Rendering.Vulkan.Texture_Icon_Atlas then
               Found_Textured_Icon := True;
            end if;
         end loop;

         Assert (Large_Icon_Batch.Icon_Atlas_Bytes = 0, "oversized icon batch skips icon atlas allocation");
         Assert (not Large_Icon_Batch.Icon_Atlas_Dirty, "oversized icon batch leaves icon atlas clean");
         Assert
           (Large_Icon_Batch.Icon_Texture_Format = Files.Rendering.Vulkan.Atlas_Texture_None,
            "oversized icon batch records no icon texture format");
         Assert
           (Large_Icon_Batch.Icon_Vertex_Count = 0,
            "oversized icon batch skips covered fallback icon geometry");
         Assert (not Found_Textured_Icon, "oversized icon batch emits no fallback icon quads");
      end;

      declare
         Empty_Text : Files.Rendering.Text_Render_Result;
         Large_Rect_Frame : Files.Rendering.Frame_Commands;
         Large_Rect_Batch : Files.Rendering.Vulkan.Submission_Batch;
      begin
         Large_Rect_Frame.Layout.Width := 640;
         Large_Rect_Frame.Layout.Height := 480;
         for Index in 1 .. 11_000 loop
            Large_Rect_Frame.Rectangles.Append
              (Files.Rendering.Rectangle_Command'
                 (X      => 0,
                  Y      => 0,
                  Width  => 1,
                  Height => 1,
                  Color  => Files.Rendering.Canvas_Color));
         end loop;

         Large_Rect_Batch := Files.Rendering.Vulkan.Build_Submission (Large_Rect_Frame, Empty_Text);
         Assert
           (Natural (Large_Rect_Batch.Vertices.Length) <= 65_536,
            "oversized rectangle batch caps vertices before GPU upload");
         Assert
           (Large_Rect_Batch.Rectangle_Vertex_Count = Natural (Large_Rect_Batch.Vertices.Length),
            "oversized rectangle batch count matches capped vertex payload");
      end;

      Assert
        (Files.Rendering.Vulkan.Present (Vulkan_Renderer, Vulkan_Batch) =
         Files.Rendering.Vulkan.Vulkan_Present_Skipped,
         "vulkan present skips when no live surface is available");
      Assert
        (Files.Rendering.Vulkan.Skipped_Frame_Count (Vulkan_Renderer) = 1,
         "vulkan present records skipped frame count");
      Assert
        (Files.Rendering.Vulkan.Presented_Frame_Count (Vulkan_Renderer) = 0,
         "vulkan present does not record skipped frames as presented");
      Assert
        (Files.Rendering.Vulkan.Failed_Frame_Count (Vulkan_Renderer) = 0,
         "vulkan present skip does not record a failure");
      Assert
        (Files.Rendering.Vulkan.Last_Submitted_Vertex_Count (Vulkan_Renderer) =
         Natural (Vulkan_Batch.Vertices.Length),
         "vulkan present records last submitted vertex count");
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (not Diagnostics.Device_Ready, "vulkan diagnostics report missing device before initialization");
         Assert (not Diagnostics.Surface_Ready, "vulkan diagnostics report missing surface before initialization");
         Assert (not Diagnostics.Render_Targets_Ready, "vulkan diagnostics report missing render targets");
         Assert (not Diagnostics.Commands_Ready, "vulkan diagnostics report missing command buffers");
         Assert (not Diagnostics.Sync_Ready, "vulkan diagnostics report missing sync objects");
         Assert (not Diagnostics.Pipeline_Ready, "vulkan diagnostics report missing pipeline");
         Assert (not Diagnostics.Descriptor_Ready, "vulkan diagnostics report missing descriptors");
         Assert (Diagnostics.Texture_Binding_Count = 0, "vulkan diagnostics report no texture bindings");
         Assert
           (not Diagnostics.Mixed_Texture_Bindings_Ready,
            "vulkan diagnostics report missing mixed texture bindings");
         Assert (Diagnostics.Last_Texture_Count = 2, "vulkan diagnostics record mixed submitted texture count");
         Assert
           (Diagnostics.Last_Used_Mixed_Textures,
            "vulkan diagnostics record mixed text and icon texture use");
         Assert
           (not Diagnostics.Framebuffer_Readback_Ready,
            "vulkan diagnostics do not report framebuffer readback before a live frame");
         Assert
           (not Diagnostics.Framebuffer_Readback_Enabled,
            "vulkan framebuffer readback diagnostics are disabled by default");
         Assert (Diagnostics.Last_Framebuffer_Hash = 0, "vulkan diagnostics clear framebuffer hash initially");
         Assert (Diagnostics.Last_Framebuffer_Bytes = 0, "vulkan diagnostics clear framebuffer byte count initially");
         Assert (not Diagnostics.Vertex_Buffer_Ready, "vulkan diagnostics report missing vertex buffer");
         Assert (not Diagnostics.Atlas_Texture_Ready, "vulkan diagnostics report missing atlas texture");
         Assert (not Diagnostics.Icon_Atlas_Texture_Ready, "vulkan diagnostics report missing icon atlas texture");
         Assert (not Diagnostics.Resize_Validated, "vulkan diagnostics do not claim resize validation yet");
         Assert (not Diagnostics.Long_Running_Validated, "vulkan diagnostics do not claim soak validation");
         Assert (not Diagnostics.Device_Loss_Handled, "vulkan diagnostics do not claim device-loss validation");
         Assert (not Diagnostics.Surface_Loss_Handled, "vulkan diagnostics do not claim surface-loss validation");
         Assert (not Diagnostics.Multi_Window_Validated, "vulkan diagnostics do not claim multi-window validation");
         Assert (Diagnostics.Resize_Validation_Planned, "vulkan diagnostics plan resize validation");
         Assert
           (Diagnostics.Device_Loss_Validation_Planned,
            "vulkan diagnostics plan device-loss validation");
         Assert
           (Diagnostics.Surface_Loss_Validation_Planned,
            "vulkan diagnostics plan surface-loss validation");
         Assert
           (Diagnostics.Multi_Window_Validation_Planned,
            "vulkan diagnostics plan multi-window validation");
         Assert
           (Diagnostics.Long_Running_Validation_Planned,
            "vulkan diagnostics plan long-running validation");
         Assert (Diagnostics.Skipped_Frames = 1, "vulkan diagnostics aggregate skipped frames");
         Assert
           (Diagnostics.Last_Vertex_Count = Natural (Vulkan_Batch.Vertices.Length),
            "vulkan diagnostics aggregate submitted vertex count");
         Assert
           (Diagnostics.Last_Status = Files.Rendering.Vulkan.Vulkan_Present_Skipped,
            "vulkan diagnostics aggregate last present status");
      end;
      Files.Rendering.Vulkan.Set_Readback_Enabled (Vulkan_Renderer, True);
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert
           (Diagnostics.Framebuffer_Readback_Enabled,
            "vulkan framebuffer readback diagnostics require explicit opt-in");
         Assert
           (not Diagnostics.Framebuffer_Readback_Ready,
            "vulkan readback opt-in alone does not fabricate framebuffer data");
      end;
      Files.Rendering.Vulkan.Set_Readback_Enabled (Vulkan_Renderer, False);
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert
           (not Diagnostics.Framebuffer_Readback_Enabled,
            "vulkan framebuffer readback diagnostics can be disabled again");
         Assert
           (not Diagnostics.Framebuffer_Readback_Ready,
            "disabling readback clears framebuffer readiness");
      end;
      Assert
        (not Files.Rendering.Vulkan.Swapchain_Ready (Vulkan_Renderer),
         "vulkan swapchain starts unconfigured");
      Assert
        (Files.Rendering.Vulkan.Configure_Swapchain
           (Renderer => Vulkan_Renderer,
            Width    => Vulkan_Batch.Width,
            Height   => Vulkan_Batch.Height)
         = Files.Rendering.Vulkan.Vulkan_Swapchain_Create_Failed,
         "vulkan swapchain configuration fails without a live surface");
      Assert
        (Files.Rendering.Vulkan.Frame_Width (Vulkan_Renderer) = 0,
         "failed swapchain configuration clears frame width");
      Assert
        (Files.Rendering.Vulkan.Frame_Height (Vulkan_Renderer) = 0,
         "failed swapchain configuration clears frame height");
      Assert
        (Files.Rendering.Vulkan.Swapchain_Recreate_Pending (Vulkan_Renderer),
         "failed swapchain configuration leaves recreation pending");
      Assert
        (Files.Rendering.Vulkan.Pending_Frame_Width (Vulkan_Renderer) = Vulkan_Batch.Width,
         "failed swapchain configuration records pending frame width");
      Assert
        (Files.Rendering.Vulkan.Pending_Frame_Height (Vulkan_Renderer) = Vulkan_Batch.Height,
         "failed swapchain configuration records pending frame height");
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (Diagnostics.Swapchain_Recreate, "vulkan diagnostics report pending swapchain recreation");
         Assert
           (Diagnostics.Pending_Frame_Width = Vulkan_Batch.Width,
            "vulkan diagnostics aggregate pending frame width");
         Assert
           (Diagnostics.Pending_Frame_Height = Vulkan_Batch.Height,
            "vulkan diagnostics aggregate pending frame height");
      end;
      declare
         Resize : constant Files.Rendering.Vulkan.Resize_Validation_Result :=
           Files.Rendering.Vulkan.Validate_Resize_Request
             (Vulkan_Renderer,
              Width  => Vulkan_Batch.Width + 7,
              Height => Vulkan_Batch.Height + 9);
      begin
         Assert (Resize.Recreate_Requested, "vulkan resize validation requests swapchain recreation");
         Assert (Resize.Pending_Width = Vulkan_Batch.Width + 7, "vulkan resize validation records width");
         Assert (Resize.Pending_Height = Vulkan_Batch.Height + 9, "vulkan resize validation records height");
         Assert
           (Resize.Status = Files.Rendering.Vulkan.Vulkan_Swapchain_Recreate_Needed,
            "vulkan resize validation reports recreate-needed status");
      end;
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (Diagnostics.Resize_Validated, "vulkan diagnostics report resize validation");
      end;
      Assert
        (Files.Rendering.Vulkan.Configure_Swapchain
           (Renderer => Vulkan_Renderer,
            Width    => 0,
            Height   => Vulkan_Batch.Height)
         = Files.Rendering.Vulkan.Vulkan_Swapchain_Recreate_Needed,
         "zero-width swapchain configuration requests recreation");
      Assert
        (Files.Rendering.Vulkan.Frame_Width (Vulkan_Renderer) = 0,
         "zero-width swapchain configuration records frame width");
      Assert
        (Files.Rendering.Vulkan.Frame_Height (Vulkan_Renderer) = Vulkan_Batch.Height,
         "zero-width swapchain configuration records frame height");
      Files.Rendering.Vulkan.Request_Swapchain_Recreate
        (Renderer => Vulkan_Renderer,
         Width    => Vulkan_Batch.Width + 1,
         Height   => Vulkan_Batch.Height + 1);
      Assert
        (Files.Rendering.Vulkan.Swapchain_Recreate_Pending (Vulkan_Renderer),
         "explicit swapchain recreation request is recorded");
      Assert
        (Files.Rendering.Vulkan.Pending_Frame_Width (Vulkan_Renderer) = Vulkan_Batch.Width + 1,
         "explicit swapchain recreation records pending width");
      Assert
        (Files.Rendering.Vulkan.Pending_Frame_Height (Vulkan_Renderer) = Vulkan_Batch.Height + 1,
         "explicit swapchain recreation records pending height");
      declare
         Surface_Loss : constant Files.Rendering.Vulkan.Runtime_Validation_Result :=
           Files.Rendering.Vulkan.Validate_Surface_Loss (Vulkan_Renderer);
         Diagnostics : Files.Rendering.Vulkan.Renderer_Diagnostics;
      begin
         Assert (Surface_Loss.Requested, "vulkan surface-loss validation records request");
         Assert (Surface_Loss.Handled, "vulkan surface-loss validation handles missing surface");
         Assert (not Surface_Loss.Surface_Ready, "vulkan surface-loss validation clears surface readiness");
         Assert (not Surface_Loss.Swapchain_Ready, "vulkan surface-loss validation clears swapchain readiness");
         Assert
           (Surface_Loss.Status = Files.Rendering.Vulkan.Vulkan_Swapchain_Recreate_Needed,
            "vulkan surface-loss validation requests swapchain recreation");
         Diagnostics := Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
         Assert (Diagnostics.Surface_Loss_Handled, "vulkan diagnostics report surface-loss validation");
      end;
      declare
         Device_Loss : constant Files.Rendering.Vulkan.Runtime_Validation_Result :=
           Files.Rendering.Vulkan.Validate_Device_Loss (Vulkan_Renderer);
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (Device_Loss.Requested, "vulkan device-loss validation records request");
         Assert (Device_Loss.Handled, "vulkan device-loss validation handles missing device");
         Assert (not Device_Loss.Device_Ready, "vulkan device-loss validation clears device readiness");
         Assert (not Device_Loss.Surface_Ready, "vulkan device-loss validation leaves no live surface");
         Assert (not Device_Loss.Swapchain_Ready, "vulkan device-loss validation leaves no live swapchain");
         Assert (Diagnostics.Device_Loss_Handled, "vulkan diagnostics report device-loss validation");
         Assert (Diagnostics.Surface_Loss_Handled, "vulkan diagnostics retain surface-loss validation");
      end;
      declare
         Plan : constant Files.Rendering.Vulkan.Runtime_Validation_Plan :=
           (Validate_Resize       => True,
            Validate_Device_Loss  => True,
            Validate_Surface_Loss => True,
            Validate_Multi_Window => True,
            Validate_Long_Running => True,
            Width                 => Vulkan_Batch.Width + 13,
            Height                => Vulkan_Batch.Height + 17,
            Frame_Count           => 2,
            Window_Count          => 2);
         Suite : constant Files.Rendering.Vulkan.Runtime_Validation_Suite_Result :=
           Files.Rendering.Vulkan.Validate_Runtime_Suite (Vulkan_Renderer, Vulkan_Batch, Plan);
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (Suite.Resize_Validated, "vulkan validation suite records resize validation");
         Assert (Suite.Device_Loss_Handled, "vulkan validation suite records device-loss handling");
         Assert (Suite.Surface_Loss_Handled, "vulkan validation suite records surface-loss handling");
         Assert (Suite.Multi_Window_Validated, "vulkan validation suite records multi-window policy");
         Assert (Suite.Long_Running_Validated, "vulkan validation suite records bounded frame validation");
         Assert (Suite.Frames_Attempted = 2, "vulkan validation suite records attempted frames");
         Assert (Suite.Frames_Skipped >= 1, "vulkan validation suite records skipped headless frames");
         Assert (Diagnostics.Long_Running_Validated, "vulkan diagnostics report bounded frame validation");
         Assert (Diagnostics.Multi_Window_Validated, "vulkan diagnostics report multi-window validation");
         Assert (Diagnostics.Device_Loss_Handled, "vulkan diagnostics retain suite device-loss validation");
         Assert (Diagnostics.Surface_Loss_Handled, "vulkan diagnostics retain suite surface-loss validation");
      end;

      Vulkan_Status := Files.Rendering.Vulkan.Initialize (Vulkan_Renderer);
      Assert
        (Vulkan_Status = Files.Rendering.Vulkan.Vulkan_Ready
         or else Vulkan_Status = Files.Rendering.Vulkan.Vulkan_Instance_Create_Failed
         or else Vulkan_Status = Files.Rendering.Vulkan.Vulkan_Surface_Unsupported
         or else Vulkan_Status = Files.Rendering.Vulkan.Vulkan_Device_Create_Failed,
         "vulkan renderer reports ready or recoverable initialization failure");
      Assert
        (Files.Rendering.Vulkan.Ready (Vulkan_Renderer) =
         (Vulkan_Status = Files.Rendering.Vulkan.Vulkan_Ready),
         "vulkan ready state matches initialization status");
      Files.Rendering.Vulkan.Shutdown (Vulkan_Renderer);
      Assert (not Files.Rendering.Vulkan.Ready (Vulkan_Renderer), "vulkan shutdown clears ready state");
      declare
         Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
           Files.Rendering.Vulkan.Diagnostics (Vulkan_Renderer);
      begin
         Assert (not Diagnostics.Device_Ready, "vulkan diagnostics report shutdown device state");
         Assert (Diagnostics.Last_Vertex_Count = 0, "vulkan diagnostics report shutdown vertex count");
      end;
      Assert
        (Files.Rendering.Vulkan.Skipped_Frame_Count (Vulkan_Renderer) = 0,
         "vulkan shutdown clears skipped frame count");
      Assert
        (Files.Rendering.Vulkan.Last_Submitted_Vertex_Count (Vulkan_Renderer) = 0,
         "vulkan shutdown clears last submitted vertex count");
      Assert
        (not Files.Rendering.Vulkan.Swapchain_Recreate_Pending (Vulkan_Renderer),
         "vulkan shutdown clears pending swapchain recreation");
   end Test_Render_Snapshot_And_Layout;


   procedure Test_Bottom_Bar_Sort_Menu_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model           : Files.Model.Window_Model := Sample_Model;
      Settings        : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result          : Files.Controller.Controller_Result;
      Snapshot        : Files.Rendering.View_Snapshot;
      Frame           : Files.Rendering.Frame_Commands;
      Bottom          : constant Files.UI.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Line_Height => 20);
      Bottom_Y        : constant Natural := 800 - (20 + Files.UI.Bottom_Bar_Padding * 2);
      Sort_Button_Y   : constant Natural := Bottom_Y + Files.UI.Bottom_Bar_Padding;
      Row_H           : constant Natural := 20 + Files.UI.Bottom_Bar_Padding * 2;
      Menu_Y          : constant Natural := Bottom_Y - Row_H * 5 - Files.UI.Sort_Menu_Padding * 2;
      Rows_Y          : constant Natural := Menu_Y + Files.UI.Sort_Menu_Padding;
      Found_Button    : Boolean := False;
      Found_Name_Up   : Boolean := False;
      Found_Size_Plain : Boolean := False;
      Found_Inset_Row  : Boolean := False;
      Found_View_Fill  : Boolean := False;
      Found_Sort_Fill  : Boolean := False;
      Found_View_Sort_Border : Boolean := False;
      Found_Info_Toggle_Fill : Boolean := False;
      Found_Changed_Button : Boolean := False;
      Found_Changed_Menu : Boolean := False;
      Action          : Files.Events.Input_Action;
   begin
      Assert (Bottom.Sort_Button_Width > 0, "bottom bar allocates a sort button");
      Assert
        (Files.UI.Bottom_Bar_Command_At
           (Bottom.Sort_Button_X, Sort_Button_Y, 1000, 800, Line_Height => 20) =
         Files.Commands.Toggle_Sort_Menu_Command,
         "bottom-bar hit test maps sort button to menu toggle");

      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Toggle_Sort_Menu_Command, "sort menu toggle result records command");
      Assert (Files.Model.Sort_Menu_Is_Open (Model), "controller opens sort menu");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Sort_Menu_Open, "snapshot records open sort menu");
      Assert (Snapshot.Sort_Field = Files.Model.Sort_Name, "snapshot records default sort field");
      Assert (Snapshot.Sort_Ascending, "snapshot records default ascending sort");

      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      for Command of Frame.Text loop
         if To_String (Command.Text) =
           Files.Localization.Text ("command.sort.name") & " " & Files.Localization.Text ("sort.direction.ascending")
         then
            Assert (not Command.Truncated, "bottom sort button text is never abbreviated");
            Found_Button := True;
         end if;
      end loop;
      for Command of Frame.Overlay_Text loop
         if To_String (Command.Text) =
           Files.Localization.Text ("command.sort.name") & " " & Files.Localization.Text ("sort.direction.ascending")
         then
            Assert (not Command.Truncated, "sort menu selected text is not abbreviated");
            Found_Name_Up := True;
         elsif To_String (Command.Text) = Files.Localization.Text ("command.sort.size") then
            Assert (not Command.Truncated, "sort menu unselected text is not abbreviated");
            Found_Size_Plain := True;
         end if;
      end loop;
      for Command of Frame.Overlay_Rectangles loop
         if Command.X = Bottom.Sort_Button_X + 1
           and then Command.Y = Rows_Y
           and then Command.Width = Bottom.Sort_Button_Width - 2
           and then Command.Color = Files.Rendering.Selection_Color
         then
            Found_Inset_Row := True;
         end if;
      end loop;
      for Command of Frame.Rectangles loop
         if Command.X = Bottom.Small_Button_X
           and then Command.Y = Bottom_Y
           and then Command.Width = Bottom.Small_Button_Width
           and then Command.Height = 20 + Files.UI.Bottom_Bar_Padding * 2
           and then Command.Color = Files.Rendering.Selection_Color
         then
            Found_View_Fill := True;
         elsif Command.X = Bottom.Sort_Button_X
           and then Command.Y = Bottom_Y
           and then Command.Width = Bottom.Sort_Button_Width
           and then Command.Height = 20 + Files.UI.Bottom_Bar_Padding * 2
           and then Command.Color = Files.Rendering.Selection_Color
         then
            Found_Sort_Fill := True;
         elsif Command.X = Bottom.Sort_Button_X
           and then Command.Y = Bottom_Y
           and then Command.Width = 1
           and then Command.Height = 20 + Files.UI.Bottom_Bar_Padding * 2
           and then Command.Color = Files.Rendering.Border_Color
         then
            Found_View_Sort_Border := True;
         end if;
      end loop;

      Assert (Found_Button, "bottom sort button displays selected field and direction");
      Assert (Found_Name_Up, "sort menu marks selected field with ascending arrow");
      Assert (Found_Size_Plain, "sort menu leaves non-selected fields unmarked");
      Assert (Found_Inset_Row, "sort menu row fill stays inside left and right border");
      Assert (Found_View_Fill, "selected view button fill covers full bottom-bar height");
      Assert (Found_Sort_Fill, "selected sort button fill covers full bottom-bar height");
      Assert (Found_View_Sort_Border, "bottom bar separates view selector from sort button");
      declare
         Info_Model    : Files.Model.Window_Model := Sample_Model;
         Info_Snapshot : Files.Rendering.View_Snapshot;
         Info_Frame    : Files.Rendering.Frame_Commands;
      begin
         Files.Model.Select_Visible (Info_Model, 1);
         Files.Model.Toggle_Info_Pane (Info_Model);
         Info_Snapshot := Files.Rendering.Build_Snapshot (Info_Model);
         Info_Frame := Files.Rendering.Build_Frame_Commands
           (Info_Snapshot, Width => 1000, Height => 800, Line_Height => 20);

         for Command of Info_Frame.Rectangles loop
            if Command.X = Bottom.Info_Pane_X
              and then Command.Y = Bottom_Y
              and then Command.Width = Bottom.Info_Pane_Width
              and then Command.Height = 20 + Files.UI.Bottom_Bar_Padding * 2
              and then Command.Color = Files.Rendering.Selection_Color
            then
               Found_Info_Toggle_Fill := True;
            end if;
         end loop;
      end;
      Assert (Found_Info_Toggle_Fill, "selected info toggle fill covers full bottom-bar height");
      Assert
        (Files.UI.Bottom_Bar_Sort_Menu_Command_At
           (Bottom.Sort_Button_X, Rows_Y + Row_H + 1, 1000, 800, Line_Height => 20) =
         Files.Commands.Sort_By_Size_Command,
         "sort menu second row maps to size command");

      Action :=
        Click_Action
          (Snapshot,
           X           => Bottom.Sort_Button_X,
           Y           => Rows_Y + Row_H + 1,
           Width       => 1000,
           Height      => 800,
           Modifiers   => Files.Types.No_Modifiers,
           Line_Height => 20);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "sort menu click becomes command action");
      Assert (Action.Command = Files.Commands.Sort_By_Size_Command, "sort menu click dispatches selected row");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Changed_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Sort_By_Changed_Command, "changed sort command records command");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Toggle_Sort_Menu_Command, "sort menu reopens after changed sort");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);

      for Command of Frame.Text loop
         if To_String (Command.Text) =
           Files.Localization.Text ("command.sort.changed") & " " & Files.Localization.Text ("sort.direction.ascending")
         then
            Assert (not Command.Truncated, "bottom sort button longest label is not abbreviated");
            Found_Changed_Button := True;
         end if;
      end loop;
      for Command of Frame.Overlay_Text loop
         if To_String (Command.Text) =
           Files.Localization.Text ("command.sort.changed") & " " & Files.Localization.Text ("sort.direction.ascending")
         then
            Assert (not Command.Truncated, "sort menu longest selected label is not abbreviated");
            Found_Changed_Menu := True;
         end if;
      end loop;

      Assert (Found_Changed_Button, "bottom sort button renders longest field and arrow");
      Assert (Found_Changed_Menu, "sort menu renders longest selected field and arrow");
   end Test_Bottom_Bar_Sort_Menu_Rendering;


   procedure Test_Directory_Loaded_UTF8_Item_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Utf8_Name : constant String := "caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt";
      Decomposed_Name : constant String :=
        "cafe" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#)) & ".txt";
      CJK_Name : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#6587#))
        & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#4EF6#))
        & ".txt";
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Snapshot  : Files.Rendering.View_Snapshot;
      Frame     : Files.Rendering.Frame_Commands;
      Renderer  : Files.Rendering.Text_Renderer;
      Text      : Files.Rendering.Text_Render_Result;
      Frame_Font_Path : Unbounded_String;
      Found_E_Acute : Boolean := False;
      Found_Byte_C3 : Boolean := False;
      Found_Byte_A9 : Boolean := False;
      Found_Utf8_Name : Boolean := False;
      Found_Decomposed_Name : Boolean := False;
      Found_CJK_Name : Boolean := False;
      Found_Utf8_Command : Boolean := False;
      Found_Decomposed_Command : Boolean := False;
      Found_CJK_Command : Boolean := False;
      Found_CJK_Glyph : Boolean := False;
      Found_Combining_Glyph : Boolean := False;
   begin
      Reset_Root;
      Write_File (Join (Root, Utf8_Name));
      Write_File (Join (Root, Decomposed_Name));
      Write_File (Join (Root, CJK_Name));

      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "UTF-8 directory load succeeds");
      Assert
        (Natural (Load.Items.Length) = 3,
         "UTF-8 directory load captures composed, decomposed, and CJK items");
      for Item of Load.Items loop
         if To_String (Item.Name) = Utf8_Name then
            Found_Utf8_Name := True;
         elsif To_String (Item.Name) = Decomposed_Name then
            Found_Decomposed_Name := True;
         elsif To_String (Item.Name) = CJK_Name then
            Found_CJK_Name := True;
         end if;
      end loop;
      Assert (Found_Utf8_Name, "directory load preserves composed UTF-8 item name");
      Assert (Found_Decomposed_Name, "directory load preserves decomposed UTF-8 item name");
      Assert (Found_CJK_Name, "directory load preserves CJK UTF-8 item name");

      Files.Model.Initialize (Model, Root, Load.Items, Root, Files.Types.Small_Icons);
      Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      Frame :=
        Files.Rendering.Build_Frame_Commands
          (Snapshot,
           Width       => 360,
          Height      => 200,
           Line_Height => 20);
      for Command of Frame.Text loop
         if To_String (Command.Text) = Utf8_Name then
            Found_Utf8_Command := True;
         elsif To_String (Command.Text) = Decomposed_Name then
            Found_Decomposed_Command := True;
         elsif To_String (Command.Text) = CJK_Name then
            Found_CJK_Command := True;
         end if;
      end loop;
      Assert
        (Found_Utf8_Command,
         "main-section frame commands preserve composed UTF-8 item names before rasterization");
      Assert
        (Found_Decomposed_Command,
         "main-section frame commands preserve decomposed UTF-8 item names before rasterization");
      Assert
        (Found_CJK_Command,
         "main-section frame commands preserve CJK item names before rasterization");
      Frame_Font_Path := To_Unbounded_String (Files.Rendering.Font_Path_For_Frame (Frame));

      Assert (To_String (Frame_Font_Path) /= "", "UTF-8 directory-loaded main view selects a text font");
      declare
         Font : Textrender.Fonts.Font;
      begin
         Assert
           (Textrender.Fonts.Load (Font, To_String (Frame_Font_Path)) = Textrender.Fonts.Loaded,
            "UTF-8 directory-loaded main view font is loadable");
         Assert
           (Textrender.Fonts.Has_Glyph (Font, 16#00E9#),
            "UTF-8 directory-loaded main view font covers composed filename glyphs");
         Assert
           (Textrender.Fonts.Has_Glyph (Font, 16#0301#),
            "UTF-8 directory-loaded main view font covers decomposed accent glyphs");
         Assert
           (Textrender.Fonts.Has_Glyph (Font, 16#6587#)
            and then Textrender.Fonts.Has_Glyph (Font, 16#4EF6#),
            "UTF-8 directory-loaded main view font covers every CJK filename glyph");
         Textrender.Fonts.Reset (Font);
      exception
         when others =>
            Textrender.Fonts.Reset (Font);
            raise;
      end;

      Assert
        (Files.Rendering.Initialize_Text
           (Renderer    => Renderer,
            Font_Path   => To_String (Frame_Font_Path),
            Pixel_Size  => 16,
            Cell_Width  => 10,
            Cell_Height => 20)
         = Files.Rendering.Text_Render_Success,
         "UTF-8 directory-loaded main view can initialize frame-specific text rendering");

      Text := Files.Rendering.Build_Text_Glyphs (Renderer, Frame);
      for Glyph of Text.Glyphs loop
         if Glyph.Codepoint = 16#00E9# then
            Found_E_Acute := True;
         elsif Glyph.Codepoint = 16#00C3# then
            Found_Byte_C3 := True;
         elsif Glyph.Codepoint = 16#00A9# then
            Found_Byte_A9 := True;
         elsif Glyph.Codepoint = 16#6587# or else Glyph.Codepoint = 16#4EF6# then
            Found_CJK_Glyph := True;
         elsif Glyph.Codepoint = 16#0301# then
            Found_Combining_Glyph := True;
         end if;
      end loop;

      Assert (Text.Status = Files.Rendering.Text_Render_Success, "directory-loaded UTF-8 item name rasterizes");
      Assert
        (Text.Missing_Glyph_Count = 0,
         "directory-loaded UTF-8 item names render without missing-glyph fallback");
      Assert (Found_E_Acute, "directory-loaded composed UTF-8 item name emits Unicode glyph codepoint");
      Assert (Found_Combining_Glyph, "directory-loaded decomposed UTF-8 item name emits accent glyph");
      Assert (Found_CJK_Glyph, "directory-loaded CJK UTF-8 item name emits Unicode glyph codepoint");
      Assert
        (not Found_Byte_C3 and then not Found_Byte_A9,
         "directory-loaded UTF-8 item name is not rendered as raw bytes");
   end Test_Directory_Loaded_UTF8_Item_Rendering;


   procedure Test_Event_Translation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl   : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Alt    : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Shift  : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Ctrl_Shift : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Action : Files.Events.Input_Action;
      Model  : Files.Model.Window_Model := Sample_Model;
      Roots  : Files.Types.String_Vectors.Vector;
      Layout : Files.Rendering.Layout_Metrics;
      Palette_Query_Length : constant Natural := String'("navigate.back")'Length;
      Rename_Text_Length   : constant Natural := String'("Alpha.txt")'Length;
   begin
      Ctrl (Files.Types.Control_Key) := True;
      Alt (Files.Types.Alt_Key) := True;
      Shift (Files.Types.Shift_Key) := True;
      Ctrl_Shift (Files.Types.Control_Key) := True;
      Ctrl_Shift (Files.Types.Shift_Key) := True;
      Action := Files.Events.Translate_Key (Files.Types.Key_P, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control shortcut translates to command action");
      Assert (Action.Command = Files.Commands.Open_Command_Palette_Command, "control+p maps to palette command");

      Action := Files.Events.Translate_Key (Files.Types.Key_L, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+l translates to command action");
      Assert (Action.Command = Files.Commands.Focus_Path_Input_Command, "control+l maps to path focus command");

      Action := Files.Events.Translate_Key (Files.Types.Key_F, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+f translates to command action");
      Assert (Action.Command = Files.Commands.Focus_Filter_Input_Command, "control+f maps to filter focus");

      Action := Files.Events.Translate_Key (Files.Types.Key_F, Ctrl_Shift);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+shift+f translates to command action");
      Assert (Action.Command = Files.Commands.Clear_Filter_Command, "control+shift+f maps to clear filter");

      Action := Files.Events.Translate_Key (Files.Types.Key_N, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+n translates to command action");
      Assert (Action.Command = Files.Commands.Create_File_Command, "control+n maps to create file");

      Action := Files.Events.Translate_Key (Files.Types.Key_A, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+a translates to command action");
      Assert (Action.Command = Files.Commands.Select_All_Command, "control+a maps to select-all command");

      Action := Files.Events.Translate_Key (Files.Types.Key_D, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+d translates to command action");
      Assert (Action.Command = Files.Commands.Select_Drive_Command, "control+d maps to drive selector");

      Action := Files.Events.Translate_Key (Files.Types.Key_R, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+r translates to command action");
      Assert (Action.Command = Files.Commands.Refresh_Directory_Command, "control+r maps to refresh");
      Action := Files.Events.Translate_Key (Files.Types.Key_S, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+s translates to command action");
      Assert (Action.Command = Files.Commands.Save_Settings_Command, "control+s maps to settings save");

      Action := Files.Events.Translate_Key (Files.Types.Key_Left, Alt);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "alt+left translates to command action");
      Assert (Action.Command = Files.Commands.Navigate_Back_Command, "alt+left maps to back command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Right, Alt);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "alt+right translates to command action");
      Assert (Action.Command = Files.Commands.Navigate_Forward_Command, "alt+right maps to forward command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Home, Alt);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "alt+home translates to command action");
      Assert (Action.Command = Files.Commands.Navigate_Home_Command, "alt+home maps to home command");

      Action := Files.Events.Translate_Key (Files.Types.Key_1, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+1 translates to command action");
      Assert (Action.Command = Files.Commands.Select_Small_Icons_Command, "control+1 maps to small-icons command");

      Action := Files.Events.Translate_Key (Files.Types.Key_2, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+2 translates to command action");
      Assert (Action.Command = Files.Commands.Select_Large_Icons_Command, "control+2 maps to large-icons command");

      Action := Files.Events.Translate_Key (Files.Types.Key_3, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+3 translates to command action");
      Assert (Action.Command = Files.Commands.Select_Details_Command, "control+3 maps to details command");

      Action := Files.Events.Translate_Key (Files.Types.Key_4, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "control+4 translates to command action");
      Assert (Action.Command = Files.Commands.Toggle_Info_Pane_Command, "control+4 maps to info toggle command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Left, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Selection_Input_Action, "arrow key translates to selection action");
      Assert (Action.Direction = Files.Types.Move_Left, "left arrow maps to left selection movement");

      Action := Files.Events.Translate_Key (Files.Types.Key_Right, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Selection_Input_Action, "right arrow translates to selection action");
      Assert (Action.Direction = Files.Types.Move_Right, "right arrow maps to right selection movement");

      Action := Files.Events.Translate_Key (Files.Types.Key_Up, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Selection_Input_Action, "up arrow translates to selection action");
      Assert (Action.Direction = Files.Types.Move_Up, "up arrow maps to upward selection movement");

      Action := Files.Events.Translate_Key (Files.Types.Key_Down, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Selection_Input_Action, "down arrow translates to selection action");
      Assert (Action.Direction = Files.Types.Move_Down, "down arrow maps to downward selection movement");
      Action := Files.Events.Translate_Key (Files.Types.Key_Down, Shift);
      Assert (Action.Kind = Files.Events.Selection_Input_Action, "shift-down translates to selection action");
      Assert (Action.Direction = Files.Types.Move_Down, "shift-down maps to downward selection movement");
      Assert (Action.Range_Selection, "shift-down requests range selection");

      Action := Files.Events.Translate_Key (Files.Types.Key_Delete, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Delete translates to command action");
      Assert (Action.Command = Files.Commands.Delete_Selected_Items_Command, "Delete maps to delete command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Delete, Shift);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Shift+Delete translates to command action");
      Assert
        (Action.Command = Files.Commands.Delete_Selected_Permanently_Command,
         "Shift+Delete maps to permanent delete command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Backspace, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Backspace translates to command action");
      Assert (Action.Command = Files.Commands.Delete_Selected_Items_Command, "Backspace maps to delete command");

      Action := Files.Events.Translate_Key (Files.Types.Key_F2, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "F2 translates to command action");
      Assert (Action.Command = Files.Commands.Rename_Selected_Items_Command, "F2 maps to rename command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Return, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Return translates to command action");
      Assert (Action.Command = Files.Commands.Open_Selected_Items_Command, "Return maps to open command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Escape, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Escape translates to command action");
      Assert (Action.Command = Files.Commands.Close_Command_Palette_Command, "Escape maps to context cancel");

      Action := Files.Events.Translate_Key (Files.Types.Key_Comma, Ctrl);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "Control+comma translates to command action");
      Assert
        (Action.Command = Files.Commands.Toggle_Settings_Pane_Command,
         "Control+comma maps to settings command");

      Action := Files.Events.Translate_Key (Files.Types.Key_Left, Ctrl);
      Assert (Action.Kind = Files.Events.No_Input_Action, "modified arrow does not move selection");

      Action := Files.Events.Translate_Key (Files.Types.Key_P, Alt);
      Assert (Action.Kind = Files.Events.No_Input_Action, "nonmatching modifier shortcut is ignored");

      Action := Files.Events.Translate_Key (Files.Types.Key_Unknown, Files.Types.No_Modifiers);
      Assert (Action.Kind = Files.Events.No_Input_Action, "unknown key translates to no input action");

      Action := Files.Events.Translate_Scroll (1);
      Assert (Action.Kind = Files.Events.Scroll_Input_Action, "positive wheel offset translates to scroll action");
      Assert (Action.Direction = Files.Types.Move_Up, "positive wheel offset maps to upward direction");
      Assert (Action.Scroll_Lines = -3, "positive wheel offset scrolls content upward");
      Assert (Action.Scroll_Area = Files.Events.Scroll_Auto, "wheel scroll uses automatic scroll target");

      Action := Files.Events.Translate_Scroll (-2);
      Assert (Action.Kind = Files.Events.Scroll_Input_Action, "negative wheel offset translates to scroll action");
      Assert (Action.Direction = Files.Types.Move_Down, "negative wheel offset maps to downward direction");
      Assert (Action.Scroll_Lines = 6, "negative wheel offset scrolls content downward");

      Action := Files.Events.Translate_Scroll (Integer'Last);
      Assert (Action.Kind = Files.Events.Scroll_Input_Action, "large positive wheel offset translates");
      Assert (Action.Direction = Files.Types.Move_Up, "large positive wheel offset keeps upward direction");
      Assert (Action.Scroll_Lines = Integer'First, "large positive wheel offset saturates upward scroll lines");

      Action := Files.Events.Translate_Scroll (Integer'First);
      Assert (Action.Kind = Files.Events.Scroll_Input_Action, "large negative wheel offset translates");
      Assert (Action.Direction = Files.Types.Move_Down, "large negative wheel offset keeps downward direction");
      Assert (Action.Scroll_Lines = Integer'Last, "large negative wheel offset saturates downward scroll lines");

      Action := Files.Events.Translate_Scroll (0);
      Assert (Action.Kind = Files.Events.No_Input_Action, "zero wheel offset translates to no input action");

      declare
         Scroll_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Scroll_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Scroll_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Scroll_Snapshot,
              X        => Scroll_Layout.Main_X + 1,
              Y        => Scroll_Layout.Main_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "wheel over main view translates to scroll");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Main_View, "wheel over main view targets main view");
         Assert (Action.Scroll_Lines = 3, "targeted main wheel keeps line delta");

         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Scroll_Snapshot,
              X        => 1,
              Y        => 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "wheel over toolbar does not scroll content");
      end;

      Files.Model.Toggle_Info_Pane (Model);
      declare
         Info_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Info_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Info_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Info_Pane     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Info_Snapshot, Info_Layout, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Info_Snapshot,
              X        => Info_Pane.X + 1,
              Y        => Info_Pane.Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => 1);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "wheel over info pane translates to scroll");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Info_Pane, "wheel over info pane targets info pane");
         Assert (Action.Scroll_Lines = -3, "targeted info wheel keeps line delta");
      end;
      Files.Model.Toggle_Info_Pane (Model);

      Files.Model.Open_Command_Palette (Model);
      declare
         Palette_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Palette_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Palette_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Palette          : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Palette_Layout, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Palette_Snapshot,
              X        => Palette.X + 1,
              Y        => Palette.Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "wheel over palette search field is inert");
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Palette_Snapshot,
              X        => Palette.Results_X + 1,
              Y        => Palette.Results_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert
           (Action.Kind = Files.Events.Scroll_Input_Action,
            "wheel over palette results translates to scroll");
         Assert
           (Action.Scroll_Area = Files.Events.Scroll_Command_Palette,
            "wheel over palette results targets palette");
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Palette_Snapshot,
              X        => 1,
              Y        => 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "open palette blocks wheel outside overlay");
      end;
      Files.Model.Close_Command_Palette (Model);

      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      declare
         Root_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Root_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Root_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Root_Snapshot,
              X        => Root_Layout.Main_X + 1,
              Y        => Root_Layout.Main_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "root selector blocks targeted main wheel translation");
      end;
      Files.Model.Open_Command_Palette (Model);
      declare
         Palette_Over_Root : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Palette_Layout    : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Palette_Over_Root, Width => 1000, Height => 800, Line_Height => 20);
         Palette           : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Palette_Layout, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Palette_Over_Root,
              X        => Palette.Results_X + 1,
              Y        => Palette.Results_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert
           (Action.Scroll_Area = Files.Events.Scroll_Command_Palette,
            "palette over root selector keeps palette wheel target");
      end;
      Files.Model.Close_Command_Palette (Model);
      Files.Model.Close_Root_Selector (Model);

      Files.Model.Begin_Settings_Edit
        (Model,
         Files.Settings.Make_Draft (Files.Settings.Default_Settings));
      declare
         Settings_Scroll_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Settings_Scroll_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Settings_Scroll_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Settings_Info_Pane       : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout
             (Settings_Scroll_Snapshot, Settings_Scroll_Layout, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Settings_Scroll_Snapshot,
              X        => Settings_Scroll_Layout.Main_X + 1,
              Y        => Settings_Scroll_Layout.Main_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings pane blocks targeted main wheel translation");
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Settings_Scroll_Snapshot,
              X        => Settings_Info_Pane.X + 1,
              Y        => Settings_Info_Pane.Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings pane blocks targeted info wheel translation");
      end;
      Files.Model.Open_Command_Palette (Model);
      declare
         Palette_Over_Settings : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Palette_Layout        : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Palette_Over_Settings, Width => 1000, Height => 800, Line_Height => 20);
         Palette               : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Palette_Layout, Line_Height => 20);
      begin
         Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot => Palette_Over_Settings,
              X        => Palette.Results_X + 1,
              Y        => Palette.Results_Y + 1,
              Width    => 1000,
              Height   => 800,
              Y_Offset => -1);
         Assert
           (Action.Scroll_Area = Files.Events.Scroll_Command_Palette,
            "palette over settings pane keeps palette wheel target");
      end;
      Files.Model.Close_Command_Palette (Model);
      Files.Model.Toggle_Settings_Pane (Model);

      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 10, Y => 10, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "toolbar click translates to command action");
      Assert (Action.Command = Files.Commands.Select_Drive_Command, "toolbar click maps drive command");

      Roots.Append (To_Unbounded_String ("/"));
      Roots.Append (To_Unbounded_String ("/tmp"));
      Files.Model.Open_Root_Selector (Model, Roots);
      Layout :=
        Files.Rendering.Calculate_Layout
          (Files.Rendering.Build_Snapshot (Model), Width => 1000, Height => 800, Line_Height => 20);
      Action :=
        Click_Action
           (Files.Rendering.Build_Snapshot (Model),
           X      => 10,
           Y      => Layout.Toolbar_Height + 10,
           Width  => 1000,
           Height => 800);
      Assert (Action.Kind = Files.Events.Root_Click_Input_Action, "root row click translates to root action");
      Assert (Action.Root_Index = 1, "root row click returns root index");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 10, Y => 10, Width => 1000, Height => 800);
      Assert
        (Action.Kind = Files.Events.Command_Input_Action,
         "root selector lets drive toolbar button toggle the chooser");
      Assert
        (Action.Command = Files.Commands.Select_Drive_Command,
         "open root selector toolbar click maps to drive command");
      declare
         Controller_Result : constant Files.Controller.Controller_Result :=
           Files.Controller.Execute_Command
             (Action.Command,
              Model,
              Files.Settings.Default_Settings);
      begin
         Assert
           (Controller_Result.Command = Files.Commands.Select_Drive_Command,
            "drive toolbar toggle executes command");
         Assert
           (not Files.Model.Root_Selector_Is_Open (Model),
            "drive toolbar toggle closes open root selector");
      end;

      Files.Model.Begin_Settings_Edit
        (Model,
         Files.Settings.Make_Draft (Files.Settings.Default_Settings));
      declare
         Settings_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Settings_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Settings_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Settings_Pane     : constant Files.UI.Settings_Pane_Layout :=
           Files.UI.Calculate_Settings_Pane_Layout (1000, 800, Settings_Layout.Toolbar_Height, Line_Height => 20);
         Pane_W            : constant Natural := Settings_Pane.Width;
         Pane_X            : constant Natural := Settings_Pane.X;
         Pane_Y            : constant Natural := Settings_Pane.Y;
         Text_X            : constant Natural := Settings_Pane.Text_X;
         Text_Y            : constant Natural := Settings_Pane.Text_Y;
         Text_W            : constant Natural := Settings_Pane.Text_Width;
         Cell_W            : constant Natural := Text_W / 4;
         Row_Step          : constant Natural := 20 + Files.UI.Settings_Row_Gap;
         Action_Buttons    : constant Files.UI.Settings_Action_Button_Layout :=
           Files.UI.Calculate_Settings_Action_Button_Layout (Text_X, Text_W);
         Entry_Buttons     : constant Files.UI.Settings_Entry_Button_Layout :=
           Files.UI.Calculate_Settings_Entry_Button_Layout (Pane_X, Pane_W, Line_Height => 20);
         Settings_Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Settings_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Found_Opaque_Settings_Background : Boolean := False;

         function Row_Y (Row : Natural) return Natural is
         begin
            return Text_Y + Row * Row_Step;
         end Row_Y;
      begin
         Assert
           (Settings_Pane.Height =
            Natural'Max
              (20 * 22 + Files.UI.Settings_Row_Gap * 21 + Files.UI.Settings_Pane_Padding * 2,
               800 / 3),
            "settings hit tests use shared pane layout height");
         Assert
           (Text_X = Pane_X + Files.UI.Settings_Pane_Padding
            and then Text_Y = Pane_Y + Files.UI.Settings_Pane_Padding
            and then Text_W = Pane_W - 2 * Files.UI.Settings_Pane_Padding,
            "settings hit tests use shared pane inner text layout");
         Assert
           (Action_Buttons.Total_X = Text_X and then Action_Buttons.Total_Width = Text_W,
            "settings hit tests use shared action button layout");
         Assert
           (Entry_Buttons.Remove_Button_Width > Entry_Buttons.Add_Button_Width,
            "settings remove button sizes to localized label");
         for Command of Settings_Frame.Rectangles loop
            if Command.X = Pane_X
              and then Command.Y = Pane_Y
              and then Command.Width = Pane_W
              and then Command.Height = Settings_Pane.Height
              and then Command.Color = Files.Rendering.Pane_Color
            then
               Found_Opaque_Settings_Background := True;
            end if;
         end loop;
         Assert (Found_Opaque_Settings_Background, "settings pane background is opaque");
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Text_X + 1,
                  Y      => Row_Y (1) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.Command_Input_Action, "settings reset click translates");
         Assert (Action.Command = Files.Commands.Reset_Settings_Command, "settings reset click maps command");
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Action_Buttons.Second_Button_X + 1,
                  Y      => Row_Y (1) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.Command_Input_Action, "settings save click translates");
         Assert (Action.Command = Files.Commands.Save_Settings_Command, "settings save click maps command");
         declare
            Disabled_Settings : Files.Rendering.View_Snapshot := Settings_Snapshot;
         begin
            Disabled_Settings.Settings_Can_Reset := False;
            Action :=
              Click_Action
                   (Disabled_Settings,
                    X      => Text_X + 1,
                    Y      => Row_Y (1) + 1,
                    Width  => 1000,
                    Height => 800);
            Assert
              (Action.Kind = Files.Events.No_Input_Action,
               "disabled settings reset click is ignored by hit testing");

            Disabled_Settings := Settings_Snapshot;
            Disabled_Settings.Settings_Can_Save := False;
            Action :=
              Click_Action
                   (Disabled_Settings,
                    X      => Action_Buttons.Second_Button_X + 1,
                    Y      => Row_Y (1) + 1,
                    Width  => 1000,
                    Height => 800);
            Assert
              (Action.Kind = Files.Events.No_Input_Action,
               "disabled settings save click is ignored by hit testing");
         end;
         declare
            Odd_Width      : constant Natural := 1004;
            Odd_Snapshot   : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
            Odd_Layout     : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (Odd_Snapshot, Width => Odd_Width, Height => 800, Line_Height => 20);
            Odd_Pane       : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout (Odd_Width, 800, Odd_Layout.Toolbar_Height, Line_Height => 20);
            Odd_Text_X     : constant Natural := Odd_Pane.Text_X;
            Odd_Text_W     : constant Natural := Odd_Pane.Text_Width;
            Odd_Last_X     : constant Natural := Odd_Text_X + Odd_Text_W - 1;
         begin
            Action :=
              Click_Action
                  (Odd_Snapshot,
                   X      => Odd_Last_X,
                  Y      => Odd_Pane.Text_Y + Row_Step + 1,
                  Width  => Odd_Width,
                  Height => 800);
            Assert
              (Action.Kind = Files.Events.Command_Input_Action,
               "settings action remainder click translates");
            Assert
              (Action.Command = Files.Commands.Save_Settings_Command,
               "settings save remainder click maps save command");
         end;
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Text_X + Cell_W + 1,
                  Y      => Row_Y (20) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.Settings_Click_Input_Action, "settings option click translates");
         Assert (Action.Settings_Field = 1, "settings option click keeps active scalar field");
         Assert (Action.Settings_Option = 2, "settings option click returns option index");
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Text_X + 3 * Cell_W + 1,
                  Y      => Row_Y (20) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings blank option cell is inert");
         Files.Model.Set_Settings_Field_Index (Model, 3);
         declare
            Sort_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
            Sort_Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (Sort_Snapshot, Width => 997, Height => 800, Line_Height => 20);
            Sort_Pane     : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout (997, 800, Sort_Layout.Toolbar_Height, Line_Height => 20);
            Sort_Text_X   : constant Natural := Sort_Pane.Text_X;
            Sort_Text_W   : constant Natural := Sort_Pane.Text_Width;
         begin
            Action :=
              Click_Action
                  (Sort_Snapshot,
                   X      => Sort_Text_X + Sort_Text_W - 1,
                  Y      => Sort_Pane.Text_Y + 20 * Row_Step + 1,
                  Width  => 997,
                  Height => 800);
            Assert
              (Action.Kind = Files.Events.Settings_Click_Input_Action,
               "settings sort remainder click translates");
            Assert (Action.Settings_Field = 3, "settings sort remainder click keeps sort field");
            Assert (Action.Settings_Option = 4, "settings sort remainder click maps modified option");
         end;
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Entry_Buttons.Add_Button_X + 1,
                  Y      => Row_Y (9) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.Settings_Click_Input_Action, "settings add click translates");
         Assert (Action.Settings_Field = 7, "settings add click targets filetype mappings");
         Assert (Action.Settings_Option = 100, "settings add click returns add action code");
         Action :=
           Click_Action
                  (Settings_Snapshot,
                   X      => Entry_Buttons.Remove_Button_X + 1,
                  Y      => Row_Y (9) + 1,
                  Width  => 1000,
                  Height => 800);
         Assert (Action.Kind = Files.Events.Settings_Click_Input_Action, "settings remove click translates");
         Assert (Action.Settings_Field = 7, "settings remove click targets filetype mappings");
         Assert (Action.Settings_Option = 101, "settings remove click returns remove action code");
         Action :=
           Click_Action
               (Settings_Snapshot,
                X      => Text_X + 1,
               Y      => Pane_Y + Settings_Pane.Height - 1,
               Width  => 1000,
               Height => 800);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings diagnostic row stays inside modal pane");
         declare
            Narrow_Width    : constant Natural := 120;
            Narrow_Snapshot : constant Files.Rendering.View_Snapshot := Settings_Snapshot;
            Narrow_Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (Narrow_Snapshot, Width => Narrow_Width, Height => 800);
            Narrow_Pane     : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout
                (Narrow_Width, 800, Narrow_Layout.Toolbar_Height, Line_Height => 20);
         begin
            Assert
              (Narrow_Pane.Width = Narrow_Width and then Narrow_Pane.X = 0,
               "narrow settings pane clamps to the window width");
            Action :=
              Click_Action
                   (Narrow_Snapshot,
                    X      => Narrow_Width,
                    Y      => Narrow_Pane.Text_Y + Row_Step + 1,
                    Width  => Narrow_Width,
                    Height => 800);
            Assert
              (Action.Kind = Files.Events.No_Input_Action,
               "narrow settings pane rejects clicks beyond the window width");
         end;
      end;
      declare
         Huge_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Huge_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Huge_Snapshot, Width => Natural'Last, Height => Natural'Last);
      begin
         Assert (Huge_Layout.Command_Width < Natural'Last, "saturated command palette width is bounded");
         Action :=
           Click_Action
             (Huge_Snapshot,
              X      => Natural'Last,
              Y      => Natural'Last,
              Width  => Natural'Last,
              Height => Natural'Last);
         Assert (Action.Kind = Files.Events.No_Input_Action, "saturated settings click avoids overflow");
         declare
            Huge_Pane : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout
                (Natural'Last, Natural'Last, Huge_Layout.Toolbar_Height, Line_Height => 20);
         begin
            Action :=
              Click_Action
                (Huge_Snapshot,
                 X      => Huge_Pane.Text_X + 1,
                 Y      => Huge_Pane.Text_Y + 20 + Files.UI.Settings_Row_Gap + 1,
                 Width  => Natural'Last,
                 Height => Natural'Last);
            Assert
              (Action.Kind = Files.Events.Command_Input_Action,
               "saturated settings pane button click avoids overflow");
            Assert
              (Action.Command = Files.Commands.Reset_Settings_Command,
               "saturated settings pane button click maps reset command");
         end;
      end;
      Files.Model.Open_Command_Palette (Model);
      declare
         Palette_Over_Settings : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Palette_Layout        : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Palette_Over_Settings, Width => 1000, Height => 800, Line_Height => 20);
         Palette               : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Palette_Layout, Line_Height => 20);
         Settings_Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Palette_Over_Settings, Width => 1000, Height => 800, Line_Height => 20);
         Settings_Pane         : constant Files.UI.Settings_Pane_Layout :=
           Files.UI.Calculate_Settings_Pane_Layout (1000, 800, Settings_Layout.Toolbar_Height, Line_Height => 20);
      begin
         Action :=
           Click_Action
             (Palette_Over_Settings,
              X      => Settings_Pane.Text_X + 1,
              Y      => Settings_Pane.Text_Y + 20 + Files.UI.Settings_Row_Gap + 1,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Command_Result_Click_Input_Action,
            "palette claims settings modal clicks behind overlay");
         Action :=
           Click_Action
             (Palette_Over_Settings,
              X      => Palette.Search_X + 1,
              Y      => Palette.Search_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Text_Click_Input_Action,
            "palette search remains clickable over settings pane");
         Assert
           (Action.Focus_Target = Files.Types.Focus_Command_Palette,
            "palette search over settings targets command-palette input");
         Action :=
           Click_Action
             (Palette_Over_Settings,
              X      => Palette.Results_X + 1,
              Y      => Palette.Results_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Command_Result_Click_Input_Action,
            "palette result remains clickable over settings pane");
      end;
      Files.Model.Close_Command_Palette (Model);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files.Model.Toggle_Settings_Pane (Model);

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      declare
         Wide_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Wide_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Wide_Snapshot, Width => Natural'Last, Height => 800, Line_Height => 20);
         Wide_Palette  : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Wide_Layout, Line_Height => 20);
      begin
         Action :=
           Click_Action
             (Wide_Snapshot,
              X      => Wide_Palette.Search_X + Wide_Palette.Search_Width - 1,
              Y      => Wide_Palette.Search_Y + 1,
              Width  => Natural'Last,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Text_Click_Input_Action,
            "wide palette search click avoids cursor overflow");
         Assert
           (Action.Cursor_Position = Length (Wide_Snapshot.Command_Palette_Query),
            "wide palette search click clamps cursor to query end");
      end;
      Files.Model.Close_Command_Palette (Model);

      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 268, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "path click translates to text action");
      Assert (Action.Focus_Target = Files.Types.Focus_Path_Input, "path click targets path input");
      Assert (Action.Cursor_Position = 2, "path click computes text cursor position");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 240, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Cursor_Position = 0, "path click clamps cursor to text start");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 799, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Cursor_Position = Root'Length, "path click clamps cursor to text end");

      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 268, Y => 5, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "path input top padding focuses text field");
      Assert (Action.Focus_Target = Files.Types.Focus_Path_Input, "path input top padding targets path input");

      Files.Model.Set_Filter (Model, "beta");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 824, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "filter click translates to text action");
      Assert (Action.Focus_Target = Files.Types.Focus_Filter_Input, "filter click targets filter input");
      Assert (Action.Cursor_Position = 2, "filter click computes text cursor position");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 800, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Cursor_Position = 0, "filter click clamps cursor to text start");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 999, Y => 20, Width => 1000, Height => 800);
      Assert (Action.Cursor_Position = 4, "filter click clamps cursor to text end");
      declare
         Utf8_Text : constant String :=
           Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#));
         Combining_Text : constant String :=
           "e" & Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#0301#));
      begin
         Files.Model.Set_Filter (Model, "a" & Utf8_Text & "b");
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model), X => 824, Y => 20, Width => 1000, Height => 800);
         Assert
           (Action.Cursor_Position = 3,
            "filter click returns UTF-8 byte boundary after clicked character");
         Files.Model.Set_Filter (Model, Combining_Text & "b");
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model), X => 814, Y => 20, Width => 1000, Height => 800);
         Assert
           (Action.Cursor_Position = Combining_Text'Length,
            "filter click skips trailing combining marks at display-cell boundaries");
         Files.Model.Set_Filter (Model, "a" & Byte (16#A9#) & "b");
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model), X => 824, Y => 20, Width => 1000, Height => 800);
         Assert
           (Action.Cursor_Position = 2,
            "filter click counts malformed UTF-8 byte as replacement cell");
      end;
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 824, Y => 30, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "filter input bottom padding focuses text field");
      Assert (Action.Focus_Target = Files.Types.Focus_Filter_Input, "filter input bottom padding targets filter input");
      Files.Model.Clear_Filter (Model);

      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 170, Y => 790, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Command_Input_Action, "bottom-bar click translates to command action");
      Assert (Action.Command = Files.Commands.Select_Details_Command, "bottom-bar click maps details command");

      Layout :=
        Files.Rendering.Calculate_Layout
          (Files.Rendering.Build_Snapshot (Model), Width => 1000, Height => 800, Line_Height => 20);
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model),
           X        => Layout.Main_X + 9,
           Y        => Layout.Main_Y + 9,
           Width    => 1000,
           Height   => 800,
           Activate => True);
      Assert (Action.Kind = Files.Events.Item_Click_Input_Action, "main item click translates to item action");
      Assert (Action.Item_Index = 1, "main item click returns visible item index");
      Assert (Action.Activate, "main item double-click preserves activation flag");
      Assert (not Action.Range_Selection, "plain item click does not request range selection");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model),
           X         => Layout.Main_X + 9,
           Y         => Layout.Main_Y + 9,
           Width     => 1000,
           Height    => 800,
           Modifiers => Ctrl);
      Assert (Action.Toggle_Selection, "control-click item action requests selection toggle");
      Assert (not Action.Range_Selection, "control-click item action does not request range selection");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model),
           X         => Layout.Main_X + 9,
           Y         => Layout.Main_Y + 9,
           Width     => 1000,
           Height    => 800,
           Modifiers => Shift);
      Assert (Action.Range_Selection, "shift-click item action requests range selection");
      Assert (not Action.Toggle_Selection, "shift-click item action does not request toggle selection");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model),
           X         => Layout.Main_X + 9,
           Y         => Layout.Main_Y + 9,
           Width     => 1000,
           Height    => 800,
           Modifiers => Ctrl_Shift);
      Assert (Action.Range_Selection, "control-shift item click keeps range selection precedence");
      Assert (not Action.Toggle_Selection, "control-shift item click does not also request toggle selection");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Command_Palette_Query (Model, "navigate.back");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 136, Y => 33, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "palette search click translates to text action");
      Assert
        (Action.Focus_Target = Files.Types.Focus_Command_Palette,
         "palette search click targets command-palette input");
      Assert (Action.Cursor_Position = 2, "palette search click computes text cursor position");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 108, Y => 33, Width => 1000, Height => 800);
      Assert (Action.Cursor_Position = 0, "palette search click clamps cursor to text start");
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 891, Y => 33, Width => 1000, Height => 800);
      Assert
        (Action.Cursor_Position = Palette_Query_Length,
         "palette search click clamps cursor to text end");
      declare
         Tiny_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Tiny_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Tiny_Snapshot, Width => 40, Height => 10, Line_Height => 20);
         Tiny_Palette  : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Tiny_Layout, Line_Height => 20);
      begin
         Action :=
           Click_Action
             (Tiny_Snapshot,
              X      => Tiny_Palette.Search_X,
              Y      => Tiny_Palette.Search_Y + Tiny_Palette.Search_Height - 1,
              Width  => 40,
              Height => 10);
         Assert
           (Action.Kind = Files.Events.Text_Click_Input_Action,
            "tiny palette search click uses clipped search height");
         Assert
           (Action.Focus_Target = Files.Types.Focus_Command_Palette,
            "tiny palette search click targets command-palette input");
         Action :=
           Click_Action
             (Tiny_Snapshot,
              X      => Tiny_Palette.Search_X,
              Y      => Tiny_Palette.Search_Y + Tiny_Palette.Search_Height,
              Width  => 40,
              Height => 10);
         Assert
           (Action.Kind = Files.Events.No_Input_Action,
            "tiny palette rejects click after clipped search field");
      end;

      declare
         Click_Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Click_Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Click_Snapshot, Width => 1000, Height => 800, Line_Height => 20);
         Click_Palette  : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Click_Layout, Line_Height => 20);
      begin
         Action :=
           Click_Action
             (Click_Snapshot,
              X      => Click_Palette.Results_X + 1,
              Y      => Click_Palette.Results_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Command_Result_Click_Input_Action,
            "palette result click translates to result action");
         Assert (Action.Result_Index = 1, "palette result click returns result index");
         Action :=
           Click_Action
             (Click_Snapshot,
              X      => Click_Palette.Results_X + 1,
              Y      => Click_Palette.Results_Y + 25,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Kind = Files.Events.Command_Result_Click_Input_Action,
            "palette result description click translates to result action");
         Assert (Action.Result_Index = 1, "palette result description click returns result index");
      end;
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 10, Y => 10, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.No_Input_Action, "palette blocks toolbar clicks behind overlay");

      declare
         Palette_Snapshot : Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Palette_Layout   : Files.Rendering.Command_Palette_Layout;
         Track_X          : Natural;
      begin
         Files.Model.Set_Command_Palette_Query (Model, "");
         Files.Model.Set_Command_Palette_Result_Offset (Model, 1);
         Palette_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Layout :=
           Files.Rendering.Calculate_Layout (Palette_Snapshot, Width => 1000, Height => 160, Line_Height => 20);
         Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
         Track_X := Palette_Layout.Results_X + Palette_Layout.Results_Width - 1;
         Action :=
           Click_Action
             (Palette_Snapshot,
              X      => Track_X,
              Y      => Palette_Layout.Results_Y + Palette_Layout.Results_Height - 1,
              Width  => 1000,
              Height => 160);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "palette scrollbar click translates to scroll");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Command_Palette, "palette scrollbar targets palette");
         Assert (Action.Scroll_Lines = 5, "palette scrollbar below thumb scrolls down by a page step");
         Palette_Snapshot.Command_Palette_Result_Offset := 0;
         Action :=
           Click_Action
             (Palette_Snapshot,
              X      => Track_X,
              Y      => Palette_Layout.Results_Y,
              Width  => 1000,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "palette thumb click is inert");
         Palette_Snapshot.Command_Palette_Result_Offset := 0;

         Layout :=
           Files.Rendering.Calculate_Layout (Palette_Snapshot, Width => 100, Height => 100, Line_Height => 20);
         Palette_Layout := Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height => 20);
         Action :=
           Click_Action
              (Palette_Snapshot,
               X      => Palette_Layout.Results_X + Palette_Layout.Results_Width - 1,
              Y      => Palette_Layout.Results_Y,
               Width  => 100,
               Height => 100);
         Assert (Action.Kind = Files.Events.No_Input_Action, "partial palette thumb click is inert");
      end;

      Files.Model.Close_Command_Palette (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Info_Pane (Model);
      declare
         Info_Snapshot : Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Info_Pane     : Files.Rendering.Info_Pane_Layout;
      begin
         for Index in 1 .. 8 loop
            Info_Snapshot.Selected_Info.Append (Info_Snapshot.Selected_Info.Element (1));
         end loop;
         Info_Snapshot.Info_Pane_Scroll_Lines := 100;
         Layout :=
           Files.Rendering.Calculate_Layout (Info_Snapshot, Width => 360, Height => 160, Line_Height => 20);
         Info_Pane := Files.Rendering.Calculate_Info_Pane_Layout (Info_Snapshot, Layout, Line_Height => 20);
         Assert (Info_Pane.Scrollbar_Visible, "overflow info pane exposes scrollbar for hit testing");
         Assert
           (Info_Pane.Scrollbar_Track_Height = Info_Pane.Height,
            "info pane exposes explicit scrollbar track height");
         Action :=
           Click_Action
              (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X + 1,
              Y      => Info_Pane.Scrollbar_Y + 1,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "info scrollbar click translates to scroll");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Info_Pane, "info scrollbar targets info pane");
         Assert (Action.Scroll_Lines = -10, "info scrollbar above thumb scrolls up by a page step");
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X + 1,
              Y      => Info_Pane.Scrollbar_Y + Info_Pane.Height - 1,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "info scrollbar below thumb click translates");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Info_Pane, "info scrollbar below thumb targets info pane");
         Assert (Action.Scroll_Lines = 10, "info scrollbar below thumb scrolls down by a page step");
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X,
              Y      => Info_Pane.Scrollbar_Y + Info_Pane.Scrollbar_Track_Height,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "info scrollbar ignores clicks below track height");
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X,
              Y      => Info_Pane.Scrollbar_Thumb_Y,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "info scrollbar thumb click is inert");
         Info_Snapshot.Command_Palette_Open := True;
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X,
              Y      => Info_Pane.Scrollbar_Y,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "palette blocks info scrollbar clicks behind overlay");
         Info_Snapshot.Command_Palette_Open := False;
         Info_Snapshot.Root_Paths.Clear;
         Info_Snapshot.Root_Labels.Clear;
         Info_Snapshot.Root_Selector_Open := True;
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X,
              Y      => Info_Pane.Scrollbar_Y,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "root selector blocks info scrollbar clicks behind menu");
         Info_Snapshot.Root_Selector_Open := False;
         Info_Snapshot.Settings_Pane_Open := True;
         Action :=
           Click_Action
             (Info_Snapshot,
              X      => Info_Pane.Scrollbar_X,
              Y      => Info_Pane.Scrollbar_Y,
              Width  => 360,
              Height => 160);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings pane blocks info scrollbar clicks behind modal");
      end;
      Files.Model.Toggle_Info_Pane (Model);

      declare
         Main_Snapshot : Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Main_View     : Files.Rendering.Main_View_Layout;
      begin
         Main_Snapshot.Items.Clear;
         Main_Snapshot.View_Mode := Files.Types.Details;
         for Index in 1 .. 12 loop
            Main_Snapshot.Items.Append
              (Files.Rendering.Item_Snapshot'
                 (Name          => To_Unbounded_String ("item" & Natural'Image (Index)),
                  Filetype      => To_Unbounded_String ("text/plain"),
                  Filetype_Detail => To_Unbounded_String (Files.Localization.Text ("info.kind.text")),
                  Icon_Id       => To_Unbounded_String ("text"),
                  Kind          => Files.Types.Regular_File_Item,
                  Selected      => False,
                  Visible_Index => Index,
                  others        => <>));
         end loop;
         Main_Snapshot.Main_View_Scroll_Lines := 2;
         Layout :=
           Files.Rendering.Calculate_Layout (Main_Snapshot, Width => 240, Height => 120, Line_Height => 20);
         Main_View := Files.Rendering.Calculate_Main_View_Layout (Main_Snapshot, Layout, Line_Height => 20);
         Assert (Main_View.Scrollbar_Visible, "overflow main view exposes scrollbar for hit testing");
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "main scrollbar click translates to scroll");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Main_View, "main scrollbar targets main view");
         Assert (Action.Scroll_Lines = -10, "main scrollbar above thumb scrolls up by a page step");
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y + Main_View.Scrollbar_Track_Height - 1,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.Scroll_Input_Action, "main scrollbar below thumb click translates");
         Assert (Action.Scroll_Area = Files.Events.Scroll_Main_View, "main scrollbar below thumb targets main view");
         Assert (Action.Scroll_Lines = 10, "main scrollbar below thumb scrolls down by a page step");
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y + Main_View.Scrollbar_Track_Height,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.No_Input_Action, "main scrollbar ignores click below padded track");
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Thumb_Y,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.No_Input_Action, "main scrollbar thumb click is inert");
         Main_Snapshot.Command_Palette_Open := True;
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.No_Input_Action, "palette blocks main scrollbar clicks behind overlay");
         Main_Snapshot.Command_Palette_Open := False;
         Main_Snapshot.Root_Paths.Clear;
         Main_Snapshot.Root_Labels.Clear;
         Main_Snapshot.Root_Selector_Open := True;
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.No_Input_Action, "root selector blocks main scrollbar clicks behind menu");
         Main_Snapshot.Root_Selector_Open := False;
         Main_Snapshot.Settings_Pane_Open := True;
         Action :=
           Click_Action
             (Main_Snapshot,
              X      => Main_View.Scrollbar_X,
              Y      => Main_View.Scrollbar_Y,
              Width  => 240,
              Height => 120);
         Assert (Action.Kind = Files.Events.No_Input_Action, "settings pane blocks main scrollbar clicks behind modal");
      end;

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Rename (Model);
      Layout :=
        Files.Rendering.Calculate_Layout
          (Files.Rendering.Build_Snapshot (Model), Width => 1000, Height => 800, Line_Height => 20);
      declare
         Item_Rows : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout
             (Files.Rendering.Build_Snapshot (Model), Layout, Line_Height => 20);
         Row       : constant Files.Rendering.Item_Layout := Item_Rows.Element (1);
      begin
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model),
              X      => Row.Text_X + 24,
              Y      => Row.Text_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert (Action.Kind = Files.Events.Text_Click_Input_Action, "rename click translates to text action");
         Assert (Action.Focus_Target = Files.Types.Focus_Rename_Input, "rename click targets rename input");
         Assert (Action.Cursor_Position = 2, "rename click computes text cursor position");
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model),
              X      => Row.Text_X,
              Y      => Row.Text_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert (Action.Cursor_Position = 0, "rename click clamps cursor to text start");
         Action :=
           Click_Action
             (Files.Rendering.Build_Snapshot (Model),
              X      => Row.Text_X + Row.Text_Width - 1,
              Y      => Row.Text_Y + 1,
              Width  => 1000,
              Height => 800);
         Assert
           (Action.Cursor_Position = Rename_Text_Length,
            "rename click clamps cursor to text end");
      end;
      Files.Model.Toggle_Rename (Model);

      Roots.Append (To_Unbounded_String ("/"));
      Roots.Append (To_Unbounded_String ("/tmp"));
      Files.Model.Open_Root_Selector (Model, Roots);
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 10, Y => 50, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.Root_Click_Input_Action, "root row click translates to root action");
      Assert (Action.Root_Index = 1, "root row click returns root index");
      Files.Model.Open_Command_Palette (Model);
      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 10, Y => 50, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.No_Input_Action, "palette blocks root row clicks behind overlay");
      Files.Model.Close_Command_Palette (Model);
      Files.Model.Close_Root_Selector (Model);

      Action :=
        Click_Action
          (Files.Rendering.Build_Snapshot (Model), X => 999, Y => 400, Width => 1000, Height => 800);
      Assert (Action.Kind = Files.Events.No_Input_Action, "empty click translates to no input action");
   end Test_Event_Translation;


   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Rendering_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Rendering;
