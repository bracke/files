with Files.Interaction;
with Files.Model.Tree_Panel;
with Files.Rendering.Hit;
with Files.Rendering.Layouts;
with Files.UI_Types;

package body Files.Application.Windows.Gestures is
   use Ada.Strings.Unbounded;
   use type Glfw.Size;
   use type Files.Events.Input_Action_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Types.Detail_Column;

   procedure Arm
     (Runtime : in out Runtime_Window;
      Action  : Files.Events.Input_Action;
      Armed   : out Boolean) is
   begin
      Armed := True;
      case Action.Kind is
         --  The scrollbar drag follows the pointer from the anchor where the
         --  thumb was grabbed (Update_Scrollbar_Drag).
         when Files.Events.Scrollbar_Drag_Begin_Input_Action =>
            Runtime.Scrollbar_Drag_Target := Action.Scroll_Area;
            Runtime.Scrollbar_Drag_Anchor := Action.Scroll_Drag_Anchor;

         --  The resize is applied per frame (Update_Column_Resize_Drag).
         when Files.Events.Column_Resize_Begin_Input_Action =>
            Runtime.Column_Resize.Active := True;
            Runtime.Column_Resize.Changed := False;
            Runtime.Column_Resize.Target := Action.Column;
            Runtime.Column_Resize.Origin_X := Action.Origin_X;
            Runtime.Column_Resize.Origin_W := Action.Column_Width;

         --  The drop, or the sort a press without a drag makes, is applied
         --  at release (Update_Column_Reorder_Drag).
         when Files.Events.Column_Reorder_Begin_Input_Action =>
            Runtime.Column_Reorder.Active := True;
            Runtime.Column_Reorder.Target := Action.Column;
            Runtime.Column_Reorder.Origin_X := Action.Origin_X;
            Runtime.Column_Reorder.Started := False;
            Runtime.Column_Reorder.Sort := Action.Sort_Command;

         --  The selection is applied per frame (Update_Marquee_Drag). The
         --  selection before the press is kept, so an additive drag unions
         --  with it however often the band is applied again; the origin is
         --  on the frame on screen, so it is anchored to that frame's scroll.
         when Files.Events.Marquee_Begin_Input_Action =>
            declare
               Slot : constant Snapshot_Slot := Hit_Slot (Runtime);
            begin
               Runtime.Marquee.Scroll_Pixels :=
                 Files.Rendering.Layouts.Calculate_Main_View_Layout
                   (Runtime.View.Snapshots (Slot),
                    Runtime.Cached_Frame.Layout,
                    Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size)).Scroll_Pixels;
            end;
            Runtime.Marquee.Active := True;
            Runtime.Marquee.Moved := False;
            Runtime.Marquee.Last_X := Integer'First;
            Runtime.Marquee.Last_Scroll := Files.Model.Main_View_Scroll_Lines (Runtime.Model);
            Runtime.Marquee.Origin_X := Action.Origin_X;
            Runtime.Marquee.Origin_Y := Action.Origin_Y;
            Runtime.Marquee.Additive := Action.Additive;
            Runtime.Marquee.Base := Files.Interaction.Marquee_Base (Runtime.Model);
            Runtime.Marquee.Rect_X := 0;
            Runtime.Marquee.Rect_Y := 0;
            Runtime.Marquee.Rect_W := 0;
            Runtime.Marquee.Rect_H := 0;

         when others =>
            Armed := False;
      end case;
   end Arm;

   procedure Update_Scrollbar_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
 is separate;

   --  End a column-resize drag. Its moves resized the column in memory only;
   --  the settings file is written once, here.
   procedure End_Column_Resize_Drag (Runtime : in out Runtime_Window) is
   begin
      if Runtime.Column_Resize.Active then
         Files.Interaction.End_Column_Resize
           (Model         => Runtime.Model,
            Settings      => Runtime.Settings,
            Settings_Path => To_String (Runtime.Settings_Path),
            Changed       => Runtime.Column_Resize.Changed);
      end if;
      Runtime.Column_Resize.Active := False;
      Runtime.Column_Resize.Changed := False;
   end End_Column_Resize_Drag;

   procedure Update_Column_Resize_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Mouse_Down : Boolean)
   is
      Result : Files.Interaction.Interaction_Result;
   begin
      if not Runtime.Column_Resize.Active then
         return;
      elsif not Mouse_Down or else Window_W = 0 or else Frame_W = 0 then
         End_Column_Resize_Drag (Runtime);
         return;
      end if;

      Files.Interaction.Apply_Column_Resize
        (Model        => Runtime.Model,
         Settings     => Runtime.Settings,
         Column       => Runtime.Column_Resize.Target,
         Origin_X     => Runtime.Column_Resize.Origin_X,
         Origin_Width => Runtime.Column_Resize.Origin_W,
         Current_X    => Scale_X (Cursor_X, Window_W, Frame_W),
         Result       => Result,
         Line_Height  => Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size));
      if Result.Settings_Changed then
         Runtime.Column_Resize.Changed := True;
      end if;
   end Update_Column_Resize_Drag;

   --  Minimum pointer travel, in frame pixels at the reference line height
   --  (scaled with the text), before an armed header press becomes a reorder
   --  drag. Below it a press/release is treated as a sort click, matching the
   --  resize hot zone's grabbable-yet-forgiving feel.
   Column_Reorder_Threshold : constant := 6;

   procedure Update_Column_Reorder_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
   is separate;

   --  Minimum pointer travel, in frame pixels, before an armed empty-space press
   --  becomes a marquee. Below it the press/release is a plain empty-space click
   --  that leaves the selection untouched, matching the pre-marquee no-op.
   Marquee_Drag_Threshold : constant := 4;

   procedure Update_Marquee_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
 is separate;

   --  Pointer gestures are tracked outside the model so they can update every
   --  frame.  If a keyboard shortcut opens an overlay while the button remains
   --  held, cancel every background gesture before its next update; otherwise
   --  scrolling, selection, or column settings can continue changing invisibly.
   procedure Cancel_Background_Gestures_For_Overlay
     (Runtime : in out Runtime_Window)
   is
      use type Files.Events.Scroll_Target;
      --  The destination picker is modal, but its tree scrollbar belongs to the
      --  modal surface rather than the background. Preserve only that gesture;
      --  every file-grid drag and any scrollbar owned by covered content still
      --  gets canceled below.
      Keep_Tree_Scrollbar : constant Boolean :=
        Files.Model.Tree_Panel.Pick_Is_Active (Runtime.Model)
        and then Files.Model.Tree_Panel.Is_Open (Runtime.Model)
        and then Runtime.Scrollbar_Drag_Target = Files.Events.Scroll_Tree_Panel
        and then not Files.Model.Other_Input_Owning_Overlay_Is_Open (Runtime.Model, Files.UI_Types.Tree_Pick_Overlay);
   begin
      if not Files.Model.Input_Owning_Overlay_Is_Open (Runtime.Model) then
         return;
      end if;

      Runtime.Drag_Source_Index := 0;
      if not Keep_Tree_Scrollbar then
         Runtime.Scrollbar_Drag_Target := Files.Events.No_Scroll_Target;
         Runtime.Scrollbar_Drag_Anchor := 0;
      end if;
      End_Column_Resize_Drag (Runtime);
      Runtime.Column_Reorder.Active := False;
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      Runtime.Marquee.Active := False;
      Runtime.Marquee.Moved := False;
      Runtime.Marquee.Base.Clear;
      Runtime.Marquee.Rect_X := 0;
      Runtime.Marquee.Rect_Y := 0;
      Runtime.Marquee.Rect_W := 0;
      Runtime.Marquee.Rect_H := 0;
   end Cancel_Background_Gestures_For_Overlay;

   procedure Update
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean) is
   begin
      Cancel_Background_Gestures_For_Overlay (Runtime);
      Update_Scrollbar_Drag (Runtime, Cursor_Y, Window_W, Window_H, Frame_W, Frame_H, Mouse_Down);
      Update_Column_Resize_Drag (Runtime, Cursor_X, Window_W, Frame_W, Mouse_Down);
      Update_Column_Reorder_Drag (Runtime, Cursor_X, Cursor_Y, Window_W, Window_H, Frame_W, Frame_H, Mouse_Down);
      Update_Marquee_Drag (Runtime, Cursor_X, Cursor_Y, Window_W, Window_H, Frame_W, Frame_H, Mouse_Down);
   end Update;

end Files.Application.Windows.Gestures;
