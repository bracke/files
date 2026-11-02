with Ada.Calendar;
with Ada.Containers.Vectors;

with Files.Shared_Bytes;
with Files.Types;

--  A directory's entry as files shows it: the value the listing produces and
--  the model, rendering and jobs pass around. Its own unit, so they need not
--  depend on Files.File_System, which reads and changes the disk, for it.
package Files.Items is
   subtype UString is Files.Types.UString;

   type Directory_Item is record
      Name               : UString;
      Full_Path          : UString;
      Parent_Path        : UString;
      --  Hidden by a leading dot or by the host's own flag (Windows hidden
      --  attribute, macOS UF_HIDDEN).
      Hidden             : Boolean := False;
      Kind               : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Filetype           : UString;
      Icon_Id            : UString;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Permissions        : UString;
      Mode_Available     : Boolean := False;
      Mode_Bits          : Natural := 0;
      Ownership_Available : Boolean := False;
      Owner_Id           : Files.Types.Account_Id := 0;
      Group_Id           : Files.Types.Account_Id := 0;
      Filetype_Extra     : UString;
      Filetype_Extra_Loaded : Boolean := False;
      Thumbnail_Available : Boolean := False;
      Thumbnail_Path      : UString;
      Thumbnail_Width     : Natural := 0;
      Thumbnail_Height    : Natural := 0;
      --  Shared, immutable: copying an item (into rows, snapshots, caches)
      --  must not copy its decoded thumbnail.
      Thumbnail_Pixels    : Files.Shared_Bytes.Bytes;
      Metadata_Error     : Boolean := False;
      Error_Key          : UString;
   end record;

   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Directory_Item);

end Files.Items;
