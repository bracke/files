with Files.Commands;
with Files.Localization;

with Ada.Strings.Unbounded;

with Guikit.Layout;
use Guikit.Layout;

package body Files.UI is

   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Guikit.Layout.Bottom_Bar_Layout
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);

      --  Size the sort button to the active field's label only (plus the
      --  direction indicator), not the widest field, so it is never wider than
      --  the text it shows.
      Sort_Label_W : constant Natural :=
        Label_Pixel_Width
          (Files.Localization.Text (Files.Commands.Sort_Label_Key (Sort_Field))
           & " "
           & Files.Localization.Text ("sort.direction.ascending"),
           Cell_W);
   begin
      return
        Guikit.Layout.Calculate_Bottom_Bar_Layout
          (Width               => Width,
           Small_Label_Width   =>
             Label_Pixel_Width (Files.Localization.Text ("command.view.small.short"), Cell_W),
           Large_Label_Width   =>
             Label_Pixel_Width (Files.Localization.Text ("command.view.large.short"), Cell_W),
           Details_Label_Width =>
             Label_Pixel_Width (Files.Localization.Text ("command.view.details.short"), Cell_W),
           Sort_Label_Width    => Sort_Label_W,
           Info_Label_Width    =>
             Label_Pixel_Width (Files.Localization.Text ("command.info.toggle.short"), Cell_W),
           Line_Height         => Line_Height);
   end Calculate_Bottom_Bar_Layout;

   function Sort_Menu_Width
     (Line_Height : Positive := 20)
      return Natural
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);

      function Label_W (Key : String) return Natural is
        (Label_Pixel_Width
           (Files.Localization.Text (Key)
            & " "
            & Files.Localization.Text ("sort.direction.ascending"),
            Cell_W));

      Widest : constant Natural :=
        Natural'Max
          (Label_W ("command.sort.name"),
           Natural'Max
             (Label_W ("command.sort.size"),
              Natural'Max
                (Label_W ("command.sort.type"),
                 Natural'Max
                   (Label_W ("command.sort.created"),
                    Label_W ("command.sort.changed")))));
   begin
      --  Mirror the sort button's sizing (guikit Calculate_Bottom_Bar_Layout) but
      --  for the widest field, so the dropdown never clips a row.
      return
        Natural'Max
          (Saturating_Multiply (Line_Height, 2),
           Saturating_Add (Widest, Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)));
   end Sort_Menu_Width;

   function Sort_Menu_Visible_Width
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Natural
   is
      Bottom : constant Bottom_Bar_Layout :=
        Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
   begin
      if Bottom.Sort_Button_Width = 0 or else Bottom.Sort_Button_X >= Width then
         return 0;
      end if;
      return Natural'Min
        (Sort_Menu_Width (Line_Height), Width - Bottom.Sort_Button_X);
   end Sort_Menu_Visible_Width;

   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector is
      Result : Guikit.Segmented.Segment_Vectors.Vector;

      procedure Add (Key : String) is
      begin
         Result.Append
           (Guikit.Segmented.Segment'
              (Label   => Ada.Strings.Unbounded.To_Unbounded_String (Files.Localization.Text (Key)),
               others  => <>));
      end Add;
   begin
      Add ("command.view.small.short");
      Add ("command.view.large.short");
      Add ("command.view.details.short");
      return Result;
   end View_Mode_Segments;

   function Filter_Scope_Chip_Width
     (Line_Height : Positive := 20)
      return Natural
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);

      function Label_W (Key : String) return Natural is
      begin
         return Label_Pixel_Width (Files.Localization.Text (Key), Cell_W);
      end Label_W;

      Widest : constant Natural :=
        Natural'Max
          (Label_W ("search.scope.here"),
           Natural'Max
             (Label_W ("search.scope.names"),
              Label_W ("search.scope.contents")));
   begin
      return Widest + 2 * Input_Field_Padding;
   end Filter_Scope_Chip_Width;

   function Calculate_Settings_Entry_Button_Layout
     (Pane_X      : Natural;
      Pane_Width  : Natural;
      Line_Height : Positive := 20)
      return Guikit.Layout.Settings_Entry_Button_Layout
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);
   begin
      return
        Guikit.Layout.Calculate_Settings_Entry_Button_Layout
          (Pane_X             => Pane_X,
           Pane_Width         => Pane_Width,
           Add_Label_Width    =>
             Label_Pixel_Width (Files.Localization.Text ("settings.add"), Cell_W),
           Remove_Label_Width =>
             Label_Pixel_Width (Files.Localization.Text ("settings.remove"), Cell_W));
   end Calculate_Settings_Entry_Button_Layout;

   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural;
      Line_Height      : Positive := 20)
   is
      Pad        : constant Natural := 4;
      Div_Gap    : constant Natural := 8;
      Count_Cell : constant Natural := Caret_Advance_Width (Line_Height);
      --  Preserve enough room for a representative compact count such as
      --  "0/31/0", including the renderer's horizontal padding. Disk-space
      --  information yields before these primary counts become an ellipsis.
      Minimum_Counts : constant Natural :=
        Saturating_Add (Saturating_Multiply (Count_Cell, 6), 2 * Pad);
      --  Only split when there is a free label and room for it plus the divider
      --  gaps and a complete compact count summary.
      Show    : constant Boolean :=
        Free_Label_Width > 0
        and then Info_Width >=
          Saturating_Add (Free_Label_Width, Saturating_Add (2 * Div_Gap, Minimum_Counts));
   begin
      if not Show then
         Toggle_Width     := Info_Width;
         Divider_X        := 0;
         Free_Field_X     := 0;
         Free_Field_Width := 0;
         return;
      end if;

      Free_Field_X     := Saturating_Add (Info_X, Info_Width - Free_Label_Width - Pad);
      Divider_X        := (if Free_Field_X > Div_Gap then Free_Field_X - Div_Gap else 0);
      Toggle_Width     := (if Divider_X > Info_X then Divider_X - Info_X else 0);
      Free_Field_Width := Saturating_Add (Free_Label_Width, Pad);
   end Split_Status_Region;

end Files.UI;
