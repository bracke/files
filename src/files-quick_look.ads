with Files.Types;

--  Pure Quick Look content preparation. Given an item's metadata plus a bounded
--  read of its leading bytes, this classifies what the Quick Look overlay should
--  render: a scaled image, the first lines of a text file, or a fallback info
--  card. It performs no filesystem access itself (the caller supplies the capped
--  bytes and the image-classification flag), so the whole seam is unit-testable.
package Files.Quick_Look is
   subtype UString is Files.Types.UString;

   --  What the overlay renders for the previewed item.
   type Content_Kind is
     (Image_Content,
      Text_Content,
      Info_Content);

   --  Cap on the number of text lines carried into the preview.
   Max_Preview_Lines : constant := 100;

   --  Cap on the number of leading bytes a caller should read for text preview.
   Max_Preview_Bytes : constant := 8192;

   --  Prepared, renderer-ready description of a Quick Look preview. Image_Path
   --  names the source image the renderer decodes for Image_Content; Text_Lines
   --  holds the capped leading lines for Text_Content; the name/type/size/icon
   --  fields back the Info_Content fallback card and the panel header.
   type Quick_Look_Content is record
      Kind           : Content_Kind := Info_Content;
      Name           : UString;
      Filetype       : UString;
      Icon_Id        : UString;
      Size_Available : Boolean := False;
      Size           : Long_Long_Integer := 0;
      Image_Path     : UString;
      Text_Lines     : Files.Types.String_Vectors.Vector;
      Text_Truncated : Boolean := False;
      --  For Image_Content: the original image decoded to RGBA at preview
      --  resolution, filled by the caller after classification (this package is
      --  pure). Empty when decoding was unavailable; the renderer then falls back
      --  to the item's small thumbnail.
      Image_Pixels   : Files.Types.Byte_Vectors.Vector;
      Image_Width    : Natural := 0;
      Image_Height   : Natural := 0;
   end record;

   --  Return whether Raw_Bytes looks like binary (non-text) data: it contains a
   --  NUL byte, or too large a share of non-printable control bytes to render as
   --  monospace text. An empty input is not considered binary.
   --
   --  @param Raw_Bytes Leading bytes of the file.
   --  @return True when the bytes should not be shown as text.
   function Looks_Binary
     (Raw_Bytes : String)
      return Boolean;

   --  Classify a Quick Look preview from item metadata and a bounded read.
   --
   --  Image items yield Image_Content (carrying Image_Path for the decoder).
   --  Regular, non-binary files with readable bytes yield Text_Content whose
   --  Text_Lines hold the first Max_Preview_Lines lines (Text_Truncated flags a
   --  longer file). Directories, binaries, unreadable, and every other case fall
   --  back to Info_Content. The bytes must already be capped by the caller; this
   --  routine additionally caps the line count and never blocks.
   --
   --  @param Name Item simple name.
   --  @param Filetype Detected filetype identifier.
   --  @param Icon_Id Icon identifier for the info card.
   --  @param Kind Filesystem item kind.
   --  @param Size_Available True when Size holds a known byte count.
   --  @param Size Item size in bytes when known.
   --  @param Is_Image True when the item is classified as a previewable image.
   --  @param Image_Path Full path the renderer decodes for an image preview.
   --  @param Raw_Bytes Bounded leading bytes for text detection and preview.
   --  @return Prepared preview content.
   function Prepare_Content
     (Name           : String;
      Filetype       : String;
      Icon_Id        : String;
      Kind           : Files.Types.Item_Kind;
      Size_Available : Boolean;
      Size           : Long_Long_Integer;
      Is_Image       : Boolean;
      Image_Path     : String;
      Raw_Bytes      : String)
      return Quick_Look_Content;

end Files.Quick_Look;
