with Files.Localization;

with Files.Gui.Layout;
use Files.Gui.Layout;

package body Files.UI is

   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Files.Gui.Layout.Bottom_Bar_Layout
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);

      function Sort_Label_Needed (Key : String) return Natural is
      begin
         return
           Label_Pixel_Width
             (Files.Localization.Text (Key)
              & " "
              & Files.Localization.Text ("sort.direction.ascending"),
              Cell_W);
      end Sort_Label_Needed;

      Sort_Label_W : constant Natural :=
        Natural'Max
          (Sort_Label_Needed ("command.sort.name"),
           Natural'Max
             (Sort_Label_Needed ("command.sort.size"),
              Natural'Max
                (Sort_Label_Needed ("command.sort.type"),
                 Natural'Max
                   (Sort_Label_Needed ("command.sort.created"),
                    Sort_Label_Needed ("command.sort.changed")))));
   begin
      return
        Files.Gui.Layout.Calculate_Bottom_Bar_Layout
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

   function Calculate_Settings_Entry_Button_Layout
     (Pane_X      : Natural;
      Pane_Width  : Natural;
      Line_Height : Positive := 20)
      return Files.Gui.Layout.Settings_Entry_Button_Layout
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);
   begin
      return
        Files.Gui.Layout.Calculate_Settings_Entry_Button_Layout
          (Pane_X             => Pane_X,
           Pane_Width         => Pane_Width,
           Add_Label_Width    =>
             Label_Pixel_Width (Files.Localization.Text ("settings.add"), Cell_W),
           Remove_Label_Width =>
             Label_Pixel_Width (Files.Localization.Text ("settings.remove"), Cell_W));
   end Calculate_Settings_Entry_Button_Layout;

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

      for Button_Index in 0 .. 6 loop
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
                  return Files.Commands.Navigate_Parent_Command;
               when 5 =>
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
