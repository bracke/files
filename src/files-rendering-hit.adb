with Files.UI;
with Guikit.Segmented;

package body Files.Rendering.Hit is

   use Guikit.Layout;
   use type Files.Types.View_Mode;

   function Conflict_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Conflict_Hit_Region is
   begin
      for Index in reverse 1 .. Natural (Frame.Conflict_Hits.Length) loop
         declare
            Region : constant Conflict_Hit_Region :=
              Frame.Conflict_Hits.Element (Positive (Index));
         begin
            if Contains_Rectangle_Point
              (Region.X, Region.Y, Region.Width, Region.Height, X, Y)
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Conflict_Hit_At;

   function Permission_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Permission_Hit_Region is
   begin
      for Index in 1 .. Natural (Frame.Permission_Hits.Length) loop
         declare
            Region : constant Permission_Hit_Region :=
              Frame.Permission_Hits.Element (Positive (Index));
         begin
            if Contains_Rectangle_Point
              (Region.X, Region.Y, Region.Width, Region.Height, X, Y)
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Permission_Hit_At;

   function Ownership_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Ownership_Hit_Region is
   begin
      for Index in 1 .. Natural (Frame.Ownership_Hits.Length) loop
         declare
            Region : constant Ownership_Hit_Region :=
              Frame.Ownership_Hits.Element (Positive (Index));
         begin
            if Contains_Rectangle_Point
              (Region.X, Region.Y, Region.Width, Region.Height, X, Y)
            then
               return Region;
            end if;
         end;
      end loop;

      return (others => <>);
   end Ownership_Hit_At;

   function Context_Menu_Row_At
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural is
      First_Row_Y : constant Natural := Saturating_Add (Menu.Y, Menu.Padding);
   begin
      if not Menu.Visible
        or else X < Menu.X
        or else X - Menu.X >= Menu.Width
        or else Y < Menu.Y
        or else Y - Menu.Y >= Menu.Height
        or else Y < First_Row_Y
        or else Menu.Row_Height = 0
      then
         return 0;
      end if;

      --  Rows have variable heights (separators are shorter), so walk them in
      --  the column under X and return the command row containing Y. Separator
      --  rows are not selectable and resolve to no row.
      declare
         Second_Column : constant Boolean :=
           Menu.Column_Count > 1
           and then X - Menu.X >= Menu.Column_Width;
         First_Row : constant Positive :=
           (if Second_Column then Positive (Menu.Column_Break_Row + 1) else 1);
         Last_Row  : constant Natural :=
           (if Second_Column then Menu.Row_Count
            elsif Menu.Column_Count > 1 then Menu.Column_Break_Row
            else Menu.Row_Count);
         Row_Top : Natural := First_Row_Y;
      begin
         for Row in First_Row .. Last_Row loop
            declare
               Row_H : constant Natural :=
                 (if Menu.Row_Kinds (Row) = Separator_Row
                  then Menu.Separator_Height
                  else Menu.Row_Height);
            begin
               if Y >= Row_Top and then Y - Row_Top < Row_H then
                  if Menu.Row_Kinds (Row) = Separator_Row then
                     return 0;
                  else
                     return Row;
                  end if;
               end if;
               Row_Top := Saturating_Add (Row_Top, Row_H);
            end;
         end loop;
         return 0;
      end;
   end Context_Menu_Row_At;

   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural
      renames Guikit.Item_Grid.Item_At;

   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector
      renames Guikit.Item_Grid.Items_In_Rect;

   --  Map a detail column to the sort command a header click on it triggers.
   --  Columns that do not define a sort (the permissions column) return
   --  No_Command.
   function Header_Sort_Command
     (Column : Files.Types.Detail_Column)
      return Files.Commands.Command_Id is
   begin
      case Column is
         when Files.Types.Name_Column =>
            return Files.Commands.Sort_By_Name_Command;
         when Files.Types.Modified_Column =>
            return Files.Commands.Sort_By_Changed_Command;
         when Files.Types.Size_Column =>
            return Files.Commands.Sort_By_Size_Command;
         when Files.Types.Filetype_Column =>
            return Files.Commands.Sort_By_Type_Command;
         when Files.Types.Created_Column =>
            return Files.Commands.Sort_By_Created_Command;
         when Files.Types.Permissions_Column =>
            return Files.Commands.No_Command;
      end case;
   end Header_Sort_Command;

   function Details_Header_Cell_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Header_Cell
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);

      function Within (Column : Files.Types.Detail_Column) return Boolean is
      begin
         return Columns (Column).Visible
           and then Contains_Rectangle_Point
             (Columns (Column).X, Content_Y, Columns (Column).Width, Header_H, X, Y);
      end Within;
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else not Contains_Rectangle_Point (Content_X, Content_Y, Content_W, Header_H, X, Y)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Types.Detail_Column loop
         if Within (Column) then
            return
              (Present => True,
               Column  => Column,
               Command => Header_Sort_Command (Column));
         end if;
      end loop;

      return (Present => False, others => <>);
   end Details_Header_Cell_At;

   function Details_Header_Drop_Index
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Natural
   is
      use type Files.Types.Detail_Column;
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
        or else X < Content_X
        or else X >= Saturating_Add (Content_X, Content_W)
      then
         return 0;
      end if;

      --  The dragged column takes the slot of the first visible optional column
      --  whose right edge is beyond the pointer (i.e. the one the pointer is
      --  over, or the first to its right). A pointer past all of them targets
      --  the final slot.
      for Slot in Snapshot.Detail_Column_Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column :=
              Snapshot.Detail_Column_Order (Slot);
         begin
            if Column /= Files.Types.Name_Column
              and then Columns (Column).Visible
              and then X < Saturating_Add (Columns (Column).X, Columns (Column).Width)
            then
               return Slot;
            end if;
         end;
      end loop;

      return Files.Types.Detail_Column_Count;
   end Details_Header_Drop_Index;

   --  Half-width, in pixels, of the invisible hot zone straddling a header
   --  column separator. A press within this band of a separator's edge begins a
   --  resize; it is wide enough to be grabbable yet narrow enough that clicks
   --  well inside a header cell still resolve to a sort.
   Detail_Separator_Hot_Zone : constant := 5;

   function Details_Header_Separator_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Column_Separator
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);
      Low       : constant Natural :=
        (if X > Detail_Separator_Hot_Zone then X - Detail_Separator_Hot_Zone else 0);
      High      : constant Natural := Saturating_Add (X, Detail_Separator_Hot_Zone);
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Types.Optional_Detail_Column loop
         if Columns (Column).Visible
           and then Columns (Column).X >= Low
           and then Columns (Column).X <= High
         then
            return
              (Present  => True,
               Column   => Column,
               Origin_X => Columns (Column).X,
               Width    => Columns (Column).Width);
         end if;
      end loop;

      return (Present => False, others => <>);
   end Details_Header_Separator_At;

   function Root_Path_At
     (Rows : Root_Path_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point
              (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Root_Index;
         end if;
      end loop;

      return 0;
   end Root_Path_At;

   function Breadcrumb_At
     (Rows : Breadcrumb_Segment_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Row.Clickable
           and then Row.Segment_Index /= 0
           and then Contains_Rectangle_Point (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Segment_Index;
         end if;
      end loop;
      return 0;
   end Breadcrumb_At;

   function Tree_Row_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point (Row.X, Row.Y, Row.Width, Row.Height, X, Y) then
            return Row.Node_Index;
         end if;
      end loop;
      return 0;
   end Tree_Row_At;

   function Tree_Triangle_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Row.Has_Children
           and then Row.Triangle_W > 0
           and then Contains_Rectangle_Point
                      (Row.Triangle_X, Row.Triangle_Y, Row.Triangle_W, Row.Triangle_H, X, Y)
         then
            return Row.Node_Index;
         end if;
      end loop;
      return 0;
   end Tree_Triangle_At;

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
     (X                : Natural;
      Y                : Natural;
      Width            : Natural;
      Height           : Natural;
      Sort_Field       : Files.Types.Sort_Field;
      Free_Label_Width : Natural := 0;
      Line_Height      : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom   : constant Bottom_Bar_Layout := Files.UI.Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Bottom_H : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      --  The hidden-files toggle occupies only the counts area; when a free-space
      --  field is split off, the toggle stops at the divider and the free field
      --  is its own, non-interactive region.
      Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width : Natural;
   begin
      Files.UI.Split_Status_Region
        (Bottom.Info_X, Bottom.Info_Width, Free_Label_Width,
         Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width, Line_Height);
      if Width = 0
        or else Height = 0
        or else X >= Width
        or else Y < Bottom_Y
        or else Y >= Height
      then
         return Files.Commands.No_Command;
      elsif Within (X, Bottom.View_Mode_X, Bottom.View_Mode_Width) then
         case Guikit.Segmented.Cell_At
                (Files.UI.View_Mode_Segments, Bottom.View_Mode_X, Bottom.View_Mode_Width, Line_Height, X)
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
      elsif Free_Field_Width > 0
        and then Within
          (X, Divider_X,
           (if Saturating_Add (Bottom.Info_X, Bottom.Info_Width) > Divider_X
            then Saturating_Add (Bottom.Info_X, Bottom.Info_Width) - Divider_X else 0))
      then
         --  The free-space field (right of the divider) toggles between showing
         --  free and used disk space.
         return Files.Commands.Toggle_Free_Space_Display_Command;
      else
         return Files.Commands.No_Command;
      end if;
   end Bottom_Bar_Command_At;

   function Bottom_Bar_Sort_Menu_Command_At
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
   is
      Bottom       : constant Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
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
      Menu_W       : constant Natural :=
        Files.UI.Sort_Menu_Visible_Width (Width, Sort_Field, Line_Height);
      Relative_Row : Natural := 0;
   begin
      if Bottom.Sort_Button_Width = 0
        or else X >= Width
        or else Y >= Height
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
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive := 20)
      return Boolean
   is
      Bottom    : constant Bottom_Bar_Layout := Files.UI.Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Row_Count : constant Natural := 5;
      Row_H     : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Menu_H    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Row_H, Row_Count), Saturating_Multiply (Sort_Menu_Padding, 2));
      Bottom_H  : constant Natural := Saturating_Add (Line_Height, Saturating_Multiply (Bottom_Bar_Padding, 2));
      Bottom_Y  : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);
      Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
      Menu_W    : constant Natural :=
        Files.UI.Sort_Menu_Visible_Width (Width, Sort_Field, Line_Height);
      Menu_Bottom : constant Natural :=
        Natural'Min (Height, Saturating_Add (Menu_Y, Menu_H));
   begin
      return Bottom.Sort_Button_Width > 0
        and then X < Width
        and then Y < Height
        and then X >= Bottom.Sort_Button_X
        and then X < Saturating_Add (Bottom.Sort_Button_X, Menu_W)
        and then Y >= Menu_Y
        and then Y < Menu_Bottom;
   end Bottom_Bar_Sort_Menu_Contains;

end Files.Rendering.Hit;
