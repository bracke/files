with Files.Localization;
with Guikit.Utf8;
with Files.Rendering.Geometry;

package body Files.Rendering.Layouts.Menus is

   use Files.Rendering.Geometry;

   function Calculate_Context_Menu_Layout
     (Snapshot : View_Snapshot; Width : Natural; Height : Natural; Line_Height : Positive) return Context_Menu_Layout
   is separate;

   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
 is separate;

   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
 is separate;

   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
 is separate;

   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural
   is separate;

   function Calculate_Sort_Menu_Layout
     (Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Sort_Menu_Layout
   is separate;

   function Sort_Menu_Row_Top
     (Menu : Sort_Menu_Layout;
      Row  : Positive)
      return Natural is
     (Guikit.Layout.Saturating_Add (Menu.Rows_Y, Guikit.Layout.Saturating_Multiply (Row - 1, Menu.Row_Height)));

   function Sort_Menu_Row_At
     (Menu : Sort_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural
   is separate;

   function Sort_Menu_Row_Field
     (Row : Positive)
      return Files.Types.Sort_Field renames Files.UI_Types.Sort_Menu_Field;

end Files.Rendering.Layouts.Menus;
