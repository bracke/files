with Files.Localization;

with Ada.Strings.Unbounded;

with Guikit.Layout;
use Guikit.Layout;

package body Files.UI is

   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Sort_Field  : Files.Model.Sort_Field;
      Line_Height : Positive := 20)
      return Guikit.Layout.Bottom_Bar_Layout
   is
      Cell_W : constant Natural := Caret_Advance_Width (Line_Height);

      function Sort_Field_Key return String is
      begin
         case Sort_Field is
            when Files.Model.Sort_Name    => return "command.sort.name";
            when Files.Model.Sort_Size    => return "command.sort.size";
            when Files.Model.Sort_Type    => return "command.sort.type";
            when Files.Model.Sort_Created => return "command.sort.created";
            when Files.Model.Sort_Changed => return "command.sort.changed";
         end case;
      end Sort_Field_Key;

      --  Size the sort button to the active field's label only (plus the
      --  direction indicator), not the widest field, so it is never wider than
      --  the text it shows.
      Sort_Label_W : constant Natural :=
        Label_Pixel_Width
          (Files.Localization.Text (Sort_Field_Key)
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

   procedure Split_Status_Region
     (Info_X           : Natural;
      Info_Width       : Natural;
      Free_Label_Width : Natural;
      Toggle_Width     : out Natural;
      Divider_X        : out Natural;
      Free_Field_X     : out Natural;
      Free_Field_Width : out Natural)
   is
      Pad     : constant Natural := 4;
      Div_Gap : constant Natural := 8;
      --  Only split when there is a free label and room for it plus the divider
      --  gaps and some counts (matching the renderer's threshold).
      Show    : constant Boolean :=
        Free_Label_Width > 0
        and then Info_Width > Saturating_Add (Free_Label_Width, 2 * Div_Gap + 3 * Pad);
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

   function Bottom_Bar_Command_At
     (X                : Natural;
      Y                : Natural;
      Width            : Natural;
      Height           : Natural;
      Sort_Field       : Files.Model.Sort_Field;
      Free_Label_Width : Natural := 0;
      Line_Height      : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom   : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Bottom_H : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Content_Y : constant Natural := Saturating_Add (Bottom_Y, Bottom_Bar_Padding);
      --  The hidden-files toggle occupies only the counts area; when a free-space
      --  field is split off, the toggle stops at the divider and the free field
      --  is its own, non-interactive region.
      Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width : Natural;
   begin
      Split_Status_Region
        (Bottom.Info_X, Bottom.Info_Width, Free_Label_Width,
         Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width);
      if Width = 0
        or else Height = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Line_Height)
      then
         return Files.Commands.No_Command;
      elsif Within (X, Bottom.View_Mode_X, Bottom.View_Mode_Width) then
         case Guikit.Segmented.Cell_At
                (View_Mode_Segments, Bottom.View_Mode_X, Bottom.View_Mode_Width, Line_Height, X)
         is
            when 1      => return Files.Commands.Select_Small_Icons_Command;
            when 2      => return Files.Commands.Select_Large_Icons_Command;
            when 3      => return Files.Commands.Select_Details_Command;
            when others => return Files.Commands.No_Command;
         end case;
      elsif Within (X, Bottom.Sort_Button_X, Bottom.Sort_Button_Width) then
         return Files.Commands.Toggle_Sort_Menu_Command;
      elsif Within (X, Bottom.Info_X, Toggle_Width) then
         --  The counts area doubles as the hidden-count control: clicking it
         --  toggles Show_Hidden_Files through the settings-path command routing.
         return Files.Commands.Toggle_Hidden_Files_Command;
      elsif Within (X, Bottom.Info_Pane_X, Bottom.Info_Pane_Width) then
         return Files.Commands.Toggle_Info_Pane_Command;
      else
         --  The free-space field (between the divider and the info-pane toggle)
         --  falls through here: it is its own field with no command.
         return Files.Commands.No_Command;
      end if;
   end Bottom_Bar_Command_At;

   function Bottom_Bar_Sort_Menu_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Model.Sort_Field;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom       : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Row_Count    : constant Natural := 5;
      Row_H        : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Menu_H       : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Row_H, Row_Count), Saturating_Multiply (Sort_Menu_Padding, 2));
      Bottom_H     : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y     : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Menu_Y       : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
      Rows_Y       : constant Natural := Saturating_Add (Menu_Y, Sort_Menu_Padding);
      --  The dropdown is as wide as the widest field, not the (snug) sort button.
      Menu_W       : constant Natural := Sort_Menu_Width (Line_Height);
      Relative_Row : Natural := 0;
   begin
      if Bottom.Sort_Button_Width = 0
        or else X < Bottom.Sort_Button_X
        or else X >= Saturating_Add (Bottom.Sort_Button_X, Menu_W)
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
      Sort_Field  : Files.Model.Sort_Field;
      Line_Height : Positive := 20)
      return Boolean
   is
      Bottom    : constant Bottom_Bar_Layout := Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Row_Count : constant Natural := 5;
      Row_H     : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Menu_H    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Row_H, Row_Count), Saturating_Multiply (Sort_Menu_Padding, 2));
      Bottom_H  : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y  : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
      Menu_W    : constant Natural := Sort_Menu_Width (Line_Height);
   begin
      return Bottom.Sort_Button_Width > 0
        and then X >= Bottom.Sort_Button_X
        and then X < Saturating_Add (Bottom.Sort_Button_X, Menu_W)
        and then Y >= Menu_Y
        and then Y < Bottom_Y;
   end Bottom_Bar_Sort_Menu_Contains;

end Files.UI;
