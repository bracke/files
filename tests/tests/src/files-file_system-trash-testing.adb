with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Files.Diagnostics;

package body Files.File_System.Trash.Testing is

   use Ada.Strings.Unbounded;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   --  Write Content to Path, replacing what it held.
   procedure Write (Path, Content : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (File), Content);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Write;

   --  Whether Change_Trashed_After_Copy has fired.
   Trashed_Changed : Boolean := False;

   --  The After_Restore_Copy hook Change_Trashed_After_Copy installs.
   procedure Change_Trashed (Trashed_Path : String) is
   begin
      if Trashed_Changed then
         return;
      end if;
      Trashed_Changed := True;
      Ada.Directories.Delete_File (Trashed_Path);
      Write (Trashed_Path, "another item");
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Trash.Testing");
   end Change_Trashed;

   procedure Change_Trashed_After_Copy is
   begin
      Trashed_Changed := False;
      After_Restore_Copy := Change_Trashed'Access;
   end Change_Trashed_After_Copy;

   procedure Stop_Changing_Trashed is
   begin
      After_Restore_Copy := null;
   end Stop_Changing_Trashed;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash.Evaluate_Native_Trash;

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
