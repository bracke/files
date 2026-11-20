with Files.Input_Actions;
separate (Files.Application.Windows)
   function Current_Click_Action
     (Runtime   : in out Runtime_Window;
      Window_W  : Glfw.Size;
      Window_H  : Glfw.Size;
      Frame_W   : Glfw.Size;
      Frame_H   : Glfw.Size;
      Cursor_X  : Glfw.Input.Mouse.Coordinate;
      Cursor_Y  : Glfw.Input.Mouse.Coordinate;
      Modifiers : Guikit.Input.Modifier_Set)
      return Files.Input_Actions.Input_Action
   is
      At_Cursor : constant Hit_Position :=
        Hit_Position_At (Runtime, Window_W, Window_H, Frame_W, Frame_H, Cursor_X, Cursor_Y);
   begin
      if not At_Cursor.Inside then
         return (Kind => Files.Input_Actions.No_Input_Action);
      end if;

      declare
         Action : Files.Input_Actions.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot    => Runtime.View.Snapshots (At_Cursor.Slot),
              Frame       => Runtime.Cached_Frame,
              X           => At_Cursor.X,
              Y           => At_Cursor.Y,
              Width       => At_Cursor.Width,
              Height      => At_Cursor.Height,
              Modifiers   => Modifiers,
              Line_Height => At_Cursor.Line_Height);
      begin
         if Action.Kind = Files.Input_Actions.Item_Click_Input_Action then
            Action.Item_Index := Current_Item_Index (Runtime, At_Cursor.Slot, Action.Item_Index);
            if Action.Item_Index = 0 then
               return (Kind => Files.Input_Actions.No_Input_Action);
            end if;
         end if;
         return Action;
      end;
   end Current_Click_Action;
