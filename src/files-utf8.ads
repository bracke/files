--  UTF-8 byte-string helpers used by UI measurement and rendering.
package Files.UTF8 is

   --  Return the display-cell count for a UTF-8 byte string.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @return Number of display cells represented by Content.
   function Display_Units
     (Content : String)
      return Natural;

   --  Return a prefix containing at most Max_Units UTF-8 display cells.
   --
   --  Invalid bytes count as one replacement display cell and are preserved
   --  as bytes in the returned prefix.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Max_Units Maximum display cells to preserve.
   --  @return Prefix ending at a UTF-8 unit boundary where possible.
   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String;

   --  Return display-cell count before a zero-based byte cursor offset.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Number of display cells before Cursor.
   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the byte offset corresponding to a display-cell column.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Column Zero-based display-cell column.
   --  @return Byte offset at the requested display-cell column.
   function Byte_Offset_For_Display_Column
     (Content : String;
      Column  : Natural)
      return Natural;

   --  Decode the UTF-8 unit at Index into a Unicode codepoint.
   --
   --  Invalid bytes decode to Replacement_Codepoint and advance by one byte.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Index One-based string index updated to the next byte after decode.
   --  @param Codepoint Decoded Unicode codepoint or Replacement_Codepoint.
   --  @param Replacement_Codepoint Codepoint used for invalid bytes.
   procedure Decode_Next_Codepoint
     (Content               : String;
      Index                 : in out Integer;
      Codepoint             : out Natural;
      Replacement_Codepoint : Natural := 16#FFFD#);

   --  Decode the UTF-8 unit at Index for user-visible text rendering.
   --
   --  Valid UTF-8 decodes normally. Invalid non-ASCII bytes decode as Latin-1
   --  codepoints so legacy byte filenames remain inspectable.
   --
   --  @param Content UTF-8 encoded byte string, or legacy filename bytes.
   --  @param Index One-based string index updated to the next byte after decode.
   --  @param Codepoint Decoded Unicode codepoint or Latin-1 fallback byte value.
   procedure Decode_Next_Display_Codepoint
     (Content   : String;
      Index     : in out Integer;
      Codepoint : out Natural);

   --  Return whether Codepoint is a zero-width mark that still needs a glyph.
   --
   --  Variation selectors are zero-width but not required glyphs because they
   --  modify adjacent glyph selection instead of rendering standalone marks.
   --
   --  @param Codepoint Unicode codepoint to classify.
   --  @return True when missing glyph coverage would visibly drop text.
   function Is_Required_Zero_Width_Codepoint
     (Codepoint : Natural)
      return Boolean;

   --  Return whether Content is well-formed UTF-8.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @return True when every byte belongs to a valid UTF-8 sequence.
   function Is_Valid
     (Content : String)
      return Boolean;

   --  Encode Codepoint as a UTF-8 byte string.
   --
   --  Invalid codepoints encode as U+FFFD.
   --
   --  @param Codepoint Unicode codepoint to encode.
   --  @return UTF-8 encoded byte string.
   function Encode_Codepoint
     (Codepoint : Natural)
      return String;

   --  Return the previous UTF-8 text boundary before or at Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the previous text boundary.
   function Previous_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the next UTF-8 text boundary after or at Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the next text boundary.
   function Next_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the nearest UTF-8 text boundary at or before Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the nearest earlier text boundary.
   function Boundary_At_Or_Before
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the byte length of a whitespace separator at Position.
   --
   --  Separators include ASCII whitespace, C1 NEL, and common UTF-8 Unicode
   --  spaces. Punctuation is not included.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Position Zero-based byte offset into Content.
   --  @return Separator byte length, or zero when no separator starts there.
   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural;

   --  Return the byte length of a word separator at Position.
   --
   --  Separators include ASCII whitespace, path/name punctuation used by the
   --  UI word movement model, C1 NEL, and common UTF-8 Unicode spaces.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Position Zero-based byte offset into Content.
   --  @return Separator byte length, or zero when no separator starts there.
   function Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural;

   --  Return the previous word boundary before or at Cursor.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the previous word boundary.
   function Previous_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the next word boundary after or at Cursor.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the next word boundary.
   function Next_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

end Files.UTF8;
