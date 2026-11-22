package body Files.IO.Errors.Testing is

   function Key_For_Errno (Code : Integer; Fallback : String) return String renames Files.IO.Errors.Key_For_Errno;

   procedure Record_Code (Code : Integer) renames Files.IO.Errors.Record_Code;

   function Key_For_Last (Fallback : String) return String renames Files.IO.Errors.Key_For_Last;

   function Key_Of (Item : Cause) return String renames Files.IO.Errors.Key_Of;

end Files.IO.Errors.Testing;
