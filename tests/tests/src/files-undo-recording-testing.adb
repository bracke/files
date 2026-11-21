package body Files.Undo.Recording.Testing is

   --  What Count_Undo_Records counted.
   Records : Natural := 0;

   --  The Undo_Record_Attempted hook Count_Undo_Records installs.
   procedure Note_Record is
   begin
      Records := Records + 1;
   end Note_Record;

   procedure Count_Undo_Records (Count : Boolean) is
   begin
      Records := 0;
      Undo_Record_Attempted := (if Count then Note_Record'Access else null);
   end Count_Undo_Records;

   function Undo_Records return Natural is (Records);

end Files.Undo.Recording.Testing;
