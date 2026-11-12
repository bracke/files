separate (Files.Events.Translate_Click)
--  The info-pane and main-view scrollbars.
procedure Scrollbar_Click (Handled : out Boolean; Result : out Input_Action) is
   Main_View : constant Files.Rendering.Main_View_Layout :=
     Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
begin
   Handled := True;
   if Info_Pane.Scrollbar_Visible
     and then Within (X, Info_Pane.Scrollbar_X, Info_Pane.Scrollbar_Width)
     and then Within (Y, Info_Pane.Scrollbar_Y, Info_Pane.Scrollbar_Track_Height)
   then
      Result :=
        Scroll_Click
          (Scroll_Info_Pane,
           Info_Pane.Scrollbar_Thumb_Y,
           Info_Pane.Scrollbar_Height,
           10,
           Snapshot.Info_Pane_Scroll_Lines,
           Files.Rendering.Info_Pane_Max_Scroll (Info_Pane, Line_Height));
      return;
   elsif Main_View.Scrollbar_Visible
     and then Within (X, Main_View.Scrollbar_X, Main_View.Scrollbar_Width)
     and then Within (Y, Main_View.Scrollbar_Y, Main_View.Scrollbar_Track_Height)
   then
      Result :=
        Scroll_Click
          (Scroll_Main_View,
           Main_View.Scrollbar_Thumb_Y,
           Main_View.Scrollbar_Height,
           10,
           Snapshot.Main_View_Scroll_Lines,
           Files.Rendering.Main_View_Max_Scroll (Main_View, Line_Height));
      return;
   end if;
   Handled := False;
   Result := No_Action;
end Scrollbar_Click;
