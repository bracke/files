separate (Files.File_System.Move_To_Trash)
--  The freedesktop info file that records where the item came from and
--  when it was trashed, on the device before the item moves in.
procedure Write_Info_File is
   Metadata : constant String :=
     "[Trash Info]" & ASCII.LF
     & "Path=" & Trash_Info_Path_Value (Info_Path_Text)
     & ASCII.LF & "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock) & ASCII.LF;
   --  Created last, so nothing runs between a refusal and Capture.
   Descriptor : GNAT.OS_Lib.File_Descriptor :=
     Hostkit.Regular_Files.Create_New (To_String (Info_Path), 8#666#);
   Written : Integer;
   Next    : Positive := Metadata'First;
   Closed  : Boolean;
begin
   if Descriptor = GNAT.OS_Lib.Invalid_FD then
      Files.Io_Errors.Capture;
      raise Ada.Directories.Use_Error;
   end if;
   Info_Owned := True;
   Files.Private_Directories.Make_File_Private (Descriptor);
   while Next <= Metadata'Last loop
      Written := GNAT.OS_Lib.Write (Descriptor, Metadata (Next)'Address, Metadata'Last - Next + 1);
      if Written <= 0 then
         Files.Io_Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      Next := Next + Written;
   end loop;
   GNAT.OS_Lib.Close (Descriptor, Closed);
   Descriptor := GNAT.OS_Lib.Invalid_FD;
   if not Closed then
      Files.Io_Errors.Capture;
      raise Ada.Directories.Use_Error;
   end if;
   --  On the device before the item moves in: a crash must not leave
   --  an item in the trash with an empty info file, which the trash
   --  view could neither list nor restore.
   if Hostkit.Durability."=" (Files.Durability.Sync_File (To_String (Info_Path)), Hostkit.Durability.Failed)
     or else Hostkit.Durability."=" (Files.Durability.Sync_Directory (Info_Dir), Hostkit.Durability.Failed)
   then
      raise Ada.Directories.Use_Error;
   end if;
exception
   when others =>
      if Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Descriptor);
      end if;
      raise;
end Write_Info_File;
