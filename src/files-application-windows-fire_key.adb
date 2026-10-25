separate (Files.Application.Windows)
   procedure Fire_Key
     (Runtime   : in out Runtime_Window;
      Key       : Tracked_Key;
      Modifiers : Guikit.Input.Modifier_Set;
      Consumed  : out Boolean)
   is

      function Tree_Page_Rows return Natural
      is
         Frame_W : Glfw.Size := 0;
         Frame_H : Glfw.Size := 0;
      begin
         if not Files.Model.Tree_Pick_Is_Active (Runtime.Model) then
            return 0;
         end if;

         Glfw.Windows.Get_Framebuffer_Size
           (As_Window (Runtime.Handle), Frame_W, Frame_H);
         if Frame_W = 0 or else Frame_H = 0 then
            return 0;
         end if;

         declare
            Line_Height : constant Positive :=
              Cell_Height_For (Runtime.Font_Pixel_Size);

            function Capacity_For
              (Snapshot : Files.Rendering.View_Snapshot)
               return Natural
            is
               Layout : constant Files.Rendering.Layout_Metrics :=
                 Files.Rendering.Calculate_Layout
                   (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
               Tree : constant Files.Rendering.Tree_Panel_Layout :=
                 Files.Rendering.Calculate_Tree_Panel_Layout
                   (Snapshot, Layout, Line_Height);
            begin
               return Files.Rendering.Tree_Row_Capacity (Snapshot, Tree);
            end Capacity_For;
         begin
            --  Key repeats arrive between frames; the current snapshot is
            --  rebuilt only when the model or settings moved since, rather
            --  than paying the O(items) rebuild on every keystroke.
            Refresh_Snapshot (Runtime);
            return Capacity_For (Runtime.Snapshots (Runtime.Current_Slot));
         end;
      end Tree_Page_Rows;
   begin
      Consumed := False;
      if Runtime.Handle = null then
         return;
      end if;

      --  Ctrl + Plus / Ctrl + Minus / Ctrl + 0 keyboard zoom flows through the
      --  shared key seam (Files.Interaction.Handle_Key adjusts the font size in
      --  the settings model and reports Font_Size_Changed); the shell's
      --  Apply_Interaction_Result then syncs the live size and rebuilds glyphs.
      Refresh_Selection_Grid_Columns (Runtime);
      declare
         Result : Files.Interaction.Interaction_Result;
      begin
         --  Genuine live key dispatch flows through the testable seam: it runs
         --  the focus-aware controller and re-routes settings-path commands
         --  through Execute_Command. Clear_Pending_Text asks the caller to drop
         --  this keystroke's own character event.
         Files.Interaction.Handle_Key
           (Model             => Runtime.Model,
            Settings          => Runtime.Settings,
            Settings_Path     => To_String (Runtime.Settings_Path),
            Key               => To_Key_Code (Key),
            Modifiers         => Modifiers,
            Current_Font_Size => Runtime.Font_Pixel_Size,
            Result            => Result,
            Tree_Page_Rows    => Tree_Page_Rows);
         Apply_Interaction_Result (Runtime, Result);
         Consumed := Result.Clear_Pending_Text;
      end;
   end Fire_Key;
