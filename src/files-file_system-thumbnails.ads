with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

--  Thumbnails of image files: made with Files.Images, kept as small PPM files
--  in a per-user cache directory, found again by the source's identity, and
--  pruned oldest-first. A child of Files.File_System because the listing
--  attaches them to items and both share its file handling.
package Files.File_System.Thumbnails is

   type Thumbnail_Status is
     (Thumbnail_Generated,
      Thumbnail_Source_Missing,
      Thumbnail_Unsupported,
      Thumbnail_Failed);

   type Thumbnail_Result is record
      Status         : Thumbnail_Status := Thumbnail_Failed;
      Source_Path    : UString;
      Thumbnail_Path : UString;
      Width          : Positive := 1;
      Height         : Positive := 1;
      Error_Key      : UString;
   end record;

   --  The most thumbnails the cache is meant to hold: how many one prune
   --  collects (sizes, times, identities), and how many a cache listing
   --  takes before it gives up and treats the cache as unlisted.
   Max_Cache_Prune_Entries : constant := 100_000;

   --  Bring the thumbnail cache under Budget_Bytes, deleting the least recently
   --  modified files first.
   --
   --  The cache is regenerable, so nothing here is lost -- a pruned thumbnail is
   --  simply rebuilt the next time its source is listed. Oldest-first is also
   --  what clears orphans: a thumbnail whose source was renamed or deleted is
   --  never rewritten, so it ages to the front of the queue on its own.
   --
   --  Housekeeping, never a precondition: a file it cannot identify, stat, or
   --  delete is skipped, and failure to prune never stops a thumbnail being
   --  written. Each deletion is bound to the entry observed during the scan.
   --
   --  @param Cache_Directory Directory holding the cached thumbnails.
   --  @param Budget_Bytes Total size to come under.
   --  @param Max_Entries How many thumbnails one pass collects: the oldest
   --  that many by modification time, whatever the listing order. A
   --  directory holding more loses the oldest it needs to -- the overflow
   --  and a tenth of the cap more, as far as the collected reach -- so
   --  repeated passes bring it under the cap, oldest first throughout.
   procedure Prune_Thumbnail_Cache
     (Cache_Directory : String;
      Budget_Bytes    : Long_Long_Integer;
      Max_Entries     : Positive := Max_Cache_Prune_Entries);

   --  Return the default thumbnail cache directory for the current environment.
   --
   --  @param Fallback_Directory Directory used when no user cache location exists.
   --  @return Directory path used for generated thumbnail artifacts.
   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String;

   --  Return the deterministic cached thumbnail path for a source file and its
   --  current identity/revision, so replacement or modification cannot reuse a
   --  stale artifact.
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

   --  A cached thumbnail read back for a listed item.
   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   --  Whether a listed item is one a thumbnail is made for automatically.
   --
   --  @param Kind Filesystem item kind.
   --  @param Filetype Detected filetype identifier.
   --  @param Name File name.
   --  @param Icon_Id Icon identifier.
   --  @return True for a raster image a listing makes a thumbnail of.
   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

   --  The thumbnail names in a cache directory, as a listing reads them once.
   package Thumbnail_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   type Cache_Index is record
      Listed : Boolean := False;
      Names  : Thumbnail_Name_Sets.Set;
      --  False for a listing the UI waits on: a missing thumbnail is then
      --  left for a background listing to make.
      Generate : Boolean := True;
      --  True when Names is empty and the remembered listing answers
      --  instead (Cache_Index_Memo), so it is never copied per directory.
      Shared   : Boolean := False;
   end record;

   --  Read the cache directory once. A cache that does not exist yet yields an
   --  empty listing. An unreadable or oversized cache falls back to per-item
   --  checks rather than losing cached results or retaining unbounded names.
   --
   --  @param Cache_Directory The thumbnail cache directory.
   --  @return The names it holds, or an unlisted index.
   function Index_Thumbnail_Cache (Cache_Directory : String) return Cache_Index;

   --  The cached thumbnail for a listed item, made first when the item is an
   --  image without one and the index allows making it.
   --
   --  @param Full_Path The item's path.
   --  @param Kind Its kind.
   --  @param Filetype Its detected filetype.
   --  @param Name Its leaf name.
   --  @param Icon_Id Its icon identifier.
   --  @param Cache_Directory The thumbnail cache directory.
   --  @param Thumbnail_Path Where its thumbnail is kept (Thumbnail_Path_For).
   --  @param Cached The cache's index, read once for the listing.
   --  @return The thumbnail; Loaded is False when there is none.
   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String;
      Cached          : Cache_Index)
      return Cached_Thumbnail;

private

   --  The pure-Ada PNG path: decode Source_Path and write its thumbnail to
   --  Target_Path, or answer False for a PNG it will not read (then gdk-pixbuf
   --  is tried). In the private part so the suite can hold it to its bounds
   --  directly, since gdk-pixbuf may read what it refuses.
   function Try_Write_Decoded_Png_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean;

   --  Read the cache directory once, holding at most Max_Entries thumbnail
   --  names; a cache holding more is left unlisted (per-item checks). Files
   --  that are not thumbnails are not counted. In the private part so the
   --  suite can try the cap without making a hundred thousand files.
   --
   --  @param Cache_Directory The thumbnail cache directory.
   --  @param Max_Entries How many thumbnails a listing holds.
   --  @return The thumbnail names it holds, or an unlisted index.
   function List_Thumbnail_Cache
     (Cache_Directory : String;
      Max_Entries     : Positive := Max_Cache_Prune_Entries)
      return Cache_Index;

end Files.File_System.Thumbnails;
