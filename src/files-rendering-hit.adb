with Files.Commands.Context_Menus;
with Files.Preference_Types;
with Ada.Containers.Vectors;
with Files.Rendering.Geometry;
with Guikit.Segmented;

package body Files.Rendering.Hit is

   use Files.Rendering.Geometry;
   use Guikit.Layout;
   use type Files.Preference_Types.View_Mode;
   use type Files.Commands.Context_Menus.Context_Menu_Row_Kind;

   --  The region a point is in. A frame records regions in drawing order,
   --  so the last one recorded there is the one drawn on top: the search runs
   --  from the end. A region with Present False when none holds the point.
   generic
      type Region is private;
      with package Region_Vectors is new Ada.Containers.Vectors (Positive, Region, <>);
      with function Contains (Item : Region; X, Y : Natural) return Boolean;
      None : Region;
   function Topmost_Hit_At (Regions : Region_Vectors.Vector; X, Y : Natural) return Region;

   function Topmost_Hit_At (Regions : Region_Vectors.Vector; X, Y : Natural) return Region is
   begin
      for Item of reverse Regions loop
         if Contains (Item, X, Y) then
            return Item;
         end if;
      end loop;
      return None;
   end Topmost_Hit_At;

   function Contains (Item : Dialog_Hit_Region; X, Y : Natural) return Boolean is
     (Contains_Rectangle_Point (Item.X, Item.Y, Item.Width, Item.Height, X, Y));
   function Contains (Item : Permission_Hit_Region; X, Y : Natural) return Boolean is
     (Contains_Rectangle_Point (Item.X, Item.Y, Item.Width, Item.Height, X, Y));
   function Contains (Item : Ownership_Hit_Region; X, Y : Natural) return Boolean is
     (Contains_Rectangle_Point (Item.X, Item.Y, Item.Width, Item.Height, X, Y));

   function Dialog_At is new Topmost_Hit_At
     (Dialog_Hit_Region, Dialog_Hit_Region_Vectors, Contains, (others => <>));
   function Permission_At is new Topmost_Hit_At
     (Permission_Hit_Region, Permission_Hit_Region_Vectors, Contains, (others => <>));
   function Ownership_At is new Topmost_Hit_At
     (Ownership_Hit_Region, Ownership_Hit_Region_Vectors, Contains, (others => <>));

   function Dialog_Hit_At (Frame : Frame_Commands; X, Y : Natural) return Dialog_Hit_Region is
     (Dialog_At (Frame.Dialog_Hits, X, Y));

   function Permission_Hit_At (Frame : Frame_Commands; X, Y : Natural) return Permission_Hit_Region is
     (Permission_At (Frame.Permission_Hits, X, Y));

   function Ownership_Hit_At (Frame : Frame_Commands; X, Y : Natural) return Ownership_Hit_Region is
     (Ownership_At (Frame.Ownership_Hits, X, Y));

   function Context_Menu_Contains
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Boolean is
     (Menu.Visible and then Contains_Rectangle_Point (Menu.X, Menu.Y, Menu.Width, Menu.Height, X, Y));

   function Context_Menu_Row_At
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      --  The declared surface bounds the rows: a clipped menu's latent rows
      --  below it are not drawn, so not clickable.
      if not Context_Menu_Contains (Menu, X, Y) or else Menu.Row_Height = 0 then
         return 0;
      end if;

      --  The rows where the renderer draws them (Context_Menu_Row_Left/Top/
      --  Width/Height); a separator is not selectable and resolves to none.
      for Row in 1 .. Menu.Row_Count loop
         if Contains_Rectangle_Point
           (Context_Menu_Row_Left (Menu, Row),
            Context_Menu_Row_Top (Menu, Row),
            Context_Menu_Row_Width (Menu, Row),
            Context_Menu_Row_Height (Menu, Row),
            X, Y)
         then
            return (if Menu.Rows (Row).Kind = Files.Commands.Context_Menus.Menu_Separator then 0 else Row);
         end if;
      end loop;
      return 0;
   end Context_Menu_Row_At;

   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural
      renames Guikit.Item_Grid.Item_At;

   function Item_At
     (Items : Placed_Item_Layout;
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

   function Items_In_Rect
     (Items  : Placed_Item_Layout;
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
     (Column : Files.Preference_Types.Detail_Column)
      return Files.Commands.Command_Id is
     (if Detail_Column_Sorts (Column).Sortable
      then Files.Commands.Sort_Command (Detail_Column_Sorts (Column).Field)
      else Files.Commands.No_Command);

   function On_Main_View
     (Layout : Layout_Metrics;
      X      : Natural;
      Y      : Natural)
      return Boolean is
     (Contains_Rectangle_Point (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, X, Y));

   function Details_Header_Cell_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive)
      return Detail_Header_Cell
   is
      Header    : constant Details_Header_Layout :=
        Details_Header_Geometry (Snapshot, Layout, Line_Height);
      Content_X : constant Natural := Header.Content.X;
      Content_Y : constant Natural := Header.Content.Y;
      Content_W : constant Natural := Header.Content.Width;
      Header_H  : constant Natural := Header.Height;
      Columns   : Detail_Column_Geometry_Array renames Header.Columns;

      function Within (Column : Files.Preference_Types.Detail_Column) return Boolean is
      begin
         return Columns (Column).Visible
           and then Contains_Rectangle_Point
             (Columns (Column).X, Content_Y, Columns (Column).Width, Header_H, X, Y);
      end Within;
   begin
      if Snapshot.View_Mode /= Files.Preference_Types.Details
        or else Header_H = 0
        or else not Contains_Rectangle_Point (Content_X, Content_Y, Content_W, Header_H, X, Y)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Preference_Types.Detail_Column loop
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
      Line_Height : Positive)
      return Natural
   is
      use type Files.Preference_Types.Detail_Column;
      Header    : constant Details_Header_Layout :=
        Details_Header_Geometry (Snapshot, Layout, Line_Height);
      Content_X : constant Natural := Header.Content.X;
      Content_Y : constant Natural := Header.Content.Y;
      Content_W : constant Natural := Header.Content.Width;
      Header_H  : constant Natural := Header.Height;
      Columns   : Detail_Column_Geometry_Array renames Header.Columns;
   begin
      if Snapshot.View_Mode /= Files.Preference_Types.Details
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
            Column : constant Files.Preference_Types.Detail_Column :=
              Snapshot.Detail_Column_Order (Slot);
         begin
            if Column /= Files.Preference_Types.Name_Column
              and then Columns (Column).Visible
              and then X < Saturating_Add (Columns (Column).X, Columns (Column).Width)
            then
               return Slot;
            end if;
         end;
      end loop;

      return Files.Preference_Types.Detail_Column_Count;
   end Details_Header_Drop_Index;

   function Details_Header_Separator_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive)
      return Detail_Column_Separator
   is
      Header    : constant Details_Header_Layout :=
        Details_Header_Geometry (Snapshot, Layout, Line_Height);
      Content_Y : constant Natural := Header.Content.Y;
      Header_H  : constant Natural := Header.Height;
      Columns   : Detail_Column_Geometry_Array renames Header.Columns;
   begin
      if Snapshot.View_Mode /= Files.Preference_Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
      then
         return (Present => False, others => <>);
      end if;

      for Column in Files.Preference_Types.Optional_Detail_Column loop
         if Columns (Column).Visible
           and then On_Column_Separator (Columns (Column).X, X, Line_Height)
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
      Line_Height : Positive)
      return Files.Commands.Command_Id
   is
      Toolbar  : constant Toolbar_Layout := Calculate_Toolbar_Layout (Width, Line_Height);
      Input_Y  : constant Natural := Toolbar_Input_Y (Line_Height);
      Input_H  : constant Natural := Toolbar_Input_Height (Line_Height);
      Toolbar_H : constant Natural := Layouts.Toolbar_Height (Line_Height);
   begin
      --  Only the left section's buttons: the path and filter fields are
      --  focused by a click on their drawn boxes alone (Toolbar_Click, with
      --  the caret placed), never by the margins around them.
      if Width = 0 or else Y >= Toolbar_H then
         return Files.Commands.No_Command;
      elsif not Within (X, Toolbar.Left_X, Toolbar.Left_Width) then
         return Files.Commands.No_Command;
      end if;

      for Button_Index in Toolbar_Button_Index loop
         if Within_Rect
              (X,
               Y,
               Toolbar_Left_Button_X (Toolbar, Button_Index),
               Input_Y,
               Toolbar_Left_Button_Width (Toolbar, Button_Index),
               Input_H)
         then
            return Toolbar_Button_Commands (Button_Index);
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
      Line_Height      : Positive)
      return Files.Commands.Command_Id
   is
      Bottom   : constant Bottom_Bar_Layout := Layouts.Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Bottom_Y : constant Natural := Layouts.Bottom_Bar_Y (Height, Line_Height);
      --  The hidden-files toggle occupies only the counts area; when a free-space
      --  field is split off, the toggle stops at the divider and the free field
      --  is its own, non-interactive region.
      Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width, Free_Region_Width : Natural;
   begin
      Layouts.Split_Status_Region
        (Bottom.Info_X, Bottom.Info_Width, Free_Label_Width,
         Toggle_Width, Divider_X, Free_Field_X, Free_Field_Width, Free_Region_Width, Line_Height);
      if Width = 0
        or else Height = 0
        or else X >= Width
        or else Y < Bottom_Y
        or else Y >= Height
      then
         return Files.Commands.No_Command;
      elsif Within (X, Bottom.View_Mode_X, Bottom.View_Mode_Width) then
         declare
            Cell : constant Natural := Guikit.Segmented.Cell_At
              (Layouts.View_Mode_Segments, Bottom.View_Mode_X, Bottom.View_Mode_Width, Line_Height, X);
         begin
            for Mode in Files.Preference_Types.View_Mode loop
               if Cell = Layouts.View_Mode_Cell (Mode) then
                  return Layouts.View_Mode_Commands (Mode);
               end if;
            end loop;
            return Files.Commands.No_Command;
         end;
      elsif Within (X, Bottom.Sort_Button_X, Bottom.Sort_Button_Width) then
         return Files.Commands.Toggle_Sort_Menu_Command;
      elsif Within (X, Bottom.Info_X, Toggle_Width) then
         --  The counts area doubles as the hidden-count control: clicking it
         --  toggles Show_Hidden_Files through the settings-path command routing.
         return Files.Commands.Toggle_Hidden_Files_Command;
      elsif Within (X, Bottom.Info_Pane_X, Bottom.Info_Pane_Width) then
         return Files.Commands.Toggle_Info_Pane_Command;
      elsif Free_Field_Width > 0 and then Within (X, Divider_X, Free_Region_Width) then
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
      Line_Height : Positive)
      return Files.Commands.Command_Id
   is
      --  No sort button, no menu: its width is then 0.
      Menu   : constant Layouts.Menus.Sort_Menu_Layout :=
        Layouts.Menus.Calculate_Sort_Menu_Layout (Width, Height, Sort_Field, Line_Height);
      Row    : constant Natural := Layouts.Menus.Sort_Menu_Row_At (Menu, X, Y);
   begin
      if Row = 0 then
         return Files.Commands.No_Command;
      end if;
      return Files.Commands.Sort_Command (Layouts.Menus.Sort_Menu_Row_Field (Row));
   end Bottom_Bar_Sort_Menu_Command_At;

   function Bottom_Bar_Sort_Menu_Contains
     (X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Boolean
   is
      Menu        : constant Layouts.Menus.Sort_Menu_Layout :=
        Layouts.Menus.Calculate_Sort_Menu_Layout (Width, Height, Sort_Field, Line_Height);
      Menu_Bottom : constant Natural :=
        Natural'Min (Height, Saturating_Add (Menu.Y, Menu.Height));
   begin
      return Menu.Width > 0
        and then X < Width
        and then Y < Height
        and then X >= Menu.X
        and then X < Saturating_Add (Menu.X, Menu.Width)
        and then Y >= Menu.Y
        and then Y < Menu_Bottom;
   end Bottom_Bar_Sort_Menu_Contains;

end Files.Rendering.Hit;
