separate (Files.Rendering)
   function Details_Header_Command_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id
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
         return Files.Commands.No_Command;
      elsif Within (Files.Types.Name_Column) then
         return Files.Commands.Sort_By_Name_Command;
      elsif Within (Files.Types.Modified_Column) then
         return Files.Commands.Sort_By_Changed_Command;
      elsif Within (Files.Types.Size_Column) then
         return Files.Commands.Sort_By_Size_Command;
      elsif Within (Files.Types.Filetype_Column) then
         return Files.Commands.Sort_By_Type_Command;
      elsif Within (Files.Types.Created_Column) then
         return Files.Commands.Sort_By_Created_Command;
      else
         return Files.Commands.No_Command;
      end if;
   end Details_Header_Command_At;
