separate (Files.Rendering.Layouts)
   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural;
      Free_Region_Width : out Natural;
      Line_Height      : Positive)
   is
      Pad        : constant Natural := Status_Field_Padding (Line_Height);
      Div_Gap    : constant Natural := Guikit.Layout.Scaled (8, Line_Height);
      Count_Cell : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
      --  Preserve enough room for a representative compact count such as
      --  "0/31/0", including the renderer's horizontal padding. Disk-space
      --  information yields before these primary counts become an ellipsis.
      Minimum_Counts : constant Natural :=
        Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Multiply (Count_Cell, 6), 2 * Pad);
      --  Only split when there is a free label and room for it plus the divider
      --  gaps and a complete compact count summary.
      Show    : constant Boolean :=
        Free_Label_Width > 0
        and then Info_Width >=
          Guikit.Layout.Saturating_Add (Free_Label_Width, Guikit.Layout.Saturating_Add (2 * Div_Gap, Minimum_Counts));
   begin
      if not Show then
         Toggle_Width     := Info_Width;
         Divider_X        := 0;
         Free_Field_X     := 0;
         Free_Field_Width := 0;
         Free_Region_Width := 0;
         return;
      end if;

      Free_Field_X     := Guikit.Layout.Saturating_Add (Info_X, Info_Width - Free_Label_Width - Pad);
      Divider_X        := (if Free_Field_X > Div_Gap then Free_Field_X - Div_Gap else 0);
      Toggle_Width     := (if Divider_X > Info_X then Divider_X - Info_X else 0);
      Free_Field_Width := Guikit.Layout.Saturating_Add (Free_Label_Width, Pad);
      Free_Region_Width :=
        (if Guikit.Layout.Saturating_Add (Info_X, Info_Width) > Divider_X
         then Guikit.Layout.Saturating_Add (Info_X, Info_Width) - Divider_X
         else 0);
   end Split_Status_Region;
