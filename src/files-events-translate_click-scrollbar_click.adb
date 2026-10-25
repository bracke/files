separate (Files.Events.Translate_Click)
--  The info-pane and main-view scrollbars.
procedure Scrollbar_Click (Handled : out Boolean; Result : out Input_Action) is
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
           Y,
           10,
           Snapshot.Info_Pane_Scroll_Lines,
           Maximum_Line_Offset
             (Info_Pane.Content_Height,
              Info_Pane.Height,
              Info_Pane.Scrollbar_Visible));
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
           Y,
           10,
           Snapshot.Main_View_Scroll_Lines,
           Maximum_Line_Offset
             (Main_View.Content_Height,
              Main_View.Scrollbar_Track_Height,
              Main_View.Scrollbar_Visible));
      return;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Scrollbar_Click;
