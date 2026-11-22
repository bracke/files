with Guikit.Layout;
with Guikit.Utf8;

package body Files.Rendering.Layouts.Testing is

   function Input_Scroll_Columns
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Natural
   is
     (Guikit.Layout.Input_Scroll_Columns
        (Guikit.Utf8.Display_Units_Before (Text, Natural'Min (Cursor, Text'Length)), Text_Width, Line_Height));

   function Dialog_Padding (Line_Height : Positive) return Natural
     renames Files.Rendering.Layouts.Dialog_Padding;

end Files.Rendering.Layouts.Testing;
