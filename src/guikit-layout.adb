with Guikit.Utf8;

package body Guikit.Layout is

   function Within
     (X          : Natural;
      Start_X    : Natural;
      Rect_Width : Natural)
      return Boolean is
   begin
      return Rect_Width > 0
        and then X >= Start_X
        and then X - Start_X < Rect_Width;
   end Within;

   function Within_Rect
     (X           : Natural;
      Y           : Natural;
      Rect_X      : Natural;
      Rect_Y      : Natural;
      Rect_Width  : Natural;
      Rect_Height : Natural)
      return Boolean is
   begin
      return Within (X, Rect_X, Rect_Width)
        and then Rect_Height > 0
        and then Y >= Rect_Y
        and then Y - Rect_Y < Rect_Height;
   end Within_Rect;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   function Caret_Advance_Width
     (Line_Height : Positive := 20)
      return Positive is
   begin
      return Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
   end Caret_Advance_Width;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Natural;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Label_Pixel_Width
     (Text   : String;
      Cell_W : Natural)
      return Natural is
   begin
      return Saturating_Multiply (Guikit.Utf8.Display_Units (Text), Cell_W);
   end Label_Pixel_Width;

   --  Horizontal gap between the filter field, the scope chip, and the right
   --  edge of the toolbar section, matching the renderer's field margin.
   Scope_Chip_Margin : constant Natural := 6;

   function Scope_Chip_Fixed_Width (Line_Height : Positive) return Natural is
   begin
      return Saturating_Multiply (Line_Height, 3);
   end Scope_Chip_Fixed_Width;

   function Filter_Scope_Chip_Region_Of
     (Toolbar     : Toolbar_Layout;
      Line_Height : Positive := 20)
      return Scope_Chip_Region
   is
      Chip_Width : constant Natural := Scope_Chip_Fixed_Width (Line_Height);
      Min_Input  : constant Natural := Saturating_Multiply (Line_Height, 2);
      Required   : constant Natural :=
        Saturating_Add
          (Saturating_Add (Chip_Width, Min_Input), Saturating_Multiply (Scope_Chip_Margin, 3));
   begin
      if Toolbar.Right_Width < Required then
         return (Visible => False, others => 0);
      end if;

      return
        (Visible => True,
         X       => Saturating_Add (Toolbar.Right_X, Toolbar.Right_Width)
                      - Scope_Chip_Margin - Chip_Width,
         Y       => Toolbar_Input_Y (Line_Height),
         Width   => Chip_Width,
         Height  => Toolbar_Input_Height (Line_Height));
   end Filter_Scope_Chip_Region_Of;

   function Filter_Input_Field_Width
     (Toolbar     : Toolbar_Layout;
      Line_Height : Positive := 20)
      return Natural
   is
      Chip : constant Scope_Chip_Region := Filter_Scope_Chip_Region_Of (Toolbar, Line_Height);
      Both_Margins : constant Natural := Saturating_Multiply (Scope_Chip_Margin, 2);
   begin
      if not Chip.Visible then
         return (if Toolbar.Right_Width > Both_Margins then Toolbar.Right_Width - Both_Margins else 0);
      end if;

      declare
         Filter_X : constant Natural := Saturating_Add (Toolbar.Right_X, Scope_Chip_Margin);
         Field_End : constant Natural :=
           (if Chip.X > Scope_Chip_Margin then Chip.X - Scope_Chip_Margin else 0);
      begin
         return (if Field_End > Filter_X then Field_End - Filter_X else 0);
      end;
   end Filter_Input_Field_Width;

   function Calculate_Toolbar_Layout
     (Width : Natural)
      return Toolbar_Layout
   is
      Preferred_Left : constant Natural := Saturating_Multiply (Toolbar_Button_Width, Toolbar_Button_Count);
      Side           : constant Natural := Width / 5;
      Left           : constant Natural := (if Width >= Preferred_Left then Preferred_Left else 0);
      Right          : constant Natural := Natural'Min (Side, Width - Left);
   begin
      return
        (Left_X       => 0,
         Left_Width   => Left,
         Middle_X     => Left,
         Middle_Width => Width - Left - Right,
         Right_X      => Width - Right,
         Right_Width  => Right);
   end Calculate_Toolbar_Layout;

   function Toolbar_Input_Height
     (Line_Height : Positive := 20)
      return Natural
   is
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Wanted_H  : constant Natural :=
        Saturating_Add (Line_Height, Input_Field_Padding);
   begin
      return Natural'Min (Toolbar_H, Wanted_H);
   end Toolbar_Input_Height;

   function Toolbar_Input_Y
     (Line_Height : Positive := 20)
      return Natural
   is
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Input_H   : constant Natural := Toolbar_Input_Height (Line_Height);
   begin
      if Toolbar_H > Input_H then
         return (Toolbar_H - Input_H) / 2;
      end if;

      return 0;
   end Toolbar_Input_Y;

   function Toolbar_Left_Button_X
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural
   is
      Clamped_Index : constant Natural := Natural'Min (Button_Index, Toolbar_Button_Count);
   begin
      if Toolbar.Left_Width >= Saturating_Multiply (Toolbar_Button_Width, Toolbar_Button_Count) then
         return Saturating_Add (Toolbar.Left_X, Saturating_Multiply (Toolbar_Button_Width, Clamped_Index));
      end if;

      return Saturating_Add (Toolbar.Left_X, Scaled_Down (Toolbar.Left_Width, Clamped_Index, Toolbar_Button_Count));
   end Toolbar_Left_Button_X;

   function Toolbar_Left_Button_Width
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural
   is
      Button_X : constant Natural := Toolbar_Left_Button_X (Toolbar, Button_Index);
      Next_X   : constant Natural := Toolbar_Left_Button_X (Toolbar, Button_Index + 1);
   begin
      if Button_Index >= Toolbar_Button_Count or else Next_X <= Button_X then
         return 0;
      end if;

      return Next_X - Button_X;
   end Toolbar_Left_Button_Width;

   function Calculate_Bottom_Bar_Layout
     (Width               : Natural;
      Small_Label_Width   : Natural;
      Large_Label_Width   : Natural;
      Details_Label_Width : Natural;
      Sort_Label_Width    : Natural;
      Info_Label_Width    : Natural;
      Line_Height         : Positive := 20)
      return Bottom_Bar_Layout
   is
      Button_Padding : constant Natural := Saturating_Multiply (Bottom_Bar_Padding, 3);
      Minimum_Button : constant Natural := Saturating_Multiply (Line_Height, 2);
      Small_Needed   : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Small_Label_Width, Button_Padding));
      Large_Needed   : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Large_Label_Width, Button_Padding));
      Details_Needed : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Details_Label_Width, Button_Padding));
      Sort_Needed    : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Sort_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Info_Needed    : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Info_Label_Width, Button_Padding));
      Preferred_View : constant Natural :=
        Saturating_Add (Small_Needed, Saturating_Add (Large_Needed, Details_Needed));
      Preferred_Sort : constant Natural := Sort_Needed;
      Toggle_Wanted  : constant Natural := Info_Needed;
      Content_X      : constant Natural := (if Width > Saturating_Multiply (Bottom_Bar_Padding, 2)
                                            then Bottom_Bar_Padding * 2 else 0);
      Content_W      : constant Natural :=
        (if Width > Saturating_Multiply (Content_X, 2) then Width - Saturating_Multiply (Content_X, 2)
         else Width);
      View_W         : constant Natural := Natural'Min (Content_W, Preferred_View);
      After_View     : constant Natural := Content_W - View_W;
      Sort_W         : constant Natural := (if After_View >= Preferred_Sort then Preferred_Sort else 0);
      Remaining      : constant Natural := After_View - Sort_W;
      Toggle_W       : constant Natural := Natural'Min (Remaining, Toggle_Wanted);
      Info_W         : constant Natural := Remaining - Toggle_W;
      Small_W        : constant Natural := Natural'Min (Small_Needed, View_W);
      Large_W        : constant Natural := Natural'Min (Large_Needed, View_W - Small_W);
      Details_W      : constant Natural := View_W - Small_W - Large_W;
      Large_X        : constant Natural := Content_X + Small_W;
      Details_X      : constant Natural := Content_X + Small_W + Large_W;
      Sort_X         : constant Natural := Content_X + View_W;
      Info_X         : constant Natural := Content_X + View_W + Sort_W;
      Toggle_X       : constant Natural := Content_X + View_W + Sort_W + Info_W;
   begin
      return
        (View_Mode_X          => Content_X,
         View_Mode_Width      => View_W,
         Small_Button_X       => Content_X,
         Small_Button_Width   => Small_W,
         Large_Button_X       => Large_X,
         Large_Button_Width   => Large_W,
         Details_Button_X     => Details_X,
         Details_Button_Width => Details_W,
         Sort_Button_X        => Sort_X,
         Sort_Button_Width    => Sort_W,
         Info_X               => Info_X,
         Info_Width           => Info_W,
         Info_Pane_X          => Toggle_X,
         Info_Pane_Width      => Toggle_W);
   end Calculate_Bottom_Bar_Layout;

   function Calculate_Settings_Entry_Button_Layout
     (Pane_X             : Natural;
      Pane_Width         : Natural;
      Add_Label_Width    : Natural;
      Remove_Label_Width : Natural)
      return Settings_Entry_Button_Layout
   is
      Edge_Padding   : constant Natural := Settings_Pane_Padding;
      Button_Gap     : constant Natural := 4;
      Minimum_Button : constant Natural := 34;
      Add_Wanted     : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Add_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Remove_Wanted  : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Remove_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Available      : constant Natural :=
        (if Pane_Width > Saturating_Multiply (Edge_Padding, 2)
         then Pane_Width - Saturating_Multiply (Edge_Padding, 2)
         else Pane_Width);
      Desired_Total  : constant Natural := Saturating_Add (Add_Wanted, Saturating_Add (Button_Gap, Remove_Wanted));
      Usable_Total   : constant Natural := Natural'Min (Available, Desired_Total);
      Add_W          : Natural := 0;
      Remove_W       : Natural := 0;
      Gap_W          : Natural := 0;
      Total_W        : Natural := 0;
      Total_X        : Natural := Pane_X;
      Remove_X       : Natural := Pane_X;
   begin
      if Usable_Total = 0 then
         return (others => <>);
      elsif Usable_Total <= Button_Gap then
         Add_W := Usable_Total;
      elsif Desired_Total <= Available then
         Add_W := Add_Wanted;
         Remove_W := Remove_Wanted;
         Gap_W := Button_Gap;
      else
         Gap_W := Button_Gap;
         Add_W := Natural'Min (Add_Wanted, (Usable_Total - Gap_W) / 2);
         Remove_W := Usable_Total - Gap_W - Add_W;
      end if;

      Total_W := Saturating_Add (Add_W, Saturating_Add (Gap_W, Remove_W));
      if Pane_Width > Saturating_Add (Total_W, Edge_Padding) then
         Total_X := Saturating_Add (Pane_X, Pane_Width - Total_W - Edge_Padding);
      end if;

      Remove_X := Saturating_Add (Total_X, Saturating_Add (Add_W, Gap_W));

      return
        (Add_Button_X        => Total_X,
         Add_Button_Width    => Add_W,
         Remove_Button_X     => Remove_X,
         Remove_Button_Width => Remove_W,
         Total_X             => Total_X,
         Total_Width         => Total_W);
   end Calculate_Settings_Entry_Button_Layout;

   function Calculate_Settings_Action_Button_Layout
     (Text_X     : Natural;
      Text_Width : Natural)
      return Settings_Action_Button_Layout
   is
      Gap      : constant Natural := 4;
      First_W  : constant Natural := (if Text_Width > Gap then (Text_Width - Gap) / 2 else 0);
      Offset   : constant Natural := Saturating_Add (First_W, Gap);
      Second_W : constant Natural := (if Text_Width > Offset then Text_Width - Offset else 0);
      Second_X : constant Natural := Saturating_Add (Text_X, Offset);
      Total_W  : constant Natural := Saturating_Add (Offset, Second_W);
   begin
      return
        (First_Button_X      => Text_X,
         First_Button_Width  => First_W,
         Second_Button_X     => Second_X,
         Second_Button_Width => Second_W,
         Total_X             => Text_X,
         Total_Width         => Total_W);
   end Calculate_Settings_Action_Button_Layout;

   function Calculate_Settings_Pane_Layout
     (Width          : Natural;
      Height         : Natural;
      Toolbar_Height : Natural;
      Line_Height    : Positive := 20)
      return Settings_Pane_Layout
   is
      Wanted_W : constant Natural := Natural'Max (440, Scaled_Down (Width, 4, 5));
      Pane_W : constant Natural := Natural'Min (Width, Wanted_W);
      Content_H : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Line_Height, 22),
           Saturating_Multiply (Settings_Row_Gap, 21));
      Wanted_H : constant Natural :=
        Natural'Max
          (Saturating_Add (Content_H, Saturating_Multiply (Settings_Pane_Padding, 2)),
           Height / 3);
      Top_Margin : constant Natural :=
        Natural'Max (Saturating_Add (Toolbar_Height, 8), Height / 6);
      Available_H : constant Natural :=
        (if Height > Top_Margin then Height - Top_Margin else 0);
      Pane_H : constant Natural := Natural'Min (Wanted_H, Available_H);
      Pane_X : constant Natural := (if Width > Pane_W then (Width - Pane_W) / 2 else 0);
      Pane_Y : constant Natural :=
        (if Available_H > 0 then Top_Margin else Toolbar_Height);
      Text_X : constant Natural := Saturating_Add (Pane_X, Settings_Pane_Padding);
      Text_Y : constant Natural := Saturating_Add (Pane_Y, Settings_Pane_Padding);
      Text_W : constant Natural :=
        (if Pane_W > Saturating_Multiply (Settings_Pane_Padding, 2)
         then Pane_W - Saturating_Multiply (Settings_Pane_Padding, 2)
         else 0);
   begin
      return
        (X          => Pane_X,
         Y          => Pane_Y,
         Width      => Pane_W,
         Height     => Pane_H,
         Text_X     => Text_X,
         Text_Y     => Text_Y,
         Text_Width => Text_W);
   end Calculate_Settings_Pane_Layout;

end Guikit.Layout;
