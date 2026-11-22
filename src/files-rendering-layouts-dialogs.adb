with Files.Rendering.Geometry;

package body Files.Rendering.Layouts.Dialogs is

   use Files.Rendering.Geometry;

   procedure Titled_Panel_Title
     (Panel_X, Panel_Y, Panel_W : Natural;
      Line_Height               : Positive;
      Title_X, Title_Y, Title_W : out Natural)
 is separate;

   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Quick_Look_Layout
   is separate;

   function Calculate_Label_Picker_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Label_Picker_Layout
   is separate;

   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector
 is separate;

   function Calculate_Conflict_Dialog_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Conflict_Dialog_Layout
 is separate;

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
   is separate;

end Files.Rendering.Layouts.Dialogs;
