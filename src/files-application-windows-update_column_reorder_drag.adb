separate (Files.Application.Windows)
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
begin
   if not Runtime.Column_Reorder.Active then
      return;
   elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
      Runtime.Column_Reorder.Active := False;
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      return;
   end if;

   X_Frame := Scale_Coordinate (Cursor_X, Window_W, Frame_W);

   if Mouse_Down then
      if abs (X_Frame - Runtime.Column_Reorder.Origin_X)
        > Guikit.Layout.Scaled (Column_Reorder_Threshold, Cell_Height_For (Runtime.Font_Pixel_Size))
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

   if not Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H) then
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      return;
   end if;

   if Runtime.Column_Reorder.Started then
      declare
         Y_Frame  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Hit_Slot (Runtime));
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Drop     : constant Natural :=
           Files.Rendering.Hit.Details_Header_Drop_Index
             (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
         Result   : Files.Interaction.Interaction_Result;
      begin
         if Drop in Files.Types.Detail_Column_Index then
            Files.Interaction.Apply_Column_Reorder
              (Model         => Runtime.Model,
               Settings      => Runtime.Settings,
               Settings_Path => To_String (Runtime.Settings_Path),
               Column        => Runtime.Column_Reorder.Target,
               To_Index      => Drop,
               Result        => Result);
            Apply_Interaction_Result (Runtime, Result);
         end if;
      end;
   elsif Runtime.Column_Reorder.Sort /= Files.Commands.No_Command then
      declare
         Y_Frame  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Hit_Slot (Runtime));
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Cell     : constant Files.Rendering.Detail_Header_Cell :=
           Files.Rendering.Hit.Details_Header_Cell_At
             (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
      begin
         if Cell.Present
           and then Cell.Column = Runtime.Column_Reorder.Target
           and then Cell.Command = Runtime.Column_Reorder.Sort
         then
            Dispatch_Click_Action
              (Runtime,
               (Kind    => Files.Events.Command_Input_Action,
                Command => Runtime.Column_Reorder.Sort),
               Guikit.Input.No_Modifiers);
         end if;
      end;
   end if;

   Runtime.Column_Reorder.Started := False;
   Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
end Update_Column_Reorder_Drag;
