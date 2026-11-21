separate (Files.File_System.Move_To_Trash)
--  The freedesktop info file that records where the item came from and
--  when it was trashed, on the device before the item moves in. Name_Taken
--  when another trash (another window or process) took the name since it
--  was found free: nothing is written then.
procedure Write_Info_File (Name_Taken : out Boolean) is
   Metadata : constant String :=
     "[Trash Info]" & ASCII.LF
     & "Path=" & Trash_Info_Path_Value (Info_Path_Text)
     & ASCII.LF & "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock) & ASCII.LF;

   --  The info file's text, as the bytes it is.
   procedure Write_Metadata (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
   begin
      String'Write (Stream, Metadata);
   end Write_Metadata;
begin
   --  Made anew at its final name, never over one already there; what fails
   --  below removes only this file, by its identity.
   Files.Durable_Writes.Write_Private_File (To_String (Info_Path), Write_Metadata'Access, Info_Identity, Name_Taken);
   if Name_Taken then
      return;
   end if;
   --  On the device before the item moves in: a crash must not leave
   --  an item in the trash with an empty info file, which the trash
   --  view could neither list nor restore.
   if Hostkit.Durability."=" (Files.Durability.Sync_File (To_String (Info_Path)), Hostkit.Durability.Failed)
     or else Hostkit.Durability."=" (Files.Durability.Sync_Directory (Info_Dir), Hostkit.Durability.Failed)
   then
      raise Ada.Directories.Use_Error;
   end if;
end Write_Info_File;
