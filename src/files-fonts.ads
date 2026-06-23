--  Font discovery for text rendering startup.
package Files.Fonts is

   --  Return the available font file best suited for broad filename text.
   --
   --  @return Font path, or an empty string when no known font is present.
   function Default_Font_Path return String;

   --  Return the available font file best suited for the requested text.
   --
   --  @param Text UTF-8 or legacy filename text that should render directly.
   --  @return Font path, or an empty string when no known font is present.
   function Font_Path_For_Text
     (Text : String)
      return String;

end Files.Fonts;
