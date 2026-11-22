with Ada.Calendar;

--  Test-only access to Files.File_System.Trash's private part: the native
--  backends' adapters, the info file's date, and the hooks that make a
--  native trash refuse, keep where it put an item to itself, or find
--  another item in a restored one's place.
package Files.File_System.Trash.Testing is

   --  Whether the current environment's native trash supports Request.
   --
   --  @param Request Native trash request metadata.
   --  @return Native trash support result.
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  The DeletionDate text a trash info file records for Value.
   --
   --  @param Value The deletion time.
   --  @return Local time, whole seconds.
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String;

   --  Build the native trash request that would be needed for Path.
   --
   --  @param Path Filesystem path requested for native trash handling.
   --  @return Native trash request metadata.
   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request;

   --  From now on, once a restore from a trash on another device has copied
   --  the item back, put another file (of "another item") in its place under
   --  the same name before the trash copy is removed, as emptying the trash
   --  and trashing something else would. It fires once; arming it again
   --  rearms it.
   procedure Change_Trashed_After_Copy;

   --  Put nothing in a restored item's place any more.
   procedure Stop_Changing_Trashed;

   --  Make the native trash refuse every item (True) or behave again.
   --
   --  @param Refuse Whether to refuse.
   procedure Refuse_Native_Trash (Refuse : Boolean);

   --  Make the trash report success without saying where the item went
   --  (True), as some hosts do, or report it again.
   --
   --  @param Withhold Whether to withhold the location.
   procedure Withhold_Trash_Location (Withhold : Boolean);

   --  The private Info_Codec's Encode: a trash info file's Path= value.
   --
   --  @param Path An original path, as bytes.
   --  @return Its percent-encoded form.
   function Encode_Info_Path (Path : String) return String;

   --  The private Info_Codec's Decode.
   --
   --  @param Value A Path= value.
   --  @return The original path it encodes.
   function Decode_Info_Path (Value : String) return String;

end Files.File_System.Trash.Testing;
