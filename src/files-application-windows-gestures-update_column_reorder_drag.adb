with Files.Preference_Types;
with Files.Input_Actions;
with Files.Rendering.Layouts;
separate (Files.Application.Windows.Gestures)
procedure Update_Column_Reorder_Drag
  (Runtime    : in out Runtime_Window;
   Cursor_X   : Glfw.Input.Mouse.Coordinate;
   Cursor_Y   : Glfw.Input.Mouse.Coordinate;
   Window_W   : Glfw.Size;
   Window_H   : Glfw.Size;
   Frame_W    : Glfw.Size;
   Frame_H    : Glfw.Size;
   Mouse_Down : Boolean)
is
   X_Frame : Integer;

   --  What a release is hit-tested against: the drawn snapshot, laid out at
   --  this frame size, and the pointer's row in it.
   procedure With_Release_Layout
     (Visit : not null access procedure
        (Snapshot    : Files.Rendering.View_Snapshot;
         Layout      : Files.Rendering.Layout_Metrics;
         Y_Frame     : Natural;
         Line_Height : Positive))
   is
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      Snapshot    : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Hit_Slot (Runtime));
   begin
      Visit
        (Snapshot    => Snapshot,
         Layout      =>
           Files.Rendering.Layouts.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height),
         Y_Frame     => Files.Window_Policy.Scale_Coordinate (Cursor_Y, Window_H, Frame_H),
         Line_Height => Line_Height);
   end With_Release_Layout;

   --  Apply the reorder at the drop target under the pointer.
   procedure Drop_Column
     (Snapshot    : Files.Rendering.View_Snapshot;
      Layout      : Files.Rendering.Layout_Metrics;
      Y_Frame     : Natural;
      Line_Height : Positive)
   is
      Drop   : constant Natural :=
        Files.Rendering.Hit.Details_Header_Drop_Index
          (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
      Result : Files.Interaction.Interaction_Result;
   begin
      if Drop in Files.Preference_Types.Detail_Column_Index then
         Files.Interaction.Apply_Column_Reorder
           (Model         => Runtime.Model,
            Settings      => Runtime.Settings,
            Settings_Path => To_String (Runtime.Settings_Path),
            Column        => Runtime.Column_Reorder.Target,
            To_Index      => Drop,
            Result        => Result);
         Flush_System_Clipboard (Runtime);
      end if;
   end Drop_Column;

   --  Sort by the pressed column when the release lands on its cell.
   procedure Sort_By_Column
     (Snapshot    : Files.Rendering.View_Snapshot;
      Layout      : Files.Rendering.Layout_Metrics;
      Y_Frame     : Natural;
      Line_Height : Positive)
   is
      Cell : constant Files.Rendering.Layouts.Detail_Header_Cell :=
        Files.Rendering.Hit.Details_Header_Cell_At
          (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
   begin
      if Cell.Present
        and then Cell.Column = Runtime.Column_Reorder.Target
        and then Cell.Command = Runtime.Column_Reorder.Sort
      then
         Dispatch_Click_Action
           (Runtime,
            (Kind    => Files.Input_Actions.Command_Input_Action,
             Command => Runtime.Column_Reorder.Sort),
            Guikit.Input.No_Modifiers);
      end if;
   end Sort_By_Column;
begin
   if not Runtime.Column_Reorder.Active then
      return;
   elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
      Runtime.Column_Reorder.Active := False;
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      return;
   end if;

   X_Frame := Files.Window_Policy.Scale_X (Cursor_X, Window_W, Frame_W);

   if Mouse_Down then
      --  Frame pixels: the drag distance is scaled to them.
      if Files.Window_Policy.Is_Drag
        (Long_Float (X_Frame - Runtime.Column_Reorder.Origin_X), 0.0, Runtime.Pixel_Ratio)
      then
         Runtime.Column_Reorder.Started := True;
      end if;
      return;
   end if;

   --  Mouse released: end the gesture. A crossed threshold applies the
   --  reorder at the drop target; otherwise the press was a plain click and
   --  falls back to the column's sort command (if any), but only when the
   --  release still lands on the cell that was pressed.
   Runtime.Column_Reorder.Active := False;

   if not Files.Window_Policy.Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H) then
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      return;
   end if;

   if Runtime.Column_Reorder.Started then
      With_Release_Layout (Drop_Column'Access);
   elsif Runtime.Column_Reorder.Sort /= Files.Commands.No_Command then
      With_Release_Layout (Sort_By_Column'Access);
   end if;

   Runtime.Column_Reorder.Started := False;
   Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
end Update_Column_Reorder_Drag;
