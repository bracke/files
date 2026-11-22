--  Test-only access to Files.Rendering.Layouts, kept out of the program.
package Files.Rendering.Layouts.Testing is

   --  Display columns a focused single-line input scrolls off its left edge
   --  so the caret stays visible: guikit's rule (Guikit.Layout.
   --  Input_Scroll_Columns) over the text's display units, which the field
   --  view (Field_View_Of) starts from.
   --
   --  @param Text Field text (UTF-8).
   --  @param Cursor Caret byte offset within Text.
   --  @param Text_Width Pixel width available to the text.
   --  @param Line_Height Text line height in pixels.
   --  @return Columns hidden on the left; zero when the caret already fits.
   function Input_Scroll_Columns
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Natural;

   --  The inset of a modal dialog's content from its frame.
   --
   --  @param Line_Height The line height in use.
   --  @return The inset in pixels.
   function Dialog_Padding (Line_Height : Positive) return Natural;

end Files.Rendering.Layouts.Testing;
