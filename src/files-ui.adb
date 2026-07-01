with Files.Localization;
with Files.UTF8;

package body Files.UI is

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
      return Saturating_Multiply (Files.UTF8.Display_Units (Text), Cell_W);
   end Label_Pixel_Width;

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
      if Button_Index >= 6 or else Next_X <= Button_X then
         return 0;
      end if;

      return Next_X - Button_X;
   end Toolbar_Left_Button_Width;

   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Bottom_Bar_Layout
   is
      Cell_W         : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
      Button_Padding : constant Natural := Saturating_Multiply (Bottom_Bar_Padding, 3);
      Minimum_Button : constant Natural := Saturating_Multiply (Line_Height, 2);
      Small_Needed   : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("command.view.small.short"), Cell_W),
              Button_Padding));
      Large_Needed   : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("command.view.large.short"), Cell_W),
              Button_Padding));
      Details_Needed : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("command.view.details.short"), Cell_W),
              Button_Padding));

      function Sort_Label_Needed (Key : String) return Natural is
      begin
         return
           Label_Pixel_Width
             (Files.Localization.Text (Key)
              & " "
              & Files.Localization.Text ("sort.direction.ascending"),
              Cell_W);
      end Sort_Label_Needed;

      Sort_Label_W  : constant Natural :=
        Natural'Max
          (Sort_Label_Needed ("command.sort.name"),
           Natural'Max
             (Sort_Label_Needed ("command.sort.size"),
              Natural'Max
                (Sort_Label_Needed ("command.sort.type"),
                 Natural'Max
                   (Sort_Label_Needed ("command.sort.created"),
                    Sort_Label_Needed ("command.sort.changed")))));
      Sort_Needed    : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Sort_Label_W,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Info_Needed    : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("command.info.toggle.short"), Cell_W),
              Button_Padding));
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
     (Pane_X      : Natural;
      Pane_Width  : Natural;
      Line_Height : Positive := 20)
      return Settings_Entry_Button_Layout
   is
      Cell_W         : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
      Edge_Padding   : constant Natural := Settings_Pane_Padding;
      Button_Gap     : constant Natural := 4;
      Minimum_Button : constant Natural := 34;
      Add_Wanted     : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("settings.add"), Cell_W),
              Saturating_Multiply (Input_Field_Padding, 2)));
      Remove_Wanted  : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Label_Pixel_Width (Files.Localization.Text ("settings.remove"), Cell_W),
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

   function Toolbar_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Toolbar  : constant Toolbar_Layout := Calculate_Toolbar_Layout (Width);
      Input_Y  : constant Natural := Toolbar_Input_Y (Line_Height);
      Input_H  : constant Natural := Toolbar_Input_Height (Line_Height);
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
   begin
      if Width = 0 or else Y >= Toolbar_H then
         return Files.Commands.No_Command;
      elsif Within_Rect (X, Y, Toolbar.Middle_X, Input_Y, Toolbar.Middle_Width, Input_H) then
         return Files.Commands.Focus_Path_Input_Command;
      elsif Within_Rect (X, Y, Toolbar.Right_X, Input_Y, Toolbar.Right_Width, Input_H) then
         return Files.Commands.Focus_Filter_Input_Command;
      elsif not Within (X, Toolbar.Left_X, Toolbar.Left_Width) then
         return Files.Commands.No_Command;
      end if;

      for Button_Index in 0 .. 5 loop
         if Within_Rect
              (X,
               Y,
               Toolbar_Left_Button_X (Toolbar, Button_Index),
               Input_Y,
               Toolbar_Left_Button_Width (Toolbar, Button_Index),
               Input_H)
         then
            case Button_Index is
               when 0 =>
                  return Files.Commands.Select_Drive_Command;
               when 1 =>
                  return Files.Commands.Navigate_Home_Command;
               when 2 =>
                  return Files.Commands.Navigate_Back_Command;
               when 3 =>
                  return Files.Commands.Navigate_Forward_Command;
               when 4 =>
                  return Files.Commands.Create_File_Command;
               when others =>
                  return Files.Commands.Delete_Selected_Items_Command;
            end case;
         end if;
      end loop;

      return Files.Commands.No_Command;
   end Toolbar_Command_At;

   function Bottom_Bar_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom   : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Line_Height);
      Bottom_H : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Content_Y : constant Natural := Saturating_Add (Bottom_Y, Bottom_Bar_Padding);
   begin
      if Width = 0
        or else Height = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Line_Height)
      then
         return Files.Commands.No_Command;
      elsif Within (X, Bottom.Small_Button_X, Bottom.Small_Button_Width) then
         return Files.Commands.Select_Small_Icons_Command;
      elsif Within (X, Bottom.Large_Button_X, Bottom.Large_Button_Width) then
         return Files.Commands.Select_Large_Icons_Command;
      elsif Within (X, Bottom.Details_Button_X, Bottom.Details_Button_Width) then
         return Files.Commands.Select_Details_Command;
      elsif Within (X, Bottom.Sort_Button_X, Bottom.Sort_Button_Width) then
         return Files.Commands.Toggle_Sort_Menu_Command;
      elsif Within (X, Bottom.Info_X, Bottom.Info_Width) then
         --  The status area doubles as the hidden-count control: clicking it
         --  toggles Show_Hidden_Files through the settings-path command routing.
         return Files.Commands.Toggle_Hidden_Files_Command;
      elsif Within (X, Bottom.Info_Pane_X, Bottom.Info_Pane_Width) then
         return Files.Commands.Toggle_Info_Pane_Command;
      else
         return Files.Commands.No_Command;
      end if;
   end Bottom_Bar_Command_At;

   function Bottom_Bar_Sort_Menu_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom       : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Line_Height);
      Row_Count    : constant Natural := 5;
      Row_H        : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Menu_H       : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Row_H, Row_Count), Saturating_Multiply (Sort_Menu_Padding, 2));
      Bottom_H     : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y     : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Menu_Y       : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
      Rows_Y       : constant Natural := Saturating_Add (Menu_Y, Sort_Menu_Padding);
      Relative_Row : Natural := 0;
   begin
      if Bottom.Sort_Button_Width = 0
        or else X < Bottom.Sort_Button_X
        or else X >= Saturating_Add (Bottom.Sort_Button_X, Bottom.Sort_Button_Width)
        or else Y < Rows_Y
        or else Y >= Saturating_Add (Rows_Y, Saturating_Multiply (Row_H, Row_Count))
        or else Row_H = 0
      then
         return Files.Commands.No_Command;
      end if;

      Relative_Row := (Y - Rows_Y) / Row_H;
      case Relative_Row is
         when 0 =>
            return Files.Commands.Sort_By_Name_Command;
         when 1 =>
            return Files.Commands.Sort_By_Size_Command;
         when 2 =>
            return Files.Commands.Sort_By_Type_Command;
         when 3 =>
            return Files.Commands.Sort_By_Created_Command;
         when 4 =>
            return Files.Commands.Sort_By_Changed_Command;
         when others =>
            return Files.Commands.No_Command;
      end case;
   end Bottom_Bar_Sort_Menu_Command_At;

   function Bottom_Bar_Sort_Menu_Contains
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Boolean
   is
      Bottom    : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Line_Height);
      Row_Count : constant Natural := 5;
      Row_H     : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Menu_H    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Row_H, Row_Count), Saturating_Multiply (Sort_Menu_Padding, 2));
      Bottom_H  : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y  : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
   begin
      return Bottom.Sort_Button_Width > 0
        and then X >= Bottom.Sort_Button_X
        and then X < Saturating_Add (Bottom.Sort_Button_X, Bottom.Sort_Button_Width)
        and then Y >= Menu_Y
        and then Y < Bottom_Y;
   end Bottom_Bar_Sort_Menu_Contains;

end Files.UI;
