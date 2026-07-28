--  The thumbnails operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Thumbnails is

   --  Return the default thumbnail cache directory for the current environment.
   --
   --  @param Fallback_Directory Directory used when no user cache location exists.
   --  @return Directory path used for generated thumbnail artifacts.
   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String;

   --  Return the deterministic cached thumbnail path for a source file.
   --
   --  @param Source_Path Source file represented by the thumbnail.
   --  @param Cache_Directory Thumbnail cache directory.
   --  @param Size Thumbnail size in pixels.
   --  @return Deterministic thumbnail artifact path.
   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String;

   --  Generate a cached thumbnail artifact for a regular file.
   --
   --  Supported source image formats are decoded and scaled in Ada; unsupported
   --  formats fall back to a deterministic PPM derived from file metadata.
   --
   --  @param Source_Path File to summarize as a thumbnail.
   --  @param Cache_Directory Directory where the thumbnail file is written.
   --  @param Size Width and height in pixels.
   --  @return Thumbnail path and status, or a recoverable error key.
   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result;

   --  Decode an image file directly to RGBA pixels, scaled to fit within
   --  Max_Size x Max_Size while preserving aspect ratio. Used for the Quick Look
   --  image preview so it renders from the original rather than the small
   --  thumbnail. Returns Available => False when decoding is unavailable.
   --
   --  @param Path Image file to decode.
   --  @param Max_Size Longest-side bound in pixels for the decoded result.
   --  @return The decoded RGBA image, or Available => False on failure.
   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image;

   --  Return whether an item is a previewable raster image, using the same
   --  classification the automatic thumbnail generator applies (image/* MIME,
   --  the "image" icon id, or a known raster extension). Directories and
   --  symlinks are never images.
   --
   --  @param Kind Filesystem item kind.
   --  @param Filetype Detected filetype identifier.
   --  @param Name File name to inspect.
   --  @param Icon_Id Icon identifier for the item.
   --  @return True when the item should be previewed as an image.
   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

   --  Read up to Max_Bytes leading bytes of a file as a raw String, for a
   --  bounded text preview. Returns an empty string when the file cannot be
   --  opened or read. Never blocks beyond the capped read.
   --
   --  @param Path File to read.
   --  @param Max_Bytes Maximum number of leading bytes to return.
   --  @return Leading bytes as a String, or an empty string on failure.
   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String;

end Files.File_System.Thumbnails;
