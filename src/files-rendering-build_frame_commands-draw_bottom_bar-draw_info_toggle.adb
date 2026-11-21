separate (Files.Rendering.Build_Frame_Commands.Draw_Bottom_Bar)
   --  The info-pane toggle at the right end of the bar.
   procedure Draw_Info_Toggle is
   begin
      Add_Rect
        (Bottom.Info_Pane_X,
         Info_Btn_Y,
         Bottom.Info_Pane_Width,
         Info_Btn_H,
         (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) then Pane_Color
          elsif Snapshot.Info_Pane_Open
          then Selection_Color
          elsif Is_Pressed
            (Bottom.Info_Pane_X,
             Bottom_Y,
             Bottom.Info_Pane_Width,
             Layout.Bottom_Bar_Height)
          then Pressed_Color
          elsif Is_Hovered (Bottom.Info_Pane_X, Bottom_Y, Bottom.Info_Pane_Width, Layout.Bottom_Bar_Height)
          then Hover_Color
          else Bottom_Bar_Color));
      declare
         --  The label's inset inside the toggle, scaled with the text.
         Inset : constant Natural := Guikit.Layout.Scaled (4, Line_Height);
      begin
         Add_Text
           (Guikit.Layout.Saturating_Add (Bottom.Info_Pane_X, Inset),
            Bottom_Content_Y,
            (if Bottom.Info_Pane_Width > 2 * Inset then Bottom.Info_Pane_Width - 2 * Inset else 0),
            Bottom_Content_H,
            Bottom_Command_Label (Files.Commands.Toggle_Info_Pane_Command),
            Command_Color (Files.Commands.Toggle_Info_Pane_Command),
            Fit => True);
      end;
      Add_Command_Tooltip
        (Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Files.Commands.Toggle_Info_Pane_Command);
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command),
         Selected => Snapshot.Info_Pane_Open);
   end Draw_Info_Toggle;
