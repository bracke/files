with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.File_System;
with Files.Localization;
with Hostkit.Fs;

package body Files.Recovery_CLI is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Fail;

   procedure List (Directory : String) is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Open   : Boolean := False;
   begin
      if Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
      then
         Fail (Files.Localization.Text ("cli.recovery.error.not_directory", "en") & ':' & ' ' & Directory);
         return;
      end if;
      Ada.Directories.Start_Search
        (Search, Directory, ".files-recovery-*", [Ada.Directories.Directory => True, others => False]);
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Payload : constant String :=
              Hostkit.Fs.Join (Ada.Directories.Full_Name (Item), "payload");
            Original : constant String := Files.File_System.Trash_Original_Path (Payload);
         begin
            if Files.File_System.Is_Recovery_Payload (Payload) and then Original /= "" then
               Ada.Text_IO.Put_Line (Payload & ASCII.HT & Original);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
         Fail (Files.Localization.Text ("cli.recovery.error.list", "en") & ':' & ' ' & Directory);
   end List;

   procedure Apply (Path : String; Restore : Boolean) is
   begin
      if not Files.File_System.Is_Recovery_Payload (Path) then
         Fail (Files.Localization.Text ("cli.recovery.error.not_payload", "en") & ':' & ' ' & Path);
         return;
      end if;
      declare
         Result : constant Files.File_System.Mutation_Result :=
           (if Restore then Files.File_System.Restore_From_Trash (Path)
            else Files.File_System.Delete_Trashed_Item (Path));
      begin
         if not Result.Success then
            Fail (Files.Localization.Text (To_String (Result.Error_Key), "en") & ": " & Path);
         end if;
      end;
   end Apply;

   function Run_If_Requested return Boolean is
   begin
      if Ada.Command_Line.Argument_Count = 0 then
         return False;
      elsif Ada.Command_Line.Argument (1) not in
        "--list-recoveries" | "--recover" | "--discard-recovery"
      then
         return False;
      elsif Ada.Command_Line.Argument_Count /= 2 then
         Fail (Files.Localization.Text ("cli.recovery.error.argument", "en"));
      elsif Ada.Command_Line.Argument (1) = "--list-recoveries" then
         List (Ada.Command_Line.Argument (2));
      else
         Apply
           (Ada.Command_Line.Argument (2),
            Restore => Ada.Command_Line.Argument (1) = "--recover");
      end if;
      return True;
   end Run_If_Requested;
end Files.Recovery_CLI;
