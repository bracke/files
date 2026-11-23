with Files.Rendering.Layouts;
separate (Files.Application.Windows)
   procedure Reveal_Selection (Runtime : in out Runtime_Window) is
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Selected : constant Natural := Files.Model.Selection.Selected_Index (Runtime.Model);
   begin
      if Runtime.Handle = null or else Selected = 0 then
         Files.Controller.Reveal_Selection (Runtime.Model, Lines => 0, Current => False);
         return;
      end if;
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Refresh_Snapshot (Runtime);
      declare
         Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot    : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Current_Slot);
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Layouts.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Lines       : constant Natural :=
           Files.Rendering.Layouts.Scroll_Lines_Revealing (Snapshot, Layout, Line_Height, Positive (Selected));
      begin
         Files.Controller.Reveal_Selection (Runtime.Model, Lines);
      end;
   end Reveal_Selection;
