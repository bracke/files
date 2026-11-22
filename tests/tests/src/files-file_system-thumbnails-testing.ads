--  Test-only views of Files.File_System.Thumbnails.
package Files.File_System.Thumbnails.Testing is

   --  The pure-Ada PNG thumbnail path alone, without the gdk-pixbuf fallback.
   --
   --  @param Source_Path PNG to decode.
   --  @param Size Thumbnail side.
   --  @param Target_Path Where to write the thumbnail.
   --  @return True when that path decoded and wrote it.
   function Png_Fast_Path (Source_Path : String; Size : Positive; Target_Path : String) return Boolean;

   --  A cache listing under a cap of Max_Entries thumbnails.
   --
   --  @param Cache_Directory The cache directory.
   --  @param Max_Entries The listing's cap.
   --  @param Listed Whether the listing stayed under the cap.
   --  @param Count How many thumbnail names it holds.
   procedure List_Cache
     (Cache_Directory : String;
      Max_Entries     : Positive;
      Listed          : out Boolean;
      Count           : out Natural);

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

end Files.File_System.Thumbnails.Testing;
