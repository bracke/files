--  How a file's leading bytes are read as text: which encoding they are in
--  (UTF-8, UTF-16 with or without a byte order mark, or something that is not
--  text), and their decoding to UTF-8 for content search and Quick Look. The
--  one place these rules live: the info pane's encoding word and the text the
--  search reads come from the same detection, so a file the search reads as
--  UTF-16 text is not called binary beside it.
package Files.Text_Encoding is

   --  An encoding a text file's metadata can name.
   type Encoding is (Ascii_Text, Utf8, Utf16_Little_Endian, Utf16_Big_Endian, Binary);

   --  The token an encoding is named by in item metadata, which the info pane
   --  reads as the catalog key info.extra.encoding.<token>.
   --
   --  @param Value Encoding to name.
   --  @return Its metadata token.
   function Token (Value : Encoding) return String is
     (case Value is
         when Ascii_Text          => "ascii",
         when Utf8                => "utf8",
         when Utf16_Little_Endian => "utf16le",
         when Utf16_Big_Endian    => "utf16be",
         when Binary              => "binary");

   --  How Raw is laid out as UTF-16, if it is: behind a byte order mark, or
   --  without one when nearly every other byte is NUL, as ASCII text in
   --  UTF-16 is.
   type Utf16_Layout is (Not_Utf16, Little_Endian_Marked, Big_Endian_Marked, Little_Endian, Big_Endian);

   --  @param Raw Bytes read from the start of a file, possibly cut short.
   --  @return Raw's UTF-16 layout; Not_Utf16 when it does not read as UTF-16.
   function Utf16_Layout_Of (Raw : String) return Utf16_Layout;

   --  @param Item A byte of UTF-8 text.
   --  @return True when Item continues a multibyte sequence (10xxxxxx).
   function Is_Continuation_Byte (Item : Character) return Boolean is
     (Character'Pos (Item) in 16#80# .. 16#BF#);

   --  Return whether Raw_Bytes looks like binary (non-text) data: it contains a
   --  NUL byte, or too large a share of non-printable control bytes to render as
   --  monospace text. An empty input is not considered binary. Applied to
   --  Searchable_Text's decoding, it is what Quick Look will not show as text
   --  and content search will not search.
   --
   --  @param Raw_Bytes Leading bytes of a file.
   --  @return True when the bytes should not be read as text.
   function Looks_Binary
     (Raw_Bytes : String)
      return Boolean;

   --  Raw cut back to its last whole UTF-8 character: a multibyte sequence a
   --  bounded read cut short is dropped. Anything else is left as it is.
   --
   --  @param Raw Bytes read from the start of a file, possibly cut short.
   --  @return Raw without a trailing incomplete character.
   function Trim_To_Character (Raw : String) return String;

   --  A file's first bytes as UTF-8 text to search: UTF-16 (Utf16_Layout_Of)
   --  transcoded; UTF-8 cut back to its last whole character; text that is
   --  not UTF-8 read as Windows-1252 (Latin-1 with the printable
   --  0x80 .. 0x9F). Bytes that look binary are returned as they are. A unit
   --  or character a bounded read cut short is dropped.
   --
   --  @param Raw Bytes read from the start of a file, possibly cut short.
   --  @return The text, UTF-8 encoded.
   function Searchable_Text (Raw : String) return String;

   --  The encoding a text file's leading bytes are in, for its metadata:
   --  UTF-16 when they read as UTF-16 text; otherwise ASCII or UTF-8 when
   --  every byte is well-formed UTF-8 without a NUL, and Binary when not. A
   --  character the sample's end cut short is not a defect when the file goes
   --  on past it.
   --
   --  @param Sample The file's first bytes.
   --  @param Complete False when the file is longer than Sample.
   --  @return The encoding to name.
   function Classify (Sample : String; Complete : Boolean) return Encoding;

   --  Whether Text (Searchable_Text) is text, not binary
   --  (Looks_Binary), and
   --  contains Folded_Query (a query already folded with Fold_Case),
   --  ignoring case: content search's match, with the query folded once
   --  per search rather than once per file.
   --
   --  @param Text A file's first bytes as Searchable_Text
   --    gives them.
   --  @param Folded_Query Files.Text_Case.Fold_Case of the text looked for; "" matches nothing.
   --  @return True for a text match.
   function Text_Contains (Text : String; Folded_Query : String) return Boolean;

end Files.Text_Encoding;
