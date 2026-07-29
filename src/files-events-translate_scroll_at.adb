separate (Files.Events)
   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive := 20)
      return Input_Action
   is
      Action  : Input_Action := Translate_Scroll (Y_Offset);
      Layout  : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Palette : constant Files.Rendering.Command_Palette_Layout :=
        Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height);
      Info    : constant Files.Rendering.Info_Pane_Layout :=
        Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);

      function Within
        (Value  : Natural;
         Start  : Natural;
         Extent : Natural)
         return Boolean is
      begin
         return Extent > 0
           and then Value >= Start
           and then Value - Start < Extent;
      end Within;
   begin
      if Action.Kind /= Scroll_Input_Action then
         return Action;
      end if;

      if Snapshot.Command_Palette_Open then
         if Within (X, Palette.Results_X, Palette.Results_Width)
           and then Within (Y, Palette.Results_Y, Palette.Results_Height)
         then
            Action.Scroll_Area := Scroll_Command_Palette;
            return Action;
         end if;

         return No_Action;
      end if;

      if Snapshot.Root_Selector_Open then
         return No_Action;
      end if;

      if Snapshot.Settings_Pane_Open then
         declare
            Settings_Pane : constant Guikit.Layout.Settings_Pane_Layout :=
              Guikit.Layout.Calculate_Settings_Pane_Layout
                (Width, Height, Layout.Toolbar_Height, Line_Height);
         begin
            if Within (X, Settings_Pane.X, Settings_Pane.Width)
              and then Within (Y, Settings_Pane.Y, Settings_Pane.Height)
            then
               Action.Scroll_Area := Scroll_Settings_Pane;
               return Action;
            end if;
         end;
         return No_Action;
      end if;

      if Snapshot.Info_Pane_Open
        and then Within (X, Info.X, Info.Width)
        and then Within (Y, Info.Y, Info.Height)
      then
         Action.Scroll_Area := Scroll_Info_Pane;
         return Action;
      end if;

      if Within (X, Layout.Main_X, Layout.Main_Width)
        and then Within (Y, Layout.Main_Y, Layout.Main_Height)
      then
         Action.Scroll_Area := Scroll_Main_View;
         return Action;
      end if;

      return No_Action;
   end Translate_Scroll_At;
