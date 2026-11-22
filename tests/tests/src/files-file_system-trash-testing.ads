with Ada.Calendar;

--  Test-only access to Files.File_System.Trash's private part: the native
--  backends' adapters, the info file's date, and the hooks that make a
--  native trash refuse or keep where it put an item to itself.
package Files.File_System.Trash.Testing is

   --  Whether the current environment's native trash supports Request.
   --
   --  @param Request Native trash request metadata.
   --  @return Native trash support result.
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  Send Request's item to the native trash.
   --
   --  @param Request Native trash request for a native backend.
   --  @return What the native backend did.
   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  The DeletionDate text a trash info file records for Value.
   --
   --  @param Value The deletion time.
   --  @return Local time, whole seconds.
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String;

   --  Make the native trash refuse every item (True) or behave again.
   --
   --  @param Refuse Whether to refuse.
   procedure Refuse_Native_Trash (Refuse : Boolean);

   --  Make the trash report success without saying where the item went
   --  (True), as some hosts do, or report it again.
   --
   --  @param Withhold Whether to withhold the location.
   procedure Withhold_Trash_Location (Withhold : Boolean);

end Files.File_System.Trash.Testing;
