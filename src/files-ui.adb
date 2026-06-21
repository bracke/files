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

   function Calculate_Toolbar_Layout
     (Width : Natural)
      return Toolbar_Layout
   is
      Side : constant Natural := Width / 5;
   begin
      return
        (Left_X       => 0,
         Left_Width   => Side,
         Middle_X     => Side,
         Middle_Width => Width - (Side * 2),
         Right_X      => Width - Side,
         Right_Width  => Side);
   end Calculate_Toolbar_Layout;

   function Toolbar_Left_Button_X
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural
   is
      Clamped_Index : constant Natural := Natural'Min (Button_Index, 6);
   begin
      return Saturating_Add (Toolbar.Left_X, Scaled_Down (Toolbar.Left_Width, Clamped_Index, 6));
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
      Button_W       : constant Natural := Saturating_Multiply (Line_Height, 4);
      Preferred_View : constant Natural := Saturating_Multiply (Button_W, 3);
      View_W         : constant Natural := Natural'Min (Width, Preferred_View);
      Remaining      : constant Natural := Width - View_W;
      Toggle_W       : constant Natural := Natural'Min (Remaining, Button_W);
      Info_W         : constant Natural := Remaining - Toggle_W;
      Small_W        : constant Natural := Natural'Min (Button_W, View_W);
      Large_W        : constant Natural := Natural'Min (Button_W, View_W - Small_W);
      Details_W      : constant Natural := View_W - Small_W - Large_W;
      Large_X        : constant Natural := Small_W;
      Details_X      : constant Natural := Small_W + Large_W;
      Info_X         : constant Natural := View_W;
      Toggle_X       : constant Natural := View_W + Info_W;
   begin
      return
        (View_Mode_X          => 0,
         View_Mode_Width      => View_W,
         Small_Button_X       => 0,
         Small_Button_Width   => Small_W,
         Large_Button_X       => Large_X,
         Large_Button_Width   => Large_W,
         Details_Button_X     => Details_X,
         Details_Button_Width => Details_W,
         Info_X               => Info_X,
         Info_Width           => Info_W,
         Info_Pane_X          => Toggle_X,
         Info_Pane_Width      => Toggle_W);
   end Calculate_Bottom_Bar_Layout;

   function Toolbar_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Toolbar  : constant Toolbar_Layout := Calculate_Toolbar_Layout (Width);
      Input_Y  : constant Natural := Line_Height / 2;
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
   begin
      if Width = 0 or else Y >= Toolbar_H then
         return Files.Commands.No_Command;
      elsif Within_Rect (X, Y, Toolbar.Middle_X, Input_Y, Toolbar.Middle_Width, Line_Height) then
         return Files.Commands.Focus_Path_Input_Command;
      elsif Within_Rect (X, Y, Toolbar.Right_X, Input_Y, Toolbar.Right_Width, Line_Height) then
         return Files.Commands.Focus_Filter_Input_Command;
      elsif not Within (X, Toolbar.Left_X, Toolbar.Left_Width) then
         return Files.Commands.No_Command;
      end if;

      for Button_Index in 0 .. 5 loop
         if Within
              (X,
               Toolbar_Left_Button_X (Toolbar, Button_Index),
               Toolbar_Left_Button_Width (Toolbar, Button_Index))
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
      Bottom_Y : constant Natural := (if Height > Line_Height then Height - Line_Height else 0);
   begin
      if Width = 0 or else Height = 0 or else Y < Bottom_Y or else Y >= Height then
         return Files.Commands.No_Command;
      elsif Within (X, Bottom.Small_Button_X, Bottom.Small_Button_Width) then
         return Files.Commands.Select_Small_Icons_Command;
      elsif Within (X, Bottom.Large_Button_X, Bottom.Large_Button_Width) then
         return Files.Commands.Select_Large_Icons_Command;
      elsif Within (X, Bottom.Details_Button_X, Bottom.Details_Button_Width) then
         return Files.Commands.Select_Details_Command;
      elsif Within (X, Bottom.Info_Pane_X, Bottom.Info_Pane_Width) then
         return Files.Commands.Toggle_Info_Pane_Command;
      else
         return Files.Commands.No_Command;
      end if;
   end Bottom_Bar_Command_At;

end Files.UI;
