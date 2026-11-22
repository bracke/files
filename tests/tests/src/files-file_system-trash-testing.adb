package body Files.File_System.Trash.Testing is

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash.Evaluate_Native_Trash;

   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash.Trash_Natively;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
     renames Files.File_System.Trash.Trash_Deletion_Date;

   procedure Refuse_Native_Trash (Refuse : Boolean) is
   begin
      Native_Trash_Refused := Refuse;
   end Refuse_Native_Trash;

   procedure Withhold_Trash_Location (Withhold : Boolean) is
   begin
      Trash_Location_Withheld := Withhold;
   end Withhold_Trash_Location;

end Files.File_System.Trash.Testing;
