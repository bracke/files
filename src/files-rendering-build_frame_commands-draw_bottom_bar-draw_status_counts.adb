separate (Files.Rendering.Build_Frame_Commands.Draw_Bottom_Bar)
   --  The counts area: the hidden / visible / selected counts (or the error
   --  line), and the free-space field beside it. The counts area doubles as
   --  the hidden-count control: clicking it toggles Show_Hidden_Files. The
   --  free-space field to its right is a separate field, so the toggle's
   --  hover/press/tooltip affordances stop at the divider rather than
   --  spanning the whole region.
   procedure Draw_Status_Counts is
      Pad       : constant Natural := Files.Rendering.Layouts.Status_Field_Padding (Line_Height);
      Cell_W    : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Free_W    : constant Natural := Free_Space_Label_Width (Snapshot, Line_Height);
      --  The counts/free split, shared with the click hit-test so the toggle's
      --  hover/press/tooltip area and the separate free-space field agree.
      Toggle_W, Divider_X, Free_X, Free_Field_W, Free_Region_W : Natural;
   begin
      Files.Rendering.Layouts.Split_Status_Region
        (Bottom.Info_X, Bottom.Info_Width, Free_W,
         Toggle_W, Divider_X, Free_X, Free_Field_W, Free_Region_W, Line_Height);
      declare
         Show_Free : constant Boolean := Free_Field_W > 0;
         Counts_W  : constant Natural := (if Toggle_W > 2 * Pad then Toggle_W - 2 * Pad else 0);
         Info_Text : constant UString := Bottom_Info_Text (Snapshot);
         --  When the labelled counts do not fit the available width, collapse
         --  to just the three numbers (hidden / visible / selected),
         --  slash-separated and label-less. The error line is never collapsed.
         Compact   : constant String := Compact_Count_Status_Text (Snapshot);
         Use_Compact : constant Boolean :=
           Length (Snapshot.Last_Error_Key) = 0
           and then Saturating_Multiply (Guikit.Utf8.Display_Units (To_String (Info_Text)), Cell_W) > Counts_W;
         Status_Text : constant UString :=
           (if Use_Compact then To_Unbounded_String (Compact) else Info_Text);
         --  The counts area is the clickable hidden-files toggle, so its text
         --  is drawn in the active control colour (white when enabled), like
         --  the neighbouring toggle buttons, rather than the muted info colour
         --  used for the non-clickable free-space field. The error line keeps
         --  the error colour.
         Counts_Color : constant Render_Color :=
           (if Length (Snapshot.Last_Error_Key) > 0 then Error_Text_Color
            else Command_Color (Files.Commands.Toggle_Hidden_Files_Command));
         --  The counts tooltip carries the toggle action plus a legend of the
         --  three numbers (hidden / visible / selected, in display order), so
         --  their meaning is clear even when the small-window form drops the
         --  labels down to "N/N/N". The legend reuses the status labels, so it
         --  is localized and matches the compact separator.
         Counts_Tip : constant UString :=
           Command_Tooltip_Text (Files.Commands.Toggle_Hidden_Files_Command) & Count_Legend_Text;
      begin
         Add_Button
           (Bottom.Info_X, Toggle_W,
            Selected => False,
            Hovered  =>
              Is_Hovered (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height),
            Pressed  => Is_Pressed (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height),
            Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
         Add_Text
           (Guikit.Layout.Saturating_Add (Bottom.Info_X, Pad),
            Bottom_Content_Y,
            Counts_W,
            Bottom_Content_H,
            Status_Text,
            Counts_Color,
            Fit => True);
         if Show_Free then
            Draw_Free_Space (Divider_X, Free_X, Free_Field_W, Free_Region_W);
         end if;
         Add_Tooltip_Text
           (Bottom.Info_X,
            Bottom_Content_Y,
            Toggle_W,
            Bottom_Content_H,
            Counts_Tip);
         Add_Accessibility_Node
           (Role_Button,
            Bottom.Info_X,
            Bottom_Content_Y,
            Toggle_W,
            Bottom_Content_H,
            Command_Label (Files.Commands.Toggle_Hidden_Files_Command),
            Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Hidden_Files_Command)),
            Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
      end;
   end Draw_Status_Counts;
